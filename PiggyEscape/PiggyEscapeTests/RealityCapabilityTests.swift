import XCTest
@testable import PiggyEscape

final class RealityCapabilityTests: XCTestCase {
    func test_injectedCapabilityDoesNotDependOnTheSimulator() {
        XCTAssertTrue(FakeRealityMeshSupport(supportsMeshWithClassification: true).supportsMeshWithClassification)
        XCTAssertFalse(FakeRealityMeshSupport(supportsMeshWithClassification: false).supportsMeshWithClassification)
    }

    func test_availabilityMessagesMatchTheRealityGuidance() {
        XCTAssertEqual(RealityAvailabilityMessage.unavailable, "이 기능은 LiDAR로 공간을 읽을 수 있는 기기에서 사용할 수 있어.")
        XCTAssertEqual(RealityAvailabilityMessage.scanFirst, "주변 바닥과 숨을 물체를 조금 더 스캔해줘.")
        XCTAssertEqual(RealityAvailabilityMessage.selectVerticalSide, "숨을 물체의 옆면을 탭해줘.")
        XCTAssertEqual(RealityAvailabilityMessage.moveFartherAway, "조금 떨어진 물체의 옆면을 탭해줘.")
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}
