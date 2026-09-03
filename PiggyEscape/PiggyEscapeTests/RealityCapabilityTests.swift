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
        XCTAssertEqual(
            RealityAvailabilityMessage.selectVerticalSide,
            "카메라에서 90cm 이상 떨어진 실제 물체의 옆면을 탭해줘."
        )
        XCTAssertEqual(
            RealityAvailabilityMessage.moveFartherAway,
            "카메라에서 90cm 이상 떨어진 물체의 옆면을 탭해줘."
        )
    }

    func test_sessionDiagnosticsIdentifyTheCameraFrameBoundary() {
        XCTAssertEqual(
            RealitySessionDiagnostic.starting.message,
            "AR 세션 시작 요청됨"
        )
        XCTAssertEqual(
            RealitySessionDiagnostic.cameraFrameReceived.message,
            "AR 카메라 프레임 수신됨"
        )
        XCTAssertEqual(
            RealitySessionDiagnostic.failed("카메라 접근 실패").message,
            "AR 세션 실패: 카메라 접근 실패"
        )
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}
