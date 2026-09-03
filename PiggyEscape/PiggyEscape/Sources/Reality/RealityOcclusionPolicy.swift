import Foundation
import simd

enum PigOcclusionSampleID: CaseIterable, Hashable {
    case center
    case top
    case bottom
    case left
    case right
}

enum PigOcclusionSampler {
    static let supportInset: Float = 0.8

    static func samples(
        boundsCorners: [SIMD3<Float>],
        cameraRight: SIMD3<Float>,
        cameraUp: SIMD3<Float>
    ) -> [PigOcclusionSampleID: SIMD3<Float>]? {
        guard boundsCorners.count == 8,
              boundsCorners.allSatisfy(\.allFinite),
              Set(boundsCorners).count == 8,
              hasThreeDimensionalSpan(boundsCorners),
              let right = normalized(cameraRight),
              let up = normalized(cameraUp),
              simd_length_squared(simd_cross(right, up)) > 0.000_001 else {
            return nil
        }

        var minimum = boundsCorners[0]
        var maximum = boundsCorners[0]
        for corner in boundsCorners.dropFirst() {
            minimum = simd_min(minimum, corner)
            maximum = simd_max(maximum, corner)
        }
        let extent = maximum - minimum
        guard extent.allFinite,
              extent.x > 0.000_001,
              extent.y > 0.000_001,
              extent.z > 0.000_001 else {
            return nil
        }

        let center = (minimum + maximum) / 2
        guard let topSupport = supportPoint(in: boundsCorners, direction: up, maximum: true),
              let bottomSupport = supportPoint(in: boundsCorners, direction: up, maximum: false),
              let rightSupport = supportPoint(in: boundsCorners, direction: right, maximum: true),
              let leftSupport = supportPoint(in: boundsCorners, direction: right, maximum: false) else {
            return nil
        }

        let result: [PigOcclusionSampleID: SIMD3<Float>] = [
            .center: center,
            .top: center + (topSupport - center) * supportInset,
            .bottom: center + (bottomSupport - center) * supportInset,
            .left: center + (leftSupport - center) * supportInset,
            .right: center + (rightSupport - center) * supportInset,
        ]
        return result.values.allSatisfy(\.allFinite) ? result : nil
    }

