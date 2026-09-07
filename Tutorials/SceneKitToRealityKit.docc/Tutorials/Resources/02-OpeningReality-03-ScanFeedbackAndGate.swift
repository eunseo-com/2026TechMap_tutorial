// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityScanTelemetry.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityMeshScanProjector.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityTargetPreview.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityScanTelemetryTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityTargetPreviewTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift

import CoreGraphics
import Foundation
import simd

enum ScanTrackingStatus: Equatable {
    case initializing, normal, excessiveMotion, insufficientFeatures
    case relocalizing, unavailable
}

/// This is a current observation, not a percentage or semantic object count.
struct CurrentScanTelemetry: Equatable {
    let timestamp: TimeInterval
    let meshAnchorCount: Int
    let meshFaceCount: Int
    let floorAnchorCount: Int
    let tracking: ScanTrackingStatus

    static let empty = CurrentScanTelemetry(
        timestamp: 0, meshAnchorCount: 0, meshFaceCount: 0,
        floorAnchorCount: 0, tracking: .initializing
    )

    var canSelectTargets: Bool {
        tracking == .normal && meshAnchorCount > 0 && floorAnchorCount > 0
    }

    fileprivate var isValid: Bool {
        timestamp.isFinite && timestamp >= 0 && meshAnchorCount >= 0
            && meshFaceCount >= 0 && floorAnchorCount >= 0
    }
}

/// Ordinary updates are limited to 4 Hz. Tracking and readiness changes publish
/// immediately, while the same ARFrame timestamp never counts twice.
struct CurrentScanTelemetryTracker {
    static let minimumUpdateInterval: TimeInterval = 0.25
    private(set) var latest = CurrentScanTelemetry.empty
    private var lastObservedTimestamp: TimeInterval?
    private var lastPublishedTimestamp: TimeInterval?

    mutating func observe(_ sample: CurrentScanTelemetry) -> CurrentScanTelemetry? {
        guard sample.isValid,
              lastObservedTimestamp.map({ sample.timestamp > $0 }) ?? true else {
            return nil
        }
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
}

/// Readiness remembers the first successful mesh-and-floor observation.
/// It intentionally does not replace the current telemetry above.
struct FirstReadyLatch {
    private var hasMesh = false
    private var hasFloor = false
    private var hasReportedReady = false

    var isReady: Bool { hasMesh && hasFloor }

    mutating func observe(_ telemetry: CurrentScanTelemetry) -> Bool {
        guard telemetry.tracking == .normal else { return false }
        hasMesh = hasMesh || telemetry.meshAnchorCount > 0
        hasFloor = hasFloor || telemetry.floorAnchorCount > 0
        let becameReady = isReady && !hasReportedReady
        hasReportedReady = hasReportedReady || isReady
        return becameReady
    }
}

/// Production projects these selected real faces and strokes their three edges.
/// No opaque fill or geometry between measured triangles is synthesized.
enum ScanMeshOverlayPolicy {
    static let maximumTriangleCount = 120

    static func selectedFaceIndices(totalFaceCount: Int) -> [Int] {
        guard totalFaceCount > 0 else { return [] }
        let step = max(1, Int(ceil(Double(totalFaceCount) / 120)))
        return Array(stride(from: 0, to: totalFaceCount, by: step).prefix(120))
    }
}

struct MeasuredSurfaceHit {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct ValidatedHidePlan {}

enum SurfaceRejection { case noSurface, wrongSide, tooClose, needsFloor }
enum SurfaceValidation {
    case accepted(ValidatedHidePlan)
    case rejected(SurfaceRejection)
}
enum TargetPreview {
    case inactive, rejected(SurfaceRejection), ready(distance: Float)
}
enum ScanInteractionMode { case preparing, selectingTarget }

/// ARView supplies the center hit for preview and a fresh hit at the tap point.
/// The validator owns the vertical-side, 0.90m, floor and route checks.
struct ScanFrameInput {
    let telemetry: CurrentScanTelemetry
    let cameraPosition: SIMD3<Float>
    let centerHit: MeasuredSurfaceHit?
    let hitAtPoint: (CGPoint) -> MeasuredSurfaceHit?
}

struct ScanFeedbackAndGate {
    typealias Validator = (MeasuredSurfaceHit, SIMD3<Float>) -> SurfaceValidation

    private var readiness = FirstReadyLatch()
    private var tracker = CurrentScanTelemetryTracker()
    private(set) var mode = ScanInteractionMode.preparing

    mutating func observe(_ telemetry: CurrentScanTelemetry) -> (
        current: CurrentScanTelemetry?,
        becameReady: Bool
    ) {
        let current = tracker.observe(telemetry)
        return (current, readiness.observe(telemetry))
    }

    var canStartChapterThreeNow: Bool {
        mode == .preparing && readiness.isReady && tracker.latest.canSelectTargets
    }

    mutating func startChapterThree() -> Bool {
        guard canStartChapterThreeNow else { return false }
        mode = .selectingTarget
        return true
    }

    func previewCenterHit(
        _ frame: ScanFrameInput,
        validate: Validator
    ) -> TargetPreview {
        guard mode == .selectingTarget else { return .inactive }
        guard frame.telemetry.tracking == .normal,
              let hit = frame.centerHit else { return .rejected(.noSurface) }
        switch validate(hit, frame.cameraPosition) {
        case .accepted:
            return .ready(distance: simd_distance(hit.point, frame.cameraPosition))
        case let .rejected(reason):
            return .rejected(reason)
        }
    }

    /// Preview is advisory: tap acceptance re-runs the hit and every plan check.
    func acceptTap(
        at point: CGPoint,
        frame: ScanFrameInput,
        validate: Validator,
        fullRouteIsClear: (ValidatedHidePlan) -> Bool
    ) -> ValidatedHidePlan? {
        guard mode == .selectingTarget,
              frame.telemetry.tracking == .normal,
              let tappedHit = frame.hitAtPoint(point),
              case let .accepted(plan) = validate(tappedHit, frame.cameraPosition),
              fullRouteIsClear(plan) else { return nil }
        return plan
    }
}
