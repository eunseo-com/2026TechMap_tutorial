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

        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2))
        XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2))
    }

    func test_revealMonitorTreatsThreeCentimeterBoundaryAsVisible() {
        var monitor = RealityRevealMonitor()

        XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2))
        XCTAssertTrue(monitor.update(meshDistance: 1.97, pigDistance: 2))
    }
}
