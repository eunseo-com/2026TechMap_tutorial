import SwiftUI

enum TutorialLearningTopic: Int, Identifiable {
    case closedWorld = 1, scanning, hiding, comparison
    var id: Int { rawValue }

    init(chapter: TutorialChapter) {
        switch chapter {
        case .closedWorld: self = .closedWorld
        case .openingReality: self = .scanning
        case .realHideAndSeek: self = .hiding
        case .comparison: self = .comparison
        }
    }

    var title: String {
        switch self {
        case .closedWorld: "코드로 만든 세계"
        case .scanning: "공간을 읽는다는 것"
        case .hiding: "숨었다는 증거"
        case .comparison: "두 세계의 책임"
        }
    }

    var observation: String {
        switch self {
        case .closedWorld: "나무와 돼지가 보이는 이유는 장면에 두 노드를 넣었기 때문이야. 현실의 물체는 카메라에 있어도 이 장면의 나무가 되지 않아."
        case .scanning: "물체 위의 청록색 선은 카메라와 LiDAR가 관찰한 메시의 일부야. 노란 선은 바닥으로 분류된 면이야. 선이 없는 곳은 아직 표시되지 않은 영역일 수 있어."
        case .hiding: "걷기가 끝나도 돼지가 보이면 아직 숨은 게 아니야. 몸의 중심과 네 방향을 확인한 뒤에만 찾기가 시작돼. 옆으로 움직여 실제 물체 뒤를 보게 되면 다시 만날 수 있어."
        case .comparison: "첫 장에서는 선언한 나무와 규칙이 숨기를 결정했어. 현실에서는 같은 돼지도 관찰한 공간과 내 시점에 따라 보이거나 가려져."
        }
    }

    var meaning: String {
        switch self {
        case .closedWorld: "노드(SCNNode)는 장면 안의 위치와 생김새·행동을 묶는 단위야. SceneKit도 ARKit과 연결할 수 있지만, 이 장에서는 직접 만든 세계만 사용해."
        case .scanning: "메시(mesh)는 공간 표면을 작은 삼각형으로 연결한 지도야. 앵커(anchor)는 그 지도의 위치 기준이야. 영역 수는 물체 수나 방 전체의 스캔 완료율이 아니야."
        case .hiding: "오클루전(occlusion)은 앞의 물체가 뒤의 돼지를 가리는 관계야. 몸의 중심을 포함한 4/5점이 서로 다른 두 프레임에서 가려져야 숨김을 인정해. 찾기도 이동 이력과 3/5점의 연속 노출을 확인해."
        case .comparison: "Entity는 대상을, Component는 데이터나 능력을 표현해. System은 관련 데이터를 읽어 행동을 처리해. 이번 앱에서는 정책과 AR 관찰을 분리해 센서 없이도 판단 규칙을 테스트해."
        }
    }

    var code: String {
        switch self {
        case .closedWorld: "scene.rootNode.addChildNode(pig)\n// 장면에 추가한 노드가 이 세계에 존재한다."
        case .scanning: "hasMesh && hasClassifiedFloor\n// 공간의 형태와 돼지가 설 바닥을 모두 확인한다."
        case .hiding: "centerBlocked && blockedCount >= 4\n// 한 번이 아닌, 서로 다른 두 프레임에서 확인한다."
        case .comparison: "ARFrame → 관찰값 → 정책 → 화면 상태\n// 센서가 본 것과 앱의 판단을 나눈다."
        }
    }

    var recovery: String {
        switch self {
        case .closedWorld: "나레이션이 끝난 뒤 돼지를 탭해봐. 나무 뒤에 도착하면 이 장에서 정한 규칙에 따라 다음 장으로 이어져."
        case .scanning: "밝은 곳에서 바닥과 물체 옆면을 천천히 비춰줘. 표면이 반사되거나 무늬가 없으면 추적이 어려울 수 있어. 준비 표시가 두 개 모두 켜져도 방 전체가 완벽하게 스캔됐다는 뜻은 아니야."
        case .hiding: "카메라에서 90cm 이상 떨어진, 바닥에 닿아 있는 넓은 물체의 옆면을 골라줘. 숨김 확인이 실패하면 옆면과 주변 바닥을 더 비추거나 다른 물체를 선택해봐."
        case .comparison: "현실 체험을 건너뛰었다면 비교 설명과 실제 관찰은 구분해 기억해줘. 조건이 맞는 기기에서는 현실 숨바꼭질을 다시 시도할 수 있어."
        }
    }
}

struct TutorialLearningView: View {
    let topic: TutorialLearningTopic
    let telemetry: RealityScanTelemetry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("지금 볼 것", topic.observation)
                    section("이 말의 뜻", topic.meaning)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("코드와 연결하기").font(.headline)
                        Text(topic.code)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                        Text("핵심 조건을 줄인 설명용 코드야. 전체 실행 예제는 튜토리얼에서 확인할 수 있어.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if topic == .scanning {
                        section("설명을 열기 직전 관찰", "메시 영역 \(telemetry.meshAnchorCount)개 · 삼각형 \(telemetry.meshFaceCount)개 · 바닥 앵커 \(telemetry.floorAnchorCount)개\n이 수치는 공간 변화에 따라 늘거나 줄 수 있어.")
                    }
                    section("잘 안 되면", topic.recovery)
                    Link("전체 코드와 그림 보기", destination: tutorialURL)
                        .font(.headline).frame(minHeight: 44)
                }
                .padding(24)
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }

    private var tutorialURL: URL {
        let route: String
        switch topic {
        case .closedWorld: route = "01-closedworld"
        case .scanning: route = "02-openingthedoor"
        case .hiding: route = "03-realhideandseek"
        case .comparison: route = "04-comparison"
        }
        return URL(string: "https://eunseo-com.github.io/2026TechMap_tutorial/tutorials/scenekittorealitykit/\(route)/")!
    }

    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(detail).font(.body).lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
