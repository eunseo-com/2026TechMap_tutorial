import UIKit
import XCTest
import simd
@testable import PiggyEscape

@MainActor
final class RealityOcclusionObservationProviderTests: XCTestCase {
    func test_rotatedLocalBoundsBecomeEightWorldCornersAndFiveSameFrameProjections() {
        let provider = RealityOcclusionObservationProvider()
        var pigTransform = simd_float4x4(simd_quatf(
            angle: .pi / 2,
            axis: SIMD3<Float>(0, 1, 0)
        ))
        pigTransform.columns.3 = SIMD4<Float>(3, 2, -4, 1)

        let corners = RealityOcclusionObservationProvider.worldBoundsCorners(
            localMinimum: SIMD3<Float>(-1, -0.5, -0.25),
            localMaximum: SIMD3<Float>(1, 0.5, 0.25),
            worldTransform: pigTransform
        )

        XCTAssertEqual(corners?.count, 8)
        for x in [Float(2.75), 3.25] {
            for y in [Float(1.5), 2.5] {
                for z in [Float(-5), -3] {
                    XCTAssertTrue(corners?.contains(where: {
                        simd_distance($0, SIMD3<Float>(x, y, z)) < 0.000_01
                    }) == true)
                }
            }
        }

        var frameCaptureCount = 0
        var projectedWorldPoints: [SIMD3<Float>] = []
        var projectedOrientations: [UIInterfaceOrientation] = []
        let observation = provider.makeObservation(
            captureFrame: {
                frameCaptureCount += 1
                return frame(
                    timestamp: 42,
                    cameraTransform: matrix_identity_float4x4,
                    orientation: .landscapeRight
                )
            },
            localBoundsMinimum: SIMD3<Float>(-1, -0.5, -0.25),
            localBoundsMaximum: SIMD3<Float>(1, 0.5, 0.25),
            pigWorldTransform: pigTransform,
            project: { worldPoint, orientation in
                projectedWorldPoints.append(worldPoint)
                projectedOrientations.append(orientation)
                return CGPoint(
                    x: CGFloat(100 + worldPoint.x),
                    y: CGFloat(200 - worldPoint.y)
                )
            },
            sceneUnderstandingHit: { _ in nil }
        )

        XCTAssertEqual(frameCaptureCount, 1)
        XCTAssertEqual(projectedWorldPoints.count, 5)
        XCTAssertEqual(Set(projectedWorldPoints).count, 5)
        XCTAssertEqual(projectedOrientations, Array(repeating: .landscapeRight, count: 5))
        XCTAssertEqual(observation?.frameTimestamp, 42)
        XCTAssertEqual(observation?.cameraPose?.position, .zero)
        XCTAssertEqual(observation?.cameraPose?.forward, SIMD3<Float>(0, 0, -1))
        XCTAssertEqual(observation?.samples.values.filter { $0 == .visible }.count, 5)
    }

    func test_eachProjectionOrDistanceFailureInvalidatesOnlyItsSample() {
        let provider = RealityOcclusionObservationProvider()
        var pigTransform = matrix_identity_float4x4
        pigTransform.columns.3 = SIMD4<Float>(0, 0, -2, 1)

        let observation = provider.makeObservation(
            captureFrame: { frame(timestamp: 7) },
            localBoundsMinimum: SIMD3<Float>(-1, -0.5, -0.25),
            localBoundsMaximum: SIMD3<Float>(1, 0.5, 0.25),
            pigWorldTransform: pigTransform,
            project: { worldPoint, _ in
                if worldPoint.y > 0.3 {
                    return nil
                }
                if worldPoint.y < -0.3 {
                    return CGPoint(x: 500, y: 200)
                }
                return CGPoint(
                    x: CGFloat(100 + worldPoint.x * 100),
                    y: 200
                )
            },
            sceneUnderstandingHit: { screenPoint in
                if screenPoint.x < 50 {
                    return SIMD3<Float>(.nan, 0, -1)
                }
                return SIMD3<Float>(0, 0, -3)
            }
        )

        XCTAssertEqual(observation?.samples[.top], .invalid, "failed projection")
        XCTAssertEqual(observation?.samples[.bottom], .invalid, "offscreen projection")
        XCTAssertEqual(observation?.samples[.left], .invalid, "non-finite hit distance")
        XCTAssertEqual(observation?.samples[.center], .visible, "a hit behind the sample remains visible")
        XCTAssertEqual(observation?.samples[.right], .visible)
    }

    func test_missingOrientationInvalidatesTheAggregateWithoutProjecting() {
        let provider = RealityOcclusionObservationProvider()
        var pigTransform = matrix_identity_float4x4
        pigTransform.columns.3 = SIMD4<Float>(0, 0, -2, 1)
        var projectionCount = 0

        let observation = provider.makeObservation(
            captureFrame: { frame(timestamp: 8, orientation: .unknown) },
            localBoundsMinimum: SIMD3<Float>(-1, -0.5, -0.25),
            localBoundsMaximum: SIMD3<Float>(1, 0.5, 0.25),
            pigWorldTransform: pigTransform,
            project: { _, _ in
                projectionCount += 1
                return CGPoint(x: 100, y: 200)
            },
            sceneUnderstandingHit: { _ in nil }
        )

        XCTAssertEqual(projectionCount, 0)
        XCTAssertEqual(observation?.samples, invalidSamples())
    }

    func test_nonFiniteCameraOrBoundsCannotProduceAValidAggregate() {
        let provider = RealityOcclusionObservationProvider()
        var pigTransform = matrix_identity_float4x4
        pigTransform.columns.3 = SIMD4<Float>(0, 0, -2, 1)
        var invalidCamera = matrix_identity_float4x4
        invalidCamera.columns.3.x = .nan

        let invalidCameraObservation = provider.makeObservation(
            captureFrame: { frame(timestamp: 9, cameraTransform: invalidCamera) },
            localBoundsMinimum: SIMD3<Float>(-1, -0.5, -0.25),
            localBoundsMaximum: SIMD3<Float>(1, 0.5, 0.25),
            pigWorldTransform: pigTransform,
            project: { _, _ in CGPoint(x: 100, y: 200) },
            sceneUnderstandingHit: { _ in nil }
        )

        XCTAssertNil(invalidCameraObservation?.cameraPose)
        XCTAssertEqual(invalidCameraObservation?.samples, invalidSamples())
        XCTAssertNil(RealityOcclusionObservationProvider.worldBoundsCorners(
            localMinimum: SIMD3<Float>(-.infinity, -1, -1),
            localMaximum: SIMD3<Float>(1, 1, 1),
            worldTransform: pigTransform
        ))
    }
}

private func frame(
    timestamp: TimeInterval,
    cameraTransform: simd_float4x4 = matrix_identity_float4x4,
    orientation: UIInterfaceOrientation = .portrait
) -> RealityOcclusionFrameSnapshot {
    RealityOcclusionFrameSnapshot(
        timestamp: timestamp,
        cameraTransform: cameraTransform,
        viewportBounds: CGRect(x: 0, y: 0, width: 200, height: 400),
        interfaceOrientation: orientation
    )
}

private func invalidSamples() -> [PigOcclusionSampleID: OcclusionSampleState] {
    Dictionary(uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { ($0, .invalid) })
}
