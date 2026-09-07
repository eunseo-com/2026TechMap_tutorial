import Foundation
import simd

/// A measured surface candidate, not semantic recognition or a promise of occlusion.
enum RealityTargetPreview: Equatable {
    case inactive
    case noSurface
    case tracking(RealityTrackingStatus)
    case rejected(RealityHideRejection)
    case ready(distance: Float)

    var isSelectable: Bool {
        if case .ready = self { return true }
        return false
    }

    var guidance: String {
        switch self {
        case .inactive, .noSurface: "물체의 옆면과 그 아래 바닥을 천천히 비춰줘"
        case let .tracking(status): status.guidance
        case .rejected(.moveFartherAway): "너무 가까워. 한 걸음 뒤에서 옆면을 비춰줘"
        case .rejected(.findFloor): "물체 아래와 양옆의 바닥을 더 비춰줘"
        case .rejected(.selectVerticalSide): "바닥이나 윗면 말고 물체의 세로 옆면을 비춰줘"
        case .ready: "선택 가능한 옆면이야. 이 표면을 탭해줘"
        }
    }

    static func evaluate(
        hit: RealitySurfaceHit?,
        cameraPosition: SIMD3<Float>,
        floorRegion: RealityFloorRegion?,
        tracking: RealityTrackingStatus
    ) -> Self {
        guard tracking == .normal else { return .tracking(tracking) }
        guard let hit else { return .noSurface }
        switch RealityHidePlanner.plan(hit: hit, cameraPosition: cameraPosition, floorRegion: floorRegion) {
        case let .rejected(reason): return .rejected(reason)
        case .accepted: return .ready(distance: simd_distance(hit.point, cameraPosition))
        }
    }
}
