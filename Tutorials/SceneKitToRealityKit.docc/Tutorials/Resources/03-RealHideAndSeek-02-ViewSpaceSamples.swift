// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionObservationProvider.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionPolicy.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityOcclusionObservationProviderTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityOcclusionPolicyTests.swift

import simd

enum PigSampleID: CaseIterable, Hashable {
    case center
    case top
    case bottom
    case left
    case right
}

enum ViewSpacePigSampler {
    static let supportInset: Float = 0.80

    static func worldCorners(
        correctedLocalMinimum minimum: SIMD3<Float>,
        correctedLocalMaximum maximum: SIMD3<Float>,
        worldTransform: simd_float4x4
    ) -> [SIMD3<Float>]? {
        guard minimum.allFinite,
              maximum.allFinite,
              worldTransform.allFinite,
              minimum.x < maximum.x,
              minimum.y < maximum.y,
              minimum.z < maximum.z else {
            return nil
        }

        var corners: [SIMD3<Float>] = []
        for x in [minimum.x, maximum.x] {
            for y in [minimum.y, maximum.y] {
                for z in [minimum.z, maximum.z] {
                    let transformed = worldTransform * SIMD4<Float>(x, y, z, 1)
                    guard transformed.x.isFinite,
                          transformed.y.isFinite,
                          transformed.z.isFinite,
                          transformed.w.isFinite,
                          abs(transformed.w) > 0.000_001 else {
                        return nil
                    }
                    corners.append(SIMD3<Float>(transformed.x, transformed.y, transformed.z) / transformed.w)
                }
            }
        }
        return corners
    }

    static func samples(
        eightWorldCorners corners: [SIMD3<Float>],
        currentCameraRight cameraRight: SIMD3<Float>,
        currentCameraUp cameraUp: SIMD3<Float>
    ) -> [PigSampleID: SIMD3<Float>]? {
        guard corners.count == 8,
              corners.allSatisfy(\.allFinite),
              Set(corners).count == 8,
              hasThreeDimensionalSpan(corners),
              let right = normalized(cameraRight),
              let up = normalized(cameraUp),
              simd_length_squared(simd_cross(right, up)) > 0.000_001 else {
            return nil
        }

        var minimum = corners[0]
        var maximum = corners[0]
        for corner in corners.dropFirst() {
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
        guard let top = support(in: corners, direction: up, maximum: true),
              let bottom = support(in: corners, direction: up, maximum: false),
              let rightPoint = support(in: corners, direction: right, maximum: true),
              let leftPoint = support(in: corners, direction: right, maximum: false) else {
            return nil
        }

        let result: [PigSampleID: SIMD3<Float>] = [
            .center: center,
            .top: center + (top - center) * supportInset,
            .bottom: center + (bottom - center) * supportInset,
            .left: center + (leftPoint - center) * supportInset,
            .right: center + (rightPoint - center) * supportInset,
        ]
        return result.values.allSatisfy(\.allFinite) ? result : nil
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float>? {
        guard vector.allFinite else { return nil }
        let lengthSquared = simd_length_squared(vector)
        guard lengthSquared.isFinite, lengthSquared > 0.000_001 else { return nil }
        return vector / sqrt(lengthSquared)
    }

    private static func support(
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
        let points = zip(corners, projections).compactMap { corner, projection in
            abs(projection - target) <= tolerance ? corner : nil
        }
        guard !points.isEmpty else { return nil }
        return points.reduce(SIMD3<Float>.zero, +) / Float(points.count)
    }

    private static func hasThreeDimensionalSpan(_ corners: [SIMD3<Float>]) -> Bool {
        let origin = SIMD3<Double>(corners[0])
        let offsets = corners.dropFirst().map { SIMD3<Double>($0) - origin }
        for firstIndex in offsets.indices {
            for secondIndex in offsets.indices where secondIndex > firstIndex {
                for thirdIndex in offsets.indices where thirdIndex > secondIndex {
                    let first = offsets[firstIndex]
                    let second = offsets[secondIndex]
                    let third = offsets[thirdIndex]
                    let lengths = [simd_length(first), simd_length(second), simd_length(third)]
                    guard lengths.allSatisfy({ $0.isFinite && $0 > 0 }) else { continue }
                    let normalizedVolume = abs(simd_dot(
                        first / lengths[0],
                        simd_cross(second / lengths[1], third / lengths[2])
                    ))
                    if normalizedVolume.isFinite, normalizedVolume > 0.000_001 {
                        return true
                    }
                }
            }
        }
        return false
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
