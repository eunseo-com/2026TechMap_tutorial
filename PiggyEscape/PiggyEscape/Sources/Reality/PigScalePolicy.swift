import simd

enum PigScalePolicyError: Error, Equatable {
    case invalidVisualBounds
}

enum PigScalePolicy {
    static let targetHeight: Float = 0.18
    private static let targetHeightTolerance: Float = 0.001

    static func uniformScale(
        visualBoundsMin minimum: SIMD3<Float>,
        visualBoundsMax maximum: SIMD3<Float>
    ) throws -> Float {
        guard minimum.allFinite,
              maximum.allFinite,
              maximum.x >= minimum.x,
              maximum.z >= minimum.z else {
            throw PigScalePolicyError.invalidVisualBounds
        }

        let height = maximum.y - minimum.y
        guard height.isFinite, height > 0 else {
            throw PigScalePolicyError.invalidVisualBounds
        }
        let scale = targetHeight / height
        guard scale.isFinite, scale > 0 else {
            throw PigScalePolicyError.invalidVisualBounds
        }
        try validateNormalizedBounds(
            visualBoundsMin: minimum * scale,
            visualBoundsMax: maximum * scale
        )
        return scale
    }

    static func validateNormalizedBounds(
        visualBoundsMin minimum: SIMD3<Float>,
        visualBoundsMax maximum: SIMD3<Float>
    ) throws {
        guard minimum.allFinite,
              maximum.allFinite,
              maximum.x >= minimum.x,
              maximum.y > minimum.y,
              maximum.z >= minimum.z else {
            throw PigScalePolicyError.invalidVisualBounds
        }

        let height = maximum.y - minimum.y
        guard height.isFinite,
              abs(height - targetHeight) <= targetHeightTolerance else {
            throw PigScalePolicyError.invalidVisualBounds
        }
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