    private static func hasThreeDimensionalSpan(_ corners: [SIMD3<Float>]) -> Bool {
        let origin = SIMD3<Double>(corners[0])
        let offsets = corners.dropFirst().map { SIMD3<Double>($0) - origin }

        for firstIndex in offsets.indices {
            let firstLength = simd_length(offsets[firstIndex])
            guard firstLength.isFinite, firstLength > 0 else { continue }
            let first = offsets[firstIndex] / firstLength

            for secondIndex in offsets.indices where secondIndex > firstIndex {
                let secondLength = simd_length(offsets[secondIndex])
                guard secondLength.isFinite, secondLength > 0 else { continue }
                let second = offsets[secondIndex] / secondLength

                for thirdIndex in offsets.indices where thirdIndex > secondIndex {
                    let thirdLength = simd_length(offsets[thirdIndex])
                    guard thirdLength.isFinite, thirdLength > 0 else { continue }
                    let third = offsets[thirdIndex] / thirdLength
                    let normalizedVolume = abs(simd_dot(first, simd_cross(second, third)))
                    if normalizedVolume.isFinite, normalizedVolume > 0.000_001 {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float>? {
        guard vector.allFinite else { return nil }
        let lengthSquared = simd_length_squared(vector)
        guard lengthSquared.isFinite, lengthSquared > 0.000_001 else { return nil }
        let result = vector / sqrt(lengthSquared)
        return result.allFinite ? result : nil
    }

    private static func supportPoint(
        in corners: [SIMD3<Float>],
        direction: SIMD3<Float>,
        maximum: Bool
    ) -> SIMD3<Float>? {
        let projections = corners.map { simd_dot($0, direction) }
        guard projections.allSatisfy(\.isFinite),
              let target = maximum ? projections.max() : projections.min() else {
            return nil
        }
        let tolerance = Swift.max(1, abs(target)) * 0.000_001
        let supports = zip(corners, projections).compactMap { corner, projection in
            abs(projection - target) <= tolerance ? corner : nil
        }
        guard !supports.isEmpty else { return nil }
        return supports.reduce(SIMD3<Float>.zero, +) / Float(supports.count)
    }
}

enum OcclusionSampleState: Equatable {
    static let meshSafetyMargin: Float = 0.03

    case blocked
    case visible
    case invalid

    static func classify(
        pigDistance: Float?,
        meshDistance: Float?
    ) -> OcclusionSampleState {
        guard let pigDistance,
              pigDistance.isFinite,
              pigDistance > 0 else {
            return .invalid
        }
        guard let meshDistance else { return .visible }
        guard meshDistance.isFinite, meshDistance >= 0 else { return .invalid }
        let distanceDifference = pigDistance - meshDistance
        guard distanceDifference.isFinite else { return .invalid }
        return distanceDifference > meshSafetyMargin ? .blocked : .visible
    }
}

struct RealityCameraPose: Equatable {
    let position: SIMD3<Float>
    let forward: SIMD3<Float>

    fileprivate var isValid: Bool {
        guard position.allFinite, forward.allFinite else { return false }
        let forwardLengthSquared = simd_length_squared(forward)
        return forwardLengthSquared.isFinite && forwardLengthSquared > 0.000_001
    }
}

struct RealityOcclusionObservation: Equatable {
    let frameTimestamp: TimeInterval
    let samples: [PigOcclusionSampleID: OcclusionSampleState]
    let cameraPose: RealityCameraPose?

    fileprivate var hasFiveValidSamples: Bool {
        PigOcclusionSampleID.allCases.allSatisfy { sampleID in
            guard let state = samples[sampleID] else { return false }
            return state != .invalid
        }
    }

    fileprivate func count(_ state: OcclusionSampleState) -> Int {
        PigOcclusionSampleID.allCases.reduce(into: 0) { count, sampleID in
            if samples[sampleID] == state {
                count += 1
            }
        }
    }
}

enum StableHideMonitorUpdate: Equatable {
    case waiting
    case hidden(referencePose: RealityCameraPose)
    case exhausted
}

struct StableHideMonitor {
    static let requiredStableOccludedObservations = 2
    static let maximumUniqueFrames = 60
    static let observationDuration: TimeInterval = 1.5

    private let deadline: TimeInterval
    private var lastFrameTimestamp: TimeInterval?
    private var stableOccludedObservationCount = 0
    private var hasFinished = false
    private(set) var uniqueFrameCount = 0

    init(startTime: TimeInterval) {
        deadline = startTime + Self.observationDuration
    }

    mutating func update(
        _ observation: RealityOcclusionObservation,
        now: TimeInterval
    ) -> StableHideMonitorUpdate {
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

        if isOccluded(observation) {
            stableOccludedObservationCount += 1
        } else {
            stableOccludedObservationCount = 0
        }

        if stableOccludedObservationCount >= Self.requiredStableOccludedObservations,
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

    mutating func deadlineElapsed(at now: TimeInterval) -> StableHideMonitorUpdate {
        guard !hasFinished else { return .waiting }
        guard !now.isFinite || !deadline.isFinite || now >= deadline else {
            return .waiting
        }
        hasFinished = true
        return .exhausted
    }

    private func isOccluded(_ observation: RealityOcclusionObservation) -> Bool {
        guard let cameraPose = observation.cameraPose,
              cameraPose.isValid,
              observation.hasFiveValidSamples,
              observation.samples[.center] == .blocked else {
            return false
        }
        return observation.count(.blocked) >= 4
    }
}

struct RealityRevealMonitor {
    static let minimumTranslation: Float = 0.15
    static let minimumRotation: Float = .pi / 12
    static let requiredStableVisibleObservations = 2

    private var referencePose: RealityCameraPose?
    private var lastFrameTimestamp: TimeInterval?
    private var stableVisibleObservationCount = 0
    private var hasReportedReveal = false
    private var legacyTimestamp: TimeInterval = 0
    private(set) var hasMeaningfulViewpointChange = false

    init(referencePose: RealityCameraPose) {
        self.referencePose = referencePose
    }

    init() {
        referencePose = nil
    }

    mutating func update(_ observation: RealityOcclusionObservation) -> Bool {
        guard !hasReportedReveal,
              observation.frameTimestamp.isFinite,
              lastFrameTimestamp.map({ observation.frameTimestamp > $0 }) ?? true else {
            return false
        }
        lastFrameTimestamp = observation.frameTimestamp

        guard let currentPose = observation.cameraPose,
              currentPose.isValid else {
            stableVisibleObservationCount = 0
            return false
        }

        if !hasMeaningfulViewpointChange,
           let referencePose,
           hasMeaningfulViewpointChange(from: referencePose, to: currentPose) {
            hasMeaningfulViewpointChange = true
        }

        guard hasMeaningfulViewpointChange,
              observation.hasFiveValidSamples,
              observation.samples[.center] == .visible,
              observation.count(.visible) >= 3 else {
            stableVisibleObservationCount = 0
            return false
        }

        stableVisibleObservationCount += 1
        guard stableVisibleObservationCount >= Self.requiredStableVisibleObservations else {
            return false
        }
        hasReportedReveal = true
        return true
    }

    // Task 6 replaces this one-ray adapter with same-frame five-point observations.
    mutating func update(
        meshDistance: Float?,
        pigDistance: Float,
        cameraPose: RealityCameraPose
    ) -> Bool {
        legacyTimestamp += 1
        let sampleState = OcclusionSampleState.classify(
            pigDistance: pigDistance,
            meshDistance: meshDistance
        )
        if referencePose == nil {
            if sampleState == .blocked, cameraPose.isValid {
                referencePose = cameraPose
            }
            stableVisibleObservationCount = 0
            return false
        }
        let samples = Dictionary(
            uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { ($0, sampleState) }
        )
        return update(RealityOcclusionObservation(
            frameTimestamp: legacyTimestamp,
            samples: samples,
            cameraPose: cameraPose
        ))
    }

    mutating func recordInvalidObservation() {
        stableVisibleObservationCount = 0
    }

    private func hasMeaningfulViewpointChange(
        from referencePose: RealityCameraPose,
        to currentPose: RealityCameraPose
    ) -> Bool {
        guard referencePose.isValid, currentPose.isValid else { return false }
        let translation = simd_distance(referencePose.position, currentPose.position)
        guard translation.isFinite else { return false }
        if translation >= Self.minimumTranslation {
            return true
        }

        let referenceForward = simd_normalize(referencePose.forward)
        let currentForward = simd_normalize(currentPose.forward)
        let directionsDot = simd_clamp(simd_dot(referenceForward, currentForward), -1, 1)
        return directionsDot <= cos(Self.minimumRotation).nextUp
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
