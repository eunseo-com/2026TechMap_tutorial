import Foundation
import simd

struct RealitySurfaceHit: Equatable {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct RealityFloorRegion: Equatable {
    static let surfaceFootprintTolerance: Float = 0.02
    static let placementInset: Float = 0.10

    let anchorIdentifier: UUID
    let transform: simd_float4x4
    let center: SIMD3<Float>
    let extent: SIMD2<Float>
    let rotationOnYAxis: Float

    init(
        anchorIdentifier: UUID,
        transform: simd_float4x4,
        center: SIMD3<Float>,
        extent: SIMD2<Float>,
        rotationOnYAxis: Float = 0
    ) {
        self.anchorIdentifier = anchorIdentifier
        self.transform = transform
        self.center = center
        self.extent = extent
        self.rotationOnYAxis = rotationOnYAxis
    }

    func containsSurfaceXZ(_ worldPoint: SIMD3<Float>) -> Bool {
        contains(worldPoint, edgeAdjustment: Self.surfaceFootprintTolerance)
    }

    func containsPlacementXZ(_ worldPoint: SIMD3<Float>) -> Bool {
        contains(worldPoint, edgeAdjustment: -Self.placementInset)
    }

    func pointOnFloor(projecting worldPoint: SIMD3<Float>) -> SIMD3<Float>? {
        guard let local = localPoint(for: worldPoint) else { return nil }
        let floorWorld = transform * SIMD4(local.x, center.y, local.z, 1)
        let result = SIMD3(floorWorld.x, floorWorld.y, floorWorld.z)
        return result.allFinite ? result : nil
    }

    private func contains(_ worldPoint: SIMD3<Float>, edgeAdjustment: Float) -> Bool {
        guard let local = localPoint(for: worldPoint),
              rotationOnYAxis.isFinite,
              extent.x.isFinite,
              extent.y.isFinite else { return false }

        let relativeX = local.x - center.x
        let relativeZ = local.z - center.z
        let cosine = cos(rotationOnYAxis)
        let sine = sin(rotationOnYAxis)
        let xOffset = abs(cosine * relativeX - sine * relativeZ)
        let zOffset = abs(sine * relativeX + cosine * relativeZ)
        let maximumX = extent.x / 2 + edgeAdjustment
        let maximumZ = extent.y / 2 + edgeAdjustment
        return maximumX >= 0
            && maximumZ >= 0
            && xOffset <= maximumX
            && zOffset <= maximumZ
    }

    private func localPoint(for worldPoint: SIMD3<Float>) -> SIMD3<Float>? {
        guard worldPoint.allFinite, transform.allFinite else { return nil }
        let local = simd_inverse(transform) * SIMD4(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let result = SIMD3(local.x, local.y, local.z)
        return result.allFinite ? result : nil
    }

    static func == (lhs: RealityFloorRegion, rhs: RealityFloorRegion) -> Bool {
        lhs.anchorIdentifier == rhs.anchorIdentifier
            && lhs.transform.columns.0 == rhs.transform.columns.0
            && lhs.transform.columns.1 == rhs.transform.columns.1
            && lhs.transform.columns.2 == rhs.transform.columns.2
            && lhs.transform.columns.3 == rhs.transform.columns.3
            && lhs.center == rhs.center
            && lhs.extent == rhs.extent
            && lhs.rotationOnYAxis == rhs.rotationOnYAxis
    }
}

enum RealityHideRejection: Equatable {
    case selectVerticalSide
    case moveFartherAway
    case findFloor
}

enum RealityHidePlanResult: Equatable {
    case accepted(RealityHidePlan)
    case rejected(RealityHideRejection)
}

struct RealityHidePlan: Equatable {
    let start: SIMD3<Float>
    let destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let floorRegion: RealityFloorRegion
}

struct RealityHideAttempt: Equatable {
    let destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let floorRegion: RealityFloorRegion
    let retryCount: Int

