// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/RealityScanFeedbackView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityEnvironmentReadiness.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityAcceptedSurfaceMarker.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityEnvironmentReadinessTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift
// Implementation status: integrated
// Verification: standalone iPhoneOS type-check·fresh generic Swift 5/Swift 6 strict build-for-testing·현재 Swift 5 Release build 통과; 물리 iPhone 기준 186/186 통과; 최신 190개 중 추가 4개 runtime은 device unlock 대기; UI test 0개; LiDAR 관찰·동일 기기 캡처는 실기기 대기

import RealityKit
import simd

enum RealityHideInteractionMode {
    case preparing
    case selectingTarget
    case moving
    case searching
    case revealed
}

struct RealityScanProgress: Equatable {
    static let meshLabel = "공간 형태"
    static let floorLabel = "바닥"

    let hasMesh: Bool
    let hasClassifiedFloor: Bool

    var isReady: Bool {
        hasMesh && hasClassifiedFloor
    }
}

struct RealityScanUpdate: Equatable {
    let progress: RealityScanProgress
    let becameReady: Bool
}

struct RealityScanPresentation: Equatable {
    let showsSceneUnderstanding: Bool
    let reduceMotion: Bool

    var showsAnimatedSweep: Bool {
        showsSceneUnderstanding && !reduceMotion
    }
}

struct RealityEnvironmentReadiness {
    private(set) var progress = RealityScanProgress(
        hasMesh: false,
        hasClassifiedFloor: false
    )
    private var hasReportedReady = false

    mutating func observe(
        hasMesh: Bool,
        hasClassifiedFloor: Bool
    ) -> RealityScanUpdate? {
        let next = RealityScanProgress(
            hasMesh: progress.hasMesh || hasMesh,
            hasClassifiedFloor: progress.hasClassifiedFloor || hasClassifiedFloor
        )
        guard next != progress else { return nil }
        progress = next
        let becameReady = progress.isReady && !hasReportedReady
        hasReportedReady = hasReportedReady || progress.isReady
        return RealityScanUpdate(progress: progress, becameReady: becameReady)
    }
}

struct RealitySurfaceHit {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct RealityHidePlan {}

enum RealityHidePlanResult {
    case accepted(RealityHidePlan)
    case rejected
}

struct ValidatedSurfaceSelection {
    let plan: RealityHidePlan
    let hit: RealitySurfaceHit

    fileprivate init(plan: RealityHidePlan, hit: RealitySurfaceHit) {
        self.plan = plan
        self.hit = hit
    }
}

enum ValidatedSurfaceFactory {
    static func make(
        plannerResult: RealityHidePlanResult,
        hit: RealitySurfaceHit
    ) -> ValidatedSurfaceSelection? {
        guard hit.point.allFinite,
              hit.normal.allFinite,
              case let .accepted(plan) = plannerResult else {
            return nil
        }
        return ValidatedSurfaceSelection(plan: plan, hit: hit)
    }
}

@MainActor
protocol AcceptedSurfaceMarking: AnyObject {
    func attach(to arView: ARView)
    func show(point: SIMD3<Float>, normal: SIMD3<Float>, animated: Bool)
    func cancel()
}

@MainActor
final class RealityScanGate {
    private let arView: ARView
    private let acceptedSurfaceMarker: any AcceptedSurfaceMarking
    private var readiness = RealityEnvironmentReadiness()
    private(set) var interactionMode: RealityHideInteractionMode = .preparing
    private(set) var presentation: RealityScanPresentation

    init(
        arView: ARView,
        acceptedSurfaceMarker: any AcceptedSurfaceMarking,
        reduceMotion: Bool
    ) {
        self.arView = arView
        self.acceptedSurfaceMarker = acceptedSurfaceMarker
        presentation = RealityScanPresentation(
            showsSceneUnderstanding: true,
            reduceMotion: reduceMotion
        )
        acceptedSurfaceMarker.attach(to: arView)
        arView.debugOptions.insert(.showSceneUnderstanding)
    }

    var stableARViewIdentity: ObjectIdentifier {
        ObjectIdentifier(arView)
    }

    func observe(hasMesh: Bool, hasClassifiedFloor: Bool) -> RealityScanUpdate? {
        readiness.observe(
            hasMesh: hasMesh,
            hasClassifiedFloor: hasClassifiedFloor
        )
    }

    @discardableResult
    func startChapterThree() -> Bool {
        guard interactionMode == .preparing,
              readiness.progress.isReady else { return false }
        presentation = RealityScanPresentation(
            showsSceneUnderstanding: false,
            reduceMotion: presentation.reduceMotion
        )
        arView.debugOptions.remove(.showSceneUnderstanding)
        interactionMode = .selectingTarget
        return true
    }

    @discardableResult
    func acceptValidatedSurface(
        _ selection: ValidatedSurfaceSelection
    ) -> RealityHidePlan? {
        guard interactionMode == .selectingTarget else { return nil }
        acceptedSurfaceMarker.show(
            point: selection.hit.point,
            normal: selection.hit.normal,
            animated: !presentation.reduceMotion
        )
        return selection.plan
    }

    func stop() {
        arView.debugOptions.remove(.showSceneUnderstanding)
        acceptedSurfaceMarker.cancel()
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
