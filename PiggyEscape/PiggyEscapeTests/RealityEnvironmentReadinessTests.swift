import XCTest
@testable import PiggyEscape

final class RealityEnvironmentReadinessTests: XCTestCase {
    func test_meshAloneDoesNotMakeTheEnvironmentReady() {
        var readiness = RealityEnvironmentReadiness()

        XCTAssertFalse(readiness.observeMesh())
        XCTAssertFalse(readiness.isReady)
    }

    func test_classifiedFloorAloneDoesNotMakeTheEnvironmentReady() {
        var readiness = RealityEnvironmentReadiness()

        XCTAssertFalse(readiness.observeClassifiedFloor())
        XCTAssertFalse(readiness.isReady)
    }

    func test_eitherObservationOrderReportsTheFirstCompleteEnvironmentOnce() {
        var meshThenFloor = RealityEnvironmentReadiness()
        XCTAssertFalse(meshThenFloor.observeMesh())
        XCTAssertTrue(meshThenFloor.observeClassifiedFloor())
        XCTAssertFalse(meshThenFloor.observeMesh())
        XCTAssertFalse(meshThenFloor.observeClassifiedFloor())
        XCTAssertTrue(meshThenFloor.isReady)

        var floorThenMesh = RealityEnvironmentReadiness()
        XCTAssertFalse(floorThenMesh.observeClassifiedFloor())
        XCTAssertTrue(floorThenMesh.observeMesh())
        XCTAssertFalse(floorThenMesh.observeMesh())
        XCTAssertTrue(floorThenMesh.isReady)
    }
}
