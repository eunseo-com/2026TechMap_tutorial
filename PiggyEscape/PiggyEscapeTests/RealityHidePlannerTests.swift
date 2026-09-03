import XCTest
import simd
@testable import PiggyEscape

final class RealityHidePlannerTests: XCTestCase {
    func test_exactNinetyCentimeterSurfaceIsAcceptedAndCloserSurfaceIsRejected() {
        let region = makeFloorRegion(extent: SIMD2(4, 4))

        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 0, 1)),
                cameraPosition: SIMD3(0, 0.8, 0.899),
                floorRegion: region
            ),
            .rejected(.moveFartherAway)
        )

        let result = RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 0, 1)),
            cameraPosition: SIMD3(0, 0.8, 0.9),
            floorRegion: region
        )

        guard case let .accepted(plan) = result else {
            return XCTFail("expected exact boundary acceptance")
        }
        XCTAssertEqual(plan.start, SIMD3(0, 0, 0.28))
        XCTAssertEqual(plan.destination, SIMD3(0, 0, -0.28))
        XCTAssertEqual(plan.retreatDirection, SIMD3(0, 0, -1))
        XCTAssertEqual(plan.floorRegion, region)
    }

    func test_horizontalSurfaceAndMissingFloorAreRejected() {
        let region = makeFloorRegion(extent: SIMD2(4, 4))
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 1, 0)),
                cameraPosition: SIMD3(0, 1.5, 1),
                floorRegion: region
            ),
            .rejected(.selectVerticalSide)
        )
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(1, 0.8, 0), normal: SIMD3(1, 0, 0)),
                cameraPosition: SIMD3(3, 1.5, 0),
                floorRegion: nil
            ),
            .rejected(.findFloor)
        )
    }

    func test_zeroLengthNormalIsRejectedWithoutNormalizingIt() {
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(repeating: 0)),
                cameraPosition: SIMD3(0, 1.5, 2),
                floorRegion: makeFloorRegion(extent: SIMD2(4, 4))
            ),
            .rejected(.selectVerticalSide)
        )
    }

    func test_rotatedFloorRegionProjectsStartAndDestinationUsingTheSnapshotTransform() {
        var transform = matrix_identity_float4x4
        transform.columns.0 = SIMD4(0, 0, -1, 0)
        transform.columns.2 = SIMD4(1, 0, 0, 0)
        transform.columns.3 = SIMD4(10, 0.3, -4, 1)
        let region = RealityFloorRegion(
            anchorIdentifier: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            transform: transform,
            center: SIMD3(1, 0, 2),
            extent: SIMD2(8, 6),
            rotationOnYAxis: .pi / 2
        )
        let selectedObjectPoint = SIMD3<Float>(11, 2, -7.5)

        let result = RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: selectedObjectPoint, normal: SIMD3(0, 0, 1)),
            cameraPosition: SIMD3(11, 2, -6.5),
            floorRegion: region
        )
        guard case let .accepted(plan) = result else {
            return XCTFail("expected rotated floor plan")
        }
        XCTAssertEqual(plan.start, SIMD3(11, 0.3, -7.22))
        XCTAssertEqual(plan.destination, SIMD3(11, 0.3, -7.78))
        XCTAssertEqual(plan.floorRegion.anchorIdentifier, region.anchorIdentifier)
    }

    func test_surfaceToleranceIsTwoCentimetersButPlacementsRequireTenCentimeterInset() {
        let region = makeFloorRegion(extent: SIMD2(1, 1))

        XCTAssertTrue(region.containsSurfaceXZ(SIMD3(0.52, 1, 0)))
        XCTAssertFalse(region.containsSurfaceXZ(SIMD3(0.521, 1, 0)))
        XCTAssertTrue(region.containsPlacementXZ(SIMD3(0.4, 0, 0)))
        XCTAssertFalse(region.containsPlacementXZ(SIMD3(0.401, 0, 0)))
    }

    func test_initialPlanRejectsWhenEitherStartOrDestinationLeavesTheSafeInset() {
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, -0.15), normal: SIMD3(0, 0, 1)),
                cameraPosition: SIMD3(0, 0.8, 0.9),
                floorRegion: makeFloorRegion(extent: SIMD2(1, 1))
            ),
            .rejected(.findFloor)
        )
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0.15), normal: SIMD3(0, 0, 1)),
                cameraPosition: SIMD3(0, 0.8, 1.1),
                floorRegion: makeFloorRegion(extent: SIMD2(1, 1))
            ),
            .rejected(.findFloor)
        )
    }

    func test_verifiedMeshOcclusionCompletesTheHideAttempt() {
        let attempt = RealityHideAttempt(
            destination: SIMD3<Float>(0, 0, -1),
            retreatDirection: SIMD3<Float>(0, 0, -1),
            floorRegion: makeFloorRegion(extent: SIMD2(4, 4)),
            retryCount: 0
        )

        XCTAssertEqual(
            RealityHideVerificationPolicy.decide(
                meshDistance: 0.7,
                pigDistance: 1.0,
                attempt: attempt
            ),
            .hidden
        )
    }

    func test_unoccludedPigRetriesOnlyTowardTheObjectBackSide() {
        let attempt = RealityHideAttempt(
            destination: SIMD3<Float>(0, 0, -0.22),
            retreatDirection: SIMD3<Float>(0, 0, -1),
            floorRegion: makeFloorRegion(extent: SIMD2(1, 1)),
            retryCount: 0
        )

        guard case let .retry(nextAttempt) = RealityHideVerificationPolicy.decide(
            meshDistance: nil,
            pigDistance: 1.0,
            attempt: attempt
        ) else {
            return XCTFail("expected one deeper hide attempt")
        }
        XCTAssertEqual(nextAttempt.destination.x, 0, accuracy: 0.0001)
        XCTAssertEqual(nextAttempt.destination.y, 0, accuracy: 0.0001)
        XCTAssertEqual(nextAttempt.destination.z, -0.4, accuracy: 0.0001)
        XCTAssertEqual(nextAttempt.retreatDirection, SIMD3<Float>(0, 0, -1))
        XCTAssertEqual(nextAttempt.floorRegion, attempt.floorRegion)
        XCTAssertEqual(nextAttempt.retryCount, 1)
    }

    func test_retryOutsideThePreservedInsetSelectsAnotherTargetWithoutMoving() {
        let attempt = RealityHideAttempt(
            destination: SIMD3<Float>(0, 0, -0.4),
            retreatDirection: SIMD3<Float>(0, 0, -1),
            floorRegion: makeFloorRegion(extent: SIMD2(1, 1)),
            retryCount: 1
        )

        XCTAssertEqual(
            RealityHideVerificationPolicy.decide(
                meshDistance: nil,
                pigDistance: 1,
                attempt: attempt
            ),
            .selectAnotherTarget
        )
    }

    func test_unoccludedPigRequiresNewTargetAfterTheBoundedRetries() {
        let finalAttempt = RealityHideAttempt(
            destination: SIMD3<Float>(0, 0, -1.36),
            retreatDirection: SIMD3<Float>(0, 0, -1),
            floorRegion: makeFloorRegion(extent: SIMD2(4, 4)),
            retryCount: 2
        )

        XCTAssertEqual(
            RealityHideVerificationPolicy.decide(
                meshDistance: nil,
                pigDistance: 1.4,
                attempt: finalAttempt
            ),
            .selectAnotherTarget
        )
    }
}

private func makeFloorRegion(
    extent: SIMD2<Float>,
    transform: simd_float4x4 = matrix_identity_float4x4,
    center: SIMD3<Float> = .zero,
    rotationOnYAxis: Float = 0
) -> RealityFloorRegion {
    RealityFloorRegion(
        anchorIdentifier: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        transform: transform,
        center: center,
        extent: extent,
        rotationOnYAxis: rotationOnYAxis
    )
}
