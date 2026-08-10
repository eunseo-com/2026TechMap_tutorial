import simd

struct RealitySurfaceHit: Equatable {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct RealityFloor: Equatable {
    let point: SIMD3<Float>
}

enum RealityHideRejection: Equatable {
    case selectVerticalSide
    case moveFartherAway
    case findFloor
}

enum RealityHidePlanResult: Equatable {
    case accepted(SIMD3<Float>)
    case rejected(RealityHideRejection)
}

enum RealityHidePlanner {
    static let verticalNormalMaximumY: Float = 0.35
    static let minimumCameraDistance: Float = 0.45
    static let objectClearance: Float = 0.28
    static let maximumFloorDistance: Float = 1.2

    static func plan(
        hit: RealitySurfaceHit,
        cameraPosition: SIMD3<Float>,
        floor: RealityFloor?
    ) -> RealityHidePlanResult {
        guard abs(hit.normal.y) <= verticalNormalMaximumY else {
            return .rejected(.selectVerticalSide)
        }
        guard simd_distance(hit.point, cameraPosition) >= minimumCameraDistance else {
            return .rejected(.moveFartherAway)
        }
        guard let floor else {
            return .rejected(.findFloor)
        }

        let floorOffset = SIMD2(hit.point.x - floor.point.x, hit.point.z - floor.point.z)
        guard simd_length(floorOffset) <= maximumFloorDistance else {
            return .rejected(.findFloor)
        }
        guard simd_length_squared(hit.normal) > 0.0001 else {
            return .rejected(.selectVerticalSide)
        }

        let normal = simd_normalize(hit.normal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0 ? normal : -normal
        let hiddenPoint = hit.point - towardCamera * objectClearance
        return .accepted(SIMD3(hiddenPoint.x, floor.point.y, hiddenPoint.z))
    }
}

struct RealityRevealMonitor {
    private var hasObservedBlockingMesh = false
    private var hasReportedReveal = false

    mutating func update(meshDistance: Float?, pigDistance: Float) -> Bool {
        let blocked = meshDistance.map { $0 + 0.03 < pigDistance } ?? false
        hasObservedBlockingMesh = hasObservedBlockingMesh || blocked
        guard hasObservedBlockingMesh, !blocked, !hasReportedReveal else {
            return false
        }
        hasReportedReveal = true
        return true
    }
}
