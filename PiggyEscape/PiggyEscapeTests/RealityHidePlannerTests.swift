import XCTest
import simd
@testable import PiggyEscape

final class RealityHidePlannerTests: XCTestCase {
    func test_verticalSurfacePlacesPigOnCameraOppositeSideOfObject() {
        let result = RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: SIMD3(1, 0.9, 0), normal: SIMD3(1, 0, 0)),
            cameraPosition: SIMD3(3, 1.5, 0),
            floor: RealityFloor(point: SIMD3(1, 0.25, 0))
        )

        guard case let .accepted(position) = result else {
            return XCTFail("expected accepted target")
        }
        XCTAssertLessThan(position.x, 1)
        XCTAssertEqual(position.x, 0.72, accuracy: 0.0001)
        XCTAssertEqual(position.y, 0.25, accuracy: 0.0001)
    }

    func test_horizontalSurfaceAndMissingFloorAreRejected() {
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 1, 0)),
                cameraPosition: SIMD3(0, 1.5, 1),
                floor: RealityFloor(point: SIMD3(0, 0, 0))
            ),
            .rejected(.selectVerticalSide)
        )
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(1, 0.8, 0), normal: SIMD3(1, 0, 0)),
                cameraPosition: SIMD3(3, 1.5, 0),
                floor: nil
            ),
            .rejected(.findFloor)
        )
    }

    func test_nearCameraAndFarFloorAreRejected() {
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 0, 1)),
                cameraPosition: SIMD3(0, 0.8, 0.44),
                floor: RealityFloor(point: SIMD3(0, 0, 0))
            ),
            .rejected(.moveFartherAway)
        )
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 0, 1)),
                cameraPosition: SIMD3(0, 1.5, 2),
                floor: RealityFloor(point: SIMD3(2, 0, 0))
            ),
            .rejected(.findFloor)
        )
    }

    func test_zeroLengthNormalIsRejectedWithoutNormalizingIt() {
        XCTAssertEqual(
            RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(repeating: 0)),
                cameraPosition: SIMD3(0, 1.5, 2),
                floor: RealityFloor(point: SIMD3(0, 0, 0))
            ),
            .rejected(.selectVerticalSide)
        )
    }

    func test_revealMonitorFiresOnlyAfterFirstBlockedFrameThenVisibleFrame() {
        var monitor = RealityRevealMonitor()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
    }

    func test_revealMonitorTreatsThreeCentimeterBoundaryAsVisible() {
        var monitor = RealityRevealMonitor()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(monitor.update(meshDistance: 1.97, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(monitor.update(meshDistance: 1.97, pigDistance: 2, cameraPose: movedPose))
    }

    func test_floorFootprintUsesTransformedExtentInsteadOfItsDistantCenter() {
        var transform = matrix_identity_float4x4
        transform.columns.0 = SIMD4(0, 0, -1, 0)
        transform.columns.2 = SIMD4(1, 0, 0, 0)
        transform.columns.3 = SIMD4(10, 0.3, -4, 1)
        let plane = RealityFloorPlane(
            transform: transform,
            center: SIMD3(1, 0, 2),
            extent: SIMD2(8, 6)
        )
        let selectedObjectPoint = SIMD3<Float>(11, 2, -7.5)

        guard let floor = plane.floor(containing: selectedObjectPoint) else {
            return XCTFail("expected the selected point inside the rotated floor footprint")
        }
        XCTAssertEqual(floor.point.x, 11, accuracy: 0.0001)
        XCTAssertEqual(floor.point.y, 0.3, accuracy: 0.0001)
        XCTAssertEqual(floor.point.z, -7.5, accuracy: 0.0001)

        let result = RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: selectedObjectPoint, normal: SIMD3(0, 0, 1)),
            cameraPosition: SIMD3(11, 2, -6.5),
            floor: floor
        )
        guard case .accepted = result else {
            return XCTFail("expected the floor directly under the selected object to be accepted")
        }
    }

    func test_floorFootprintRejectsPointOutsideNearbyAnchorCenter() {
        let plane = RealityFloorPlane(
            transform: matrix_identity_float4x4,
            center: .zero,
            extent: SIMD2(1, 1)
        )

        XCTAssertNil(plane.floor(containing: SIMD3(0.75, 1, 0)))
    }

    func test_floorFootprintAllowsOnlyItsTwoCentimeterBoundaryTolerance() {
        let plane = RealityFloorPlane(
            transform: matrix_identity_float4x4,
            center: .zero,
            extent: SIMD2(1, 1)
        )

        XCTAssertNotNil(plane.floor(containing: SIMD3(0.52, 1, 0)))
        XCTAssertNil(plane.floor(containing: SIMD3(0.521, 1, 0)))
    }

    func test_floorFootprintAppliesThePlaneExtentRotation() {
        let plane = RealityFloorPlane(
            transform: matrix_identity_float4x4,
            center: .zero,
            extent: SIMD2(4, 2),
            rotationOnYAxis: .pi / 2
        )

        XCTAssertNotNil(plane.floor(containing: SIMD3(0, 0, -1.9)))
        XCTAssertNil(plane.floor(containing: SIMD3(1.1, 0, 0)))
    }

    func test_revealMonitorDoesNotRevealForZeroMovementNullHits() {
        var monitor = RealityRevealMonitor()
        let pose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: pose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: pose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: pose))
    }

    func test_revealMonitorRejectsSubthresholdTranslationAndRotation() {
        var translationMonitor = RealityRevealMonitor()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let shortMove = RealityCameraPose(position: SIMD3(0.149, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(translationMonitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(translationMonitor.update(meshDistance: nil, pigDistance: 2, cameraPose: shortMove))
        XCTAssertFalse(translationMonitor.update(meshDistance: nil, pigDistance: 2, cameraPose: shortMove))

        var rotationMonitor = RealityRevealMonitor()
        let shortTurn = RealityCameraPose(position: .zero, forward: SIMD3(0.2, 0, -0.9797959))
        XCTAssertFalse(rotationMonitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(rotationMonitor.update(meshDistance: nil, pigDistance: 2, cameraPose: shortTurn))
        XCTAssertFalse(rotationMonitor.update(meshDistance: nil, pigDistance: 2, cameraPose: shortTurn))
    }

    func test_revealMonitorRequiresTwoStableVisibleFramesAfterExactMovementThreshold() {
        var monitor = RealityRevealMonitor()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let exactMove = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: exactMove))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: exactMove))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: exactMove))
    }

    func test_revealMonitorAcceptsExactRotationThresholdAfterStableFrames() {
        var monitor = RealityRevealMonitor()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let angle: Float = .pi / 12
        let exactTurn = RealityCameraPose(
            position: .zero,
            forward: SIMD3(sin(angle), 0, -cos(angle))
        )

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: exactTurn))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: exactTurn))
    }

    func test_revealMonitorResetsVisibleStabilityWhenBlockingReturns() {
        var monitor = RealityRevealMonitor()
        let firstBlockingPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let firstMove = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))
        let secondMove = RealityCameraPose(position: SIMD3(0.3, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: firstBlockingPose))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: firstMove))
        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: firstMove))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: secondMove))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: secondMove))
    }

    func test_revealMonitorLatchesTheFirstBlockingPoseForItsHideCycle() {
        var monitor = RealityRevealMonitor()
        let firstBlockingPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let stillBlockedAfterMoving = RealityCameraPose(
            position: SIMD3(0.15, 0, 0),
            forward: SIMD3(0, 0, -1)
        )

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: firstBlockingPose))
        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2, cameraPose: stillBlockedAfterMoving))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: stillBlockedAfterMoving))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2, cameraPose: stillBlockedAfterMoving))
    }
}
