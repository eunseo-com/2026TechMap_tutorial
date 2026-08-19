import UIKit
import RealityKit
import simd

struct RealitySurfaceHit {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct RealityFloor {
    let point: SIMD3<Float>
}

enum RealityHidePlanResult {
    case accepted(SIMD3<Float>)
    case selectVerticalSide
    case moveFartherAway
    case findFloor
}

enum RealityHidePlanner {
    static func plan(
        hit: RealitySurfaceHit,
        cameraPosition: SIMD3<Float>,
        floor: RealityFloor?
    ) -> RealityHidePlanResult {
        guard abs(hit.normal.y) <= 0.35 else { return .selectVerticalSide }
        guard simd_distance(hit.point, cameraPosition) >= 0.45 else {
            return .moveFartherAway
        }
        guard let floor else { return .findFloor }

        let normal = simd_normalize(hit.normal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0
            ? normal : -normal
        let hiddenPoint = hit.point - towardCamera * 0.28
        return .accepted(SIMD3(hiddenPoint.x, floor.point.y, hiddenPoint.z))
    }
}

func selectHideTarget(at point: CGPoint, in arView: ARView) {
    guard let hit = arView.hitTest(
        point, query: .nearest, mask: .sceneUnderstanding
    ).first else { return }
    // 실제 구현은 현재 ARFrame에서 hit 근처의 수평 floor도 찾아 plan에 전달한다.
    _ = RealitySurfaceHit(point: hit.position, normal: hit.normal)
}
