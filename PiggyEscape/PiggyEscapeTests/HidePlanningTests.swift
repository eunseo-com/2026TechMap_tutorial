import XCTest
import simd
@testable import PiggyEscape

final class HidePlanningTests: XCTestCase {
    func test_treeDestinationIsOnTheCameraOppositeSideAndOnTheFloor() {
        let target = TreeHidePlanner.destination(
            treeCenter: SIMD3(0, 0, 0), treeRadius: 0.5,
            cameraPosition: SIMD3(0, 2, 4), pigRadius: 0.25, floorY: 0
        )
        XCTAssertLessThan(target.z, 0)
        XCTAssertEqual(target.y, 0, accuracy: 0.0001)
    }
}
