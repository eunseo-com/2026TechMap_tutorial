import XCTest
@testable import PiggyEscape

final class ComparisonModelTests: XCTestCase {
    func test_rowsKeepTheLearningSequenceAndExplainBothWorlds() {
        let model = ComparisonModel(reason: .completedHide)

        XCTAssertEqual(
            model.rows.map(\.axis),
            [.world, .coordinates, .visibility, .responsibilities]
        )
        XCTAssertEqual(
            model.rows.map(\.question),
            [
                "세계를 어디서 얻는가?",
                "위치의 기준은 무엇인가?",
                "앞뒤 관계를 무엇이 결정하는가?",
                "책임을 어디에 두는가?"
            ]
        )
        XCTAssertEqual(
            model.rows.map(\.sceneKit),
            [
                "개발자가 노드와 좌표로 구성한다.",
                "장면 원점과 부모 노드가 기준이다.",
                "선언한 geometry와 렌더링 규칙이 결정한다.",
                "SCNNode에 geometry, physics, action을 모은다."
            ]
        )
        XCTAssertEqual(
            model.rows.map(\.realityKit),
            [
                "AR session이 관찰한 현실 공간을 함께 사용한다.",
                "현실의 추적 좌표와 anchor가 기준이다.",
                "선언한 entity와 인식된 실제 mesh가 함께 결정한다.",
                "Entity에 필요한 Component와 System을 조합한다."
            ]
        )
    }

    func test_onlyCompletedHideReportsThatTheRealHideWasCompleted() {
        let completed = ComparisonModel(reason: .completedHide).summary
        XCTAssertTrue(completed.completedRealHide)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.title, "현실 숨바꼭질을 끝냈어")
        XCTAssertNil(completed.remainingStep)

        for reason in skippedReasons {
            let summary = ComparisonModel(reason: reason).summary
            XCTAssertFalse(summary.completedRealHide, "\(reason) must stay incomplete")
            XCTAssertEqual(summary.status, .pending, "\(reason) must stay pending")
            XCTAssertNotNil(summary.remainingStep, "\(reason) needs a recovery step")
        }
    }

    func test_eachSkippedReasonExplainsWhatStoppedAndWhatRemains() {
        let expectations: [(ComparisonEntryReason, String, String)] = [
            (
                .cameraDenied,
                "카메라 권한이 없어 현실 숨바꼭질을 건너뛰었어.",
                "카메라 권한을 허용한 뒤 Chapter 3에서 "
                    + "실제 물체 뒤 숨기와 재발견을 확인해봐."
            ),
            (
                .cameraRestricted,
                "시스템 카메라 제한으로 현실 숨바꼭질을 건너뛰었어.",
                "카메라를 사용할 수 있는 기기에서 Chapter 3의 "
                    + "실제 가림과 재발견을 확인해봐."
            ),
            (
                .lidarUnavailable,
                "LiDAR scene reconstruction을 사용할 수 없어 현실 숨바꼭질을 건너뛰었어.",
                "LiDAR 지원 기기에서 실제 mesh 가림과 움직여 재발견하기를 확인해봐."
            ),
            (
                .sessionFailed,
                "AR session을 이어갈 수 없어 비교로 먼저 이동했어.",
                "세션을 다시 준비한 뒤 Chapter 3의 실제 숨기와 재발견을 완료해봐."
            ),
            (
                .scanTimedOut,
                "공간 형태와 분류된 바닥을 모두 찾지 못해 비교로 먼저 이동했어.",
                "주변과 바닥을 다시 스캔한 뒤 Chapter 3의 "
                    + "실제 숨기와 재발견을 완료해봐."
            ),
            (
                .assetFailed,
                "피기 모델을 불러오지 못해 비교로 먼저 이동했어.",
                "피기를 다시 불러온 뒤 Chapter 3의 실제 숨기와 재발견을 완료해봐."
            )
        ]

        for (reason, message, remainingStep) in expectations {
            let summary = ComparisonModel(reason: reason).summary
            XCTAssertEqual(summary.message, message, "wrong explanation for \(reason)")
            XCTAssertEqual(summary.remainingStep, remainingStep, "wrong recovery for \(reason)")
        }
    }

    func test_retryAvailabilityPreservesTheUnavailableExplanation() {
        XCTAssertTrue(ChapterThreeRetryAvailability.available.isAvailable)
        XCTAssertNil(ChapterThreeRetryAvailability.available.unavailableReason)

        let unavailable = ChapterThreeRetryAvailability.unavailable(
            reason: "LiDAR 지원 기기에서 다시 시도할 수 있어."
        )
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertEqual(
            unavailable.unavailableReason,
            "LiDAR 지원 기기에서 다시 시도할 수 있어."
        )
    }

    private var skippedReasons: [ComparisonEntryReason] {
        [
            .cameraDenied,
            .cameraRestricted,
            .lidarUnavailable,
            .sessionFailed,
            .scanTimedOut,
            .assetFailed
        ]
    }
}