    init(plan: RealityHidePlan) {
        destination = plan.destination
        retreatDirection = plan.retreatDirection
        floorRegion = plan.floorRegion
        retryCount = 0
    }

    init(
        destination: SIMD3<Float>,
        retreatDirection: SIMD3<Float>,
        floorRegion: RealityFloorRegion,
        retryCount: Int
    ) {
        self.destination = destination
        self.retreatDirection = retreatDirection
        self.floorRegion = floorRegion
        self.retryCount = retryCount
    }
}

enum RealityHideVerificationDecision: Equatable {
    case hidden
    case retry(RealityHideAttempt)
    case selectAnotherTarget
}

enum RealityHideVerificationPolicy {
    static let meshSafetyMargin: Float = 0.03
    static let retryDistance: Float = 0.18
    static let maximumRetries = 2

    static func decide(
        meshDistance: Float?,
        pigDistance: Float,
        attempt: RealityHideAttempt
    ) -> RealityHideVerificationDecision {
        if let meshDistance, meshDistance + meshSafetyMargin < pigDistance {
            return .hidden
        }
        guard attempt.retryCount < maximumRetries else {
            return .selectAnotherTarget
        }
        let candidate = attempt.destination + attempt.retreatDirection * retryDistance
        guard attempt.floorRegion.containsPlacementXZ(candidate) else {
            return .selectAnotherTarget
        }
        return .retry(RealityHideAttempt(
            destination: candidate,
            retreatDirection: attempt.retreatDirection,
            floorRegion: attempt.floorRegion,
            retryCount: attempt.retryCount + 1
        ))
    }
}

enum RealityHidePlanner {
    static let verticalNormalMaximumY: Float = 0.35
    static let minimumCameraDistance: Float = 0.90
    static let objectClearance: Float = 0.28

    static func plan(
        hit: RealitySurfaceHit,
        cameraPosition: SIMD3<Float>,
        floorRegion: RealityFloorRegion?
    ) -> RealityHidePlanResult {
        guard hit.point.allFinite,
              hit.normal.allFinite,
              cameraPosition.allFinite,
              abs(hit.normal.y) <= verticalNormalMaximumY else {
            return .rejected(.selectVerticalSide)
        }
        let cameraDistance = simd_distance(hit.point, cameraPosition)
        guard cameraDistance.isFinite,
              cameraDistance >= minimumCameraDistance else {
            return .rejected(.moveFartherAway)
        }
        guard let floorRegion,
              floorRegion.containsSurfaceXZ(hit.point) else {
            return .rejected(.findFloor)
        }

        let horizontalNormal = SIMD3(hit.normal.x, 0, hit.normal.z)
        guard simd_length_squared(horizontalNormal) > 0.0001 else {
            return .rejected(.selectVerticalSide)
        }

        let normal = simd_normalize(horizontalNormal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0 ? normal : -normal
        let unprojectedStart = hit.point + towardCamera * objectClearance
        let unprojectedDestination = hit.point - towardCamera * objectClearance
        guard floorRegion.containsPlacementXZ(unprojectedStart),
              floorRegion.containsPlacementXZ(unprojectedDestination),
              let start = floorRegion.pointOnFloor(projecting: unprojectedStart),
              let destination = floorRegion.pointOnFloor(projecting: unprojectedDestination) else {
            return .rejected(.findFloor)
        }
        return .accepted(RealityHidePlan(
            start: start,
            destination: destination,
            retreatDirection: -towardCamera,
            floorRegion: floorRegion
        ))
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

private extension simd_float4x4 {
    var allFinite: Bool {
        columns.0.x.isFinite && columns.0.y.isFinite && columns.0.z.isFinite && columns.0.w.isFinite
            && columns.1.x.isFinite && columns.1.y.isFinite && columns.1.z.isFinite && columns.1.w.isFinite
            && columns.2.x.isFinite && columns.2.y.isFinite && columns.2.z.isFinite && columns.2.w.isFinite
            && columns.3.x.isFinite && columns.3.y.isFinite && columns.3.z.isFinite && columns.3.w.isFinite
    }
}
