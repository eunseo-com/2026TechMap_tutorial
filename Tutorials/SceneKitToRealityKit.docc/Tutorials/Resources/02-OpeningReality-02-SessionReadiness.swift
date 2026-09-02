// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityEnvironmentReadiness.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityDeadlineScheduler.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityEnvironmentReadinessTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityDeadlineSchedulerTests.swift

import ARKit
import CoreGraphics
import Foundation

struct ARSessionStartGate {
    private var hasStarted = false

    mutating func consumeIfReady(
        hasWindow: Bool,
        containerBounds: CGRect,
        arViewBounds: CGRect
    ) -> Bool {
        guard !hasStarted,
              hasWindow,
              !containerBounds.isEmpty,
              !arViewBounds.isEmpty else {
            return false
        }
        hasStarted = true
        return true
    }
}

struct RoomReadinessUpdate {
    let hasMesh: Bool
    let hasClassifiedHorizontalFloor: Bool
    let becameReady: Bool
}

struct RoomReadiness {
    private var hasMesh = false
    private var hasClassifiedHorizontalFloor = false
    private var hasReportedReady = false

    mutating func observe(anchors: [ARAnchor]) -> RoomReadinessUpdate {
        hasMesh = hasMesh || anchors.contains { $0 is ARMeshAnchor }
        hasClassifiedHorizontalFloor = hasClassifiedHorizontalFloor || anchors.contains { anchor in
            guard let plane = anchor as? ARPlaneAnchor else { return false }
            return plane.alignment == .horizontal && plane.classification == .floor
        }

        let isReady = hasMesh && hasClassifiedHorizontalFloor
        let becameReady = isReady && !hasReportedReady
        hasReportedReady = hasReportedReady || isReady
        return RoomReadinessUpdate(
            hasMesh: hasMesh,
            hasClassifiedHorizontalFloor: hasClassifiedHorizontalFloor,
            becameReady: becameReady
        )
    }
}

enum RealityDeadline {
    case scan
    case interruption

    var duration: TimeInterval {
        switch self {
        case .scan: return 20.0
        case .interruption: return 10.0
        }
    }
}

enum RealitySessionRecovery {
    case keepScanning
    case retryWithNewSession
    case skipToComparison
}
