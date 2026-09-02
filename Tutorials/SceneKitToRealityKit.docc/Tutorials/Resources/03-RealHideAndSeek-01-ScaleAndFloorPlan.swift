// Production: PiggyEscape/PiggyEscape/Sources/Reality/PigScalePolicy.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/PigScalePolicyTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift

import Foundation
import simd

enum PigScaleError: Error {
    case invalidVisualBounds
}

enum PigScalePolicy {
    static let targetHeight: Float = 0.18
    static let targetHeightTolerance: Float = 0.001

    static func uniformScale(
        correctedVisualMinimum minimum: SIMD3<Float>,
        correctedVisualMaximum maximum: SIMD3<Float>
    ) throws -> Float {
        guard minimum.allFinite,
              maximum.allFinite,
              maximum.x >= minimum.x,
              maximum.y > minimum.y,
              maximum.z >= minimum.z else {
            throw PigScaleError.invalidVisualBounds
        }
        let height = maximum.y - minimum.y
        let scale = targetHeight / height
        guard height.isFinite, height > 0, scale.isFinite, scale > 0 else {
            throw PigScaleError.invalidVisualBounds
        }
        try validateNormalizedBounds(
            minimum: minimum * scale,
            maximum: maximum * scale
        )
        return scale
    }

    static func validateNormalizedBounds(
        minimum: SIMD3<Float>,
        maximum: SIMD3<Float>
    ) throws {
        guard minimum.allFinite,
              maximum.allFinite,
              maximum.x >= minimum.x,
              maximum.y > minimum.y,
              maximum.z >= minimum.z else {
            throw PigScaleError.invalidVisualBounds
        }
        let height = maximum.y - minimum.y
        guard height.isFinite,
              abs(height - targetHeight) <= targetHeightTolerance else {
            throw PigScaleError.invalidVisualBounds
        }
    }
}

struct SurfaceHit {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct ImmutableFloorRegion {
    static let surfaceTolerance: Float = 0.02
    static let placementInset: Float = 0.10

    let anchorIdentifier: UUID
    let transform: simd_float4x4
    let center: SIMD3<Float>
    let extent: SIMD2<Float>
    let rotationOnYAxis: Float

    func containsSurface(_ worldPoint: SIMD3<Float>) -> Bool {
        contains(worldPoint, edgeAdjustment: Self.surfaceTolerance)
    }

    func containsPlacement(_ worldPoint: SIMD3<Float>) -> Bool {
        contains(worldPoint, edgeAdjustment: -Self.placementInset)
    }

    func pointOnFloor(projecting worldPoint: SIMD3<Float>) -> SIMD3<Float>? {
        guard let local = localPoint(for: worldPoint) else { return nil }
        let transformed = transform * SIMD4<Float>(local.x, center.y, local.z, 1)
        let result = SIMD3<Float>(transformed.x, transformed.y, transformed.z)
        return result.allFinite ? result : nil
    }

    private func contains(_ worldPoint: SIMD3<Float>, edgeAdjustment: Float) -> Bool {
        guard let local = localPoint(for: worldPoint),
              extent.x.isFinite,
              extent.y.isFinite,
              rotationOnYAxis.isFinite else {
            return false
        }
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
        let transformed = simd_inverse(transform) * SIMD4<Float>(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let result = SIMD3<Float>(transformed.x, transformed.y, transformed.z)
        return result.allFinite ? result : nil
    }
}

enum HidePlanRejection {
    case selectVerticalSide
    case moveFartherAway
    case findFloor
}

struct HidePlan {
    let start: SIMD3<Float>
    let destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let floorRegion: ImmutableFloorRegion
}

enum HidePlanResult {
    case accepted(HidePlan)
    case rejected(HidePlanRejection)
}

enum HidePlanner {
    static let verticalNormalMaximumY: Float = 0.35
    static let minimumCameraDistance: Float = 0.90
    static let objectClearance: Float = 0.28

    static func plan(
        hit: SurfaceHit,
        cameraPosition: SIMD3<Float>,
        floorRegion: ImmutableFloorRegion?
    ) -> HidePlanResult {
        guard hit.point.allFinite,
              hit.normal.allFinite,
              cameraPosition.allFinite,
              abs(hit.normal.y) <= verticalNormalMaximumY else {
            return .rejected(.selectVerticalSide)
        }
        let distance = simd_distance(hit.point, cameraPosition)
        guard distance.isFinite, distance >= minimumCameraDistance else {
            return .rejected(.moveFartherAway)
        }
        guard let floorRegion, floorRegion.containsSurface(hit.point) else {
            return .rejected(.findFloor)
        }

        let horizontalNormal = SIMD3<Float>(hit.normal.x, 0, hit.normal.z)
        guard simd_length_squared(horizontalNormal) > 0.0001 else {
            return .rejected(.selectVerticalSide)
        }
        let normal = simd_normalize(horizontalNormal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0 ? normal : -normal
        let unprojectedStart = hit.point + towardCamera * objectClearance
        let unprojectedDestination = hit.point - towardCamera * objectClearance

        guard floorRegion.containsPlacement(unprojectedStart),
              floorRegion.containsPlacement(unprojectedDestination),
              let start = floorRegion.pointOnFloor(projecting: unprojectedStart),
              let destination = floorRegion.pointOnFloor(projecting: unprojectedDestination) else {
            return .rejected(.findFloor)
        }
        return .accepted(HidePlan(
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
