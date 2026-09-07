import Foundation

enum RealityTrackingStatus: Equatable {
    case initializing, normal, excessiveMotion, insufficientFeatures, relocalizing, unavailable

    var guidance: String {
        switch self {
        case .normal: "카메라 추적 중"
        case .initializing: "주변과 바닥을 천천히 비춰줘"
        case .excessiveMotion: "조금 더 천천히 움직여줘"
        case .insufficientFeatures: "밝은 곳에서 무늬 있는 물체를 비춰줘"
        case .relocalizing: "방금 보던 공간을 다시 비춰줘"
        case .unavailable: "카메라 추적을 기다리고 있어"
        }
    }
}

/// Current observations, not a percentage of the room or a semantic object detector.
struct RealityScanTelemetry: Equatable {
    let timestamp: TimeInterval
    let meshAnchorCount: Int
    let meshFaceCount: Int
    let floorAnchorCount: Int
    let tracking: RealityTrackingStatus

    static let empty = RealityScanTelemetry(timestamp: 0, meshAnchorCount: 0,
                                          meshFaceCount: 0, floorAnchorCount: 0,
                                          tracking: .initializing)

    var canSelectTargets: Bool {
        tracking == .normal && meshAnchorCount > 0 && floorAnchorCount > 0
    }

    fileprivate var isValid: Bool {
        timestamp.isFinite && timestamp >= 0 && meshAnchorCount >= 0
            && meshFaceCount >= 0 && floorAnchorCount >= 0
    }
}

/// The original readiness gate latches the first successful scan. This tracker instead
/// keeps current geometry/tracking, so a lost floor or tracking loss is visible immediately.
struct RealityScanTelemetryTracker {
    static let minimumUpdateInterval: TimeInterval = 0.25
    private(set) var latest = RealityScanTelemetry.empty
    private var lastObservedTimestamp: TimeInterval?
    private var lastPublishedTimestamp: TimeInterval?

    mutating func observe(_ sample: RealityScanTelemetry) -> RealityScanTelemetry? {
        guard sample.isValid,
              lastObservedTimestamp.map({ sample.timestamp > $0 }) ?? true else { return nil }
        lastObservedTimestamp = sample.timestamp
        let readinessChanged = (sample.meshAnchorCount > 0) != (latest.meshAnchorCount > 0)
            || (sample.floorAnchorCount > 0) != (latest.floorAnchorCount > 0)
        let urgent = sample.tracking != latest.tracking || readinessChanged
        guard urgent || lastPublishedTimestamp.map({
            sample.timestamp - $0 >= Self.minimumUpdateInterval
        }) ?? true else { return nil }
        latest = sample
        lastPublishedTimestamp = sample.timestamp
        return sample
    }

    mutating func reset() {
        self = RealityScanTelemetryTracker()
    }
}

/// Normalized viewport coordinates from real AR mesh triangles; never synthetic coverage.
struct RealityScanPatch: Equatable {
    let a: CGPoint
    let b: CGPoint
    let c: CGPoint
    let isFloor: Bool
}

struct RealityScanVisualization: Equatable {
    var telemetry = RealityScanTelemetry.empty
    var patches: [RealityScanPatch] = []
    var targetPreview = RealityTargetPreview.inactive
    var selectionFeedback: String?
    static let empty = RealityScanVisualization()
}
