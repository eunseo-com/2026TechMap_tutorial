// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/TutorialChapter.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/ComparisonModel.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/TutorialChapterTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/ComparisonModelTests.swift
// Implementation status: integrated
// Verification: standalone iPhoneOS type-check·fresh generic Swift 5/Swift 6 strict build-for-testing·현재 Swift 5 Release build 통과; 물리 iPhone 기준 186/186 통과; 최신 190개 중 추가 4개 runtime은 device unlock 대기; UI test 0개; LiDAR 관찰·동일 기기 캡처는 실기기 대기

enum ComparisonAxis: CaseIterable {
    case world
    case coordinates
    case visibility
    case responsibilities
}

enum ComparisonEntryReason: CaseIterable {
    case completedHide
    case cameraDenied
    case cameraRestricted
    case lidarUnavailable
    case sessionFailed
    case scanTimedOut
    case assetFailed
}

struct ComparisonRow {
    let axis: ComparisonAxis
    let question: String
    let sceneKit: String
    let realityKit: String
}

struct ComparisonSummary {
    let completedRealHide: Bool
    let text: String
}

struct ComparisonModel {
    let rows: [ComparisonRow] = [
        ComparisonRow(
            axis: .world,
            question: "세계를 어디서 얻는가?",
            sceneKit: "개발자가 노드와 좌표로 구성한다.",
            realityKit: "ARKit이 관찰한 현실 공간을 RealityKit 장면과 함께 사용한다."
        ),
        ComparisonRow(
            axis: .coordinates,
            question: "위치의 기준은 무엇인가?",
            sceneKit: "장면 원점과 부모 SCNNode가 기준이다.",
            realityKit: "현실 추적 좌표와 Anchor가 기준이다."
        ),
        ComparisonRow(
            axis: .visibility,
            question: "앞뒤 관계를 무엇이 결정하는가?",
            sceneKit: "선언한 geometry와 렌더링 규칙이 결정한다.",
            realityKit: "선언한 Entity와 ARKit이 관찰한 실제 mesh가 함께 결정한다."
        ),
        ComparisonRow(
            axis: .responsibilities,
            question: "책임을 어디에 두는가?",
            sceneKit: "SCNNode에 geometry, action, physics를 모은다.",
            realityKit: "Entity에 필요한 Component를 조합하고 AR session 관찰은 coordinator가 연결한다."
        ),
    ]

    func summary(for reason: ComparisonEntryReason) -> ComparisonSummary {
        switch reason {
        case .completedHide:
            return ComparisonSummary(
                completedRealHide: true,
                text: "실제 숨기와 이동 재발견 흐름을 마친 경로로 비교에 들어왔어."
            )
        case .cameraDenied:
            return pending("카메라 권한이 거부되어 현실 장을 건너뛰었어.")
        case .cameraRestricted:
            return pending("시스템 카메라 제한으로 현실 장을 건너뛰었어.")
        case .lidarUnavailable:
            return pending("LiDAR scene reconstruction을 사용할 수 없어 현실 장을 건너뛰었어.")
        case .sessionFailed:
            return pending("AR session 실패 뒤 비교 장으로 이동했어.")
        case .scanTimedOut:
            return pending("mesh와 classified floor 준비 시간이 끝나 비교 장으로 이동했어.")
        case .assetFailed:
            return pending("돼지 asset을 불러오지 못해 비교 장으로 이동했어.")
        }
    }

    private func pending(_ reason: String) -> ComparisonSummary {
        ComparisonSummary(
            completedRealHide: false,
            text: "\(reason) 실제 가림·재발견은 실기기 대기 상태야."
        )
    }
}
