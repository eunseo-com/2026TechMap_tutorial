import Foundation

enum ComparisonAxis: String, CaseIterable, Equatable, Hashable, Identifiable {
    case world
    case coordinates
    case visibility
    case responsibilities

    var id: Self { self }
}

struct ComparisonRow: Equatable, Identifiable {
    let axis: ComparisonAxis
    let question: String
    let sceneKit: String
    let realityKit: String

    var id: ComparisonAxis { axis }
}

enum ComparisonCompletionStatus: Equatable {
    case completed
    case pending
}

struct ComparisonSummary: Equatable {
    let status: ComparisonCompletionStatus
    let title: String
    let message: String
    let remainingStep: String?

    var completedRealHide: Bool {
        status == .completed
    }
}

enum ChapterThreeRetryAvailability: Equatable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var unavailableReason: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

struct ComparisonModel: Equatable {
    let reason: ComparisonEntryReason
    let rows: [ComparisonRow]
    let summary: ComparisonSummary

    init(reason: ComparisonEntryReason) {
        self.reason = reason
        rows = Self.orderedRows
        summary = Self.summary(for: reason)
    }

    private static let orderedRows = [
        ComparisonRow(
            axis: .world,
            question: "세계를 어디서 얻는가?",
            sceneKit: "개발자가 노드와 좌표로 구성한다.",
            realityKit: "AR session이 관찰한 현실 공간을 함께 사용한다."
        ),
        ComparisonRow(
            axis: .coordinates,
            question: "위치의 기준은 무엇인가?",
            sceneKit: "장면 원점과 부모 노드가 기준이다.",
            realityKit: "현실의 추적 좌표와 anchor가 기준이다."
        ),
        ComparisonRow(
            axis: .visibility,
            question: "앞뒤 관계를 무엇이 결정하는가?",
            sceneKit: "선언한 geometry와 렌더링 규칙이 결정한다.",
            realityKit: "선언한 entity와 인식된 실제 mesh가 함께 결정한다."
        ),
        ComparisonRow(
            axis: .responsibilities,
            question: "책임을 어디에 두는가?",
            sceneKit: "SCNNode에 geometry, physics, action을 모은다.",
            realityKit: "Entity에 필요한 Component와 System을 조합한다."
        )
    ]

    private static func summary(for reason: ComparisonEntryReason) -> ComparisonSummary {
        switch reason {
        case .completedHide:
            ComparisonSummary(
                status: .completed,
                title: "현실 숨바꼭질을 끝냈어",
                message: "실제 물체 뒤로 숨기고, 직접 움직여 피기를 "
                    + "다시 찾는 흐름까지 완료했어.",
                remainingStep: nil
            )
        case .cameraDenied:
            pendingSummary(
                title: "카메라 권한이 필요해",
                message: "카메라 권한이 없어 현실 숨바꼭질을 건너뛰었어.",
                remainingStep: "카메라 권한을 허용한 뒤 Chapter 3에서 "
                    + "실제 물체 뒤 숨기와 재발견을 확인해봐."
            )
        case .cameraRestricted:
            pendingSummary(
                title: "카메라 사용이 제한됐어",
                message: "시스템 카메라 제한으로 현실 숨바꼭질을 건너뛰었어.",
                remainingStep: "카메라를 사용할 수 있는 기기에서 Chapter 3의 "
                    + "실제 가림과 재발견을 확인해봐."
            )
        case .lidarUnavailable:
            pendingSummary(
                title: "LiDAR 지원 기기가 필요해",
                message: "LiDAR scene reconstruction을 사용할 수 없어 "
                    + "현실 숨바꼭질을 건너뛰었어.",
                remainingStep: "LiDAR 지원 기기에서 실제 mesh 가림과 "
                    + "움직여 재발견하기를 확인해봐."
            )
        case .sessionFailed:
            pendingSummary(
                title: "AR 세션이 중단됐어",
                message: "AR session을 이어갈 수 없어 비교로 먼저 이동했어.",
                remainingStep: "세션을 다시 준비한 뒤 Chapter 3의 "
                    + "실제 숨기와 재발견을 완료해봐."
            )
        case .scanTimedOut:
            pendingSummary(
                title: "공간 준비를 마치지 못했어",
                message: "공간 형태와 분류된 바닥을 모두 찾지 못해 "
                    + "비교로 먼저 이동했어.",
                remainingStep: "주변과 바닥을 다시 스캔한 뒤 Chapter 3의 "
                    + "실제 숨기와 재발견을 완료해봐."
            )
        case .assetFailed:
            pendingSummary(
                title: "피기를 불러오지 못했어",
                message: "피기 모델을 불러오지 못해 비교로 먼저 이동했어.",
                remainingStep: "피기를 다시 불러온 뒤 Chapter 3의 "
                    + "실제 숨기와 재발견을 완료해봐."
            )
        }
    }

    private static func pendingSummary(
        title: String,
        message: String,
        remainingStep: String
    ) -> ComparisonSummary {
        ComparisonSummary(
            status: .pending,
            title: title,
            message: message,
            remainingStep: remainingStep
        )
    }
}
