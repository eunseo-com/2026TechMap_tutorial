// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionPolicy.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityOcclusionPolicyTests.swift

import Foundation
import simd

enum PigOcclusionSampleID: CaseIterable, Hashable {
    case center
    case top
    case bottom
    case left
    case right
}

enum OcclusionSampleState {
    static let meshSafetyMargin: Float = 0.03

    case blocked
    case visible
    case invalid

    static func classify(
        pigDistance: Float?,
        meshDistance: Float?
    ) -> OcclusionSampleState {
        guard let pigDistance, pigDistance.isFinite, pigDistance > 0 else {
            return .invalid
        }
        guard let meshDistance else { return .visible }
        guard meshDistance.isFinite, meshDistance >= 0 else { return .invalid }
        let distanceDifference = pigDistance - meshDistance
        guard distanceDifference.isFinite else { return .invalid }
        return distanceDifference > meshSafetyMargin ? .blocked : .visible
    }
}

struct CameraPose {
    let position: SIMD3<Float>
    let forward: SIMD3<Float>

    var isValid: Bool {
        guard position.allFinite, forward.allFinite else { return false }
        let lengthSquared = simd_length_squared(forward)
        return lengthSquared.isFinite && lengthSquared > 0.000_001
    }
}

struct OcclusionObservation {
    let frameTimestamp: TimeInterval
    let samples: [PigOcclusionSampleID: OcclusionSampleState]
    let cameraPose: CameraPose?

    var hasFiveValidSamples: Bool {
        PigOcclusionSampleID.allCases.allSatisfy { id in
            guard let state = samples[id] else { return false }
            return state != .invalid
        }
    }

    func count(_ state: OcclusionSampleState) -> Int {
        PigOcclusionSampleID.allCases.reduce(into: 0) { result, id in
            if samples[id] == state { result += 1 }
        }
    }
}

enum StableHideUpdate {
    case waiting
    case hidden(referencePose: CameraPose)
    case exhausted
}

struct StableHideMonitor {
    static let requiredStableObservations = 2
    static let maximumUniqueFrames = 60
    static let observationDuration: TimeInterval = 1.5

    private let deadline: TimeInterval
    private var lastFrameTimestamp: TimeInterval?
    private var stableCount = 0
    private var uniqueFrameCount = 0
    private var hasFinished = false

    init(startTime: TimeInterval) {
        deadline = startTime + Self.observationDuration
    }

    mutating func update(
        _ observation: OcclusionObservation,
        now: TimeInterval
    ) -> StableHideUpdate {
        guard !hasFinished else { return .waiting }
        guard now.isFinite, deadline.isFinite, now < deadline else {
            hasFinished = true
            return .exhausted
        }
        guard observation.frameTimestamp.isFinite,
              lastFrameTimestamp.map({ observation.frameTimestamp > $0 }) ?? true else {
            return .waiting
        }

        lastFrameTimestamp = observation.frameTimestamp
        uniqueFrameCount += 1
        let isOccluded = observation.cameraPose?.isValid == true
            && observation.hasFiveValidSamples
            && observation.samples[.center] == .blocked
            && observation.count(.blocked) >= 4
        stableCount = isOccluded ? stableCount + 1 : 0

        if stableCount >= Self.requiredStableObservations,
           let referencePose = observation.cameraPose {
            hasFinished = true
            return .hidden(referencePose: referencePose)
        }
        if uniqueFrameCount >= Self.maximumUniqueFrames {
            hasFinished = true
            return .exhausted
        }
        return .waiting
    }

    mutating func deadlineElapsed(at now: TimeInterval) -> StableHideUpdate {
        guard !hasFinished else { return .waiting }
        guard !now.isFinite || !deadline.isFinite || now >= deadline else {
            return .waiting
        }
        hasFinished = true
        return .exhausted
    }
}

struct StableRevealMonitor {
    static let minimumTranslation: Float = 0.15
    static let minimumRotation: Float = .pi / 12
    static let requiredStableObservations = 2

    private let referencePose: CameraPose
    private var lastFrameTimestamp: TimeInterval?
    private var stableVisibleCount = 0
    private var hasReportedReveal = false
    private(set) var hasMeaningfulViewpointChange = false

    init(referencePose: CameraPose) {
        self.referencePose = referencePose
    }

    mutating func update(_ observation: OcclusionObservation) -> Bool {
        guard !hasReportedReveal,
              observation.frameTimestamp.isFinite,
              lastFrameTimestamp.map({ observation.frameTimestamp > $0 }) ?? true else {
            return false
        }
        lastFrameTimestamp = observation.frameTimestamp

        guard let currentPose = observation.cameraPose, currentPose.isValid else {
            stableVisibleCount = 0
            return false
        }
        if !hasMeaningfulViewpointChange,
           movedEnough(from: referencePose, to: currentPose) {
            hasMeaningfulViewpointChange = true
        }

        let isRevealed = hasMeaningfulViewpointChange
            && observation.hasFiveValidSamples
            && observation.samples[.center] == .visible
            && observation.count(.visible) >= 3
        stableVisibleCount = isRevealed ? stableVisibleCount + 1 : 0
        guard stableVisibleCount >= Self.requiredStableObservations else { return false }
        hasReportedReveal = true
        return true
    }

    private func movedEnough(from reference: CameraPose, to current: CameraPose) -> Bool {
        guard reference.isValid, current.isValid else { return false }
        let translation = simd_distance(reference.position, current.position)
        if translation.isFinite, translation >= Self.minimumTranslation {
            return true
        }
        let referenceForward = simd_normalize(reference.forward)
        let currentForward = simd_normalize(current.forward)
        let dot = simd_clamp(simd_dot(referenceForward, currentForward), -1, 1)
        return dot <= cos(Self.minimumRotation).nextUp
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
