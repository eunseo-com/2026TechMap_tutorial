// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionObservationProvider.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityOcclusionObservationProviderTests.swift
// Implementation status: integrated
// Verification: standalone iPhoneOS type-check·generic build·물리 iPhone 기준 186/186 통과; 추가 Reduce Motion 2개 compile·sign 통과/runtime은 device unlock 대기; UI test 0개; LiDAR 관찰·동일 기기 캡처·Swift 6 strict·배포 대기

import Foundation
import simd

@MainActor
protocol CycleDeadlineCancellable: AnyObject {
    func cancel()
}

@MainActor
protocol CycleDeadlineScheduling {
    var now: TimeInterval { get }

    func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> any CycleDeadlineCancellable
}

@MainActor
protocol RealitySessionControlling: AnyObject {
    func pause()
}

@MainActor
protocol HideCycleResources: AnyObject {
    func cancelPendingControllerWork()
    func removeAnchorFromScene()
}

struct CycleToken: Equatable {
    let realityGeneration: Int
    let hideCycleGeneration: Int
}

struct PlacementSafeFloorRegion {
    let minimumXZ: SIMD2<Float>
    let maximumXZ: SIMD2<Float>

    func contains(_ point: SIMD3<Float>) -> Bool {
        point.x >= minimumXZ.x && point.x <= maximumXZ.x
            && point.z >= minimumXZ.y && point.z <= maximumXZ.y
    }
}

struct SameFrameHideObservation {
    let frameTimestamp: TimeInterval
    let isOccludedByFivePointPolicy: Bool
}

enum HideCycleEvent {
    case movementRetryStarted(destination: SIMD3<Float>, retryCount: Int)
    case verifiedHidden
    case returnedToTargetSelection
}

@MainActor
final class HideCycleRecovery {
    static let maximumUniqueFrames = 60
    static let observationDuration: TimeInterval = 1.5
    static let retryDistance: Float = 0.18
    static let maximumRetries = 2
    static let requiredStableOccludedObservations = 2

    private let session: any RealitySessionControlling
    private let scheduler: any CycleDeadlineScheduling
    private let makeResources: () -> any HideCycleResources

    private var resources: (any HideCycleResources)?
    private var deadlineTask: (any CycleDeadlineCancellable)?
    private var floorRegion: PlacementSafeFloorRegion?
    private var destination = SIMD3<Float>.zero
    private var retreatDirection = SIMD3<Float>.zero
    private var attemptStartTime: TimeInterval = 0
    private var lastFrameTimestamp: TimeInterval?
    private var uniqueFrameCount = 0
    private var stableOccludedCount = 0
    private var attemptFinished = false
    private var retryCount = 0
    private var realityGeneration = 0
    private var hideCycleGeneration = 0

    var onEvent: (HideCycleEvent) -> Void = { _ in }

    init(
        session: any RealitySessionControlling,
        scheduler: any CycleDeadlineScheduling,
        makeResources: @escaping () -> any HideCycleResources
    ) {
        self.session = session
        self.scheduler = scheduler
        self.makeResources = makeResources
    }

    @discardableResult
    func beginCycle(
        destination: SIMD3<Float>,
        retreatDirection: SIMD3<Float>,
        immutableFloorRegion: PlacementSafeFloorRegion
    ) -> CycleToken {
        tearDownCycle()
        hideCycleGeneration += 1
        self.destination = destination
        self.retreatDirection = simd_normalize(retreatDirection)
        floorRegion = immutableFloorRegion
        retryCount = 0
        resources = makeResources()
        beginAttempt(startTime: scheduler.now)
        return currentToken
    }

    func observe(
        _ observation: SameFrameHideObservation,
        now: TimeInterval,
        token: CycleToken
    ) {
        guard accepts(token),
              !attemptFinished,
              now.isFinite,
              now < attemptStartTime + Self.observationDuration,
              observation.frameTimestamp.isFinite,
              lastFrameTimestamp.map({ observation.frameTimestamp > $0 }) ?? true else {
            return
        }

        lastFrameTimestamp = observation.frameTimestamp
        uniqueFrameCount += 1
        stableOccludedCount = observation.isOccludedByFivePointPolicy
            ? stableOccludedCount + 1
            : 0

        // A successful pair on the deadline-safe 60th unique frame still wins.
        if stableOccludedCount >= Self.requiredStableOccludedObservations {
            attemptFinished = true
            deadlineTask?.cancel()
            deadlineTask = nil
            onEvent(.verifiedHidden)
        } else if uniqueFrameCount >= Self.maximumUniqueFrames {
            exhaustAttempt()
        }
    }

    func accepts(_ token: CycleToken) -> Bool {
        token == currentToken && resources != nil
    }

    func restartHideCycle() {
        tearDownCycle()
        hideCycleGeneration += 1
        onEvent(.returnedToTargetSelection)
        // The RealityKit AR session intentionally remains running.
    }

    func beginNewRealitySessionGeneration() {
        tearDownCycle()
        realityGeneration += 1
        hideCycleGeneration += 1
    }

    func stop() {
        tearDownCycle()
        hideCycleGeneration += 1
        session.pause()
    }

    private var currentToken: CycleToken {
        CycleToken(
            realityGeneration: realityGeneration,
            hideCycleGeneration: hideCycleGeneration
        )
    }

    private func beginAttempt(startTime: TimeInterval) {
        attemptStartTime = startTime
        lastFrameTimestamp = nil
        uniqueFrameCount = 0
        stableOccludedCount = 0
        attemptFinished = false
        deadlineTask?.cancel()
        let token = currentToken
        deadlineTask = scheduler.schedule(after: Self.observationDuration) { [weak self] in
            guard let self, self.accepts(token) else { return }
            self.exhaustAttempt()
        }
    }

    private func exhaustAttempt() {
        guard !attemptFinished else { return }
        attemptFinished = true
        deadlineTask?.cancel()
        deadlineTask = nil
        guard retryCount < Self.maximumRetries,
              let floorRegion else {
            returnToTargetSelection()
            return
        }

        let candidate = destination + retreatDirection * Self.retryDistance
        guard floorRegion.contains(candidate) else {
            returnToTargetSelection()
            return
        }
        retryCount += 1
        destination = candidate
        onEvent(.movementRetryStarted(destination: candidate, retryCount: retryCount))
        beginAttempt(startTime: scheduler.now)
    }

    private func returnToTargetSelection() {
        tearDownCycle()
        hideCycleGeneration += 1
        onEvent(.returnedToTargetSelection)
    }

    private func tearDownCycle() {
        deadlineTask?.cancel()
        deadlineTask = nil
        resources?.cancelPendingControllerWork()
        resources?.removeAnchorFromScene()
        resources = nil
        floorRegion = nil
        lastFrameTimestamp = nil
        uniqueFrameCount = 0
        stableOccludedCount = 0
        attemptFinished = false
    }
}
