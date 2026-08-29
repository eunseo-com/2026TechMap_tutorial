import XCTest
@testable import PiggyEscape

final class PigScalePolicyTests: XCTestCase {
    func test_validVisualBoundsScaleToEighteenCentimeters() throws {
        XCTAssertEqual(PigScalePolicy.targetHeight, 0.18, accuracy: 0.0001)

        let scale = try PigScalePolicy.uniformScale(
            visualBoundsMin: SIMD3(-0.1, 0, -0.15),
            visualBoundsMax: SIMD3(0.1, 0.45, 0.15)
        )

        XCTAssertEqual(scale, 0.4, accuracy: 0.0001)
    }

    func test_zeroNegativeNaNAndInfiniteVisualBoundsAreRejected() {
        let invalidBounds: [(SIMD3<Float>, SIMD3<Float>)] = [
            (.zero, SIMD3(0.2, 0, 0.2)),
            (.zero, SIMD3(0.2, -0.1, 0.2)),
            (.zero, SIMD3(0.2, .nan, 0.2)),
            (.zero, SIMD3(0.2, .infinity, 0.2)),
            (SIMD3(0, .nan, 0), SIMD3(0.2, 0.2, 0.2)),
            (SIMD3(0.3, 0, 0), SIMD3(0.2, 0.2, 0.2))
        ]

        for (minimum, maximum) in invalidBounds {
            XCTAssertThrowsError(
                try PigScalePolicy.uniformScale(
                    visualBoundsMin: minimum,
                    visualBoundsMax: maximum
                )
            ) { error in
                XCTAssertEqual(error as? PigScalePolicyError, .invalidVisualBounds)
            }
        }
    }

    func test_nearZeroHeightThatWouldProduceInfiniteScaleIsRejected() {
        XCTAssertThrowsError(
            try PigScalePolicy.uniformScale(
                visualBoundsMin: .zero,
                visualBoundsMax: SIMD3(0.2, Float.leastNonzeroMagnitude, 0.2)
            )
        ) { error in
            XCTAssertEqual(error as? PigScalePolicyError, .invalidVisualBounds)
        }
    }
}
