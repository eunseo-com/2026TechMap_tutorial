# Chapter 2–4 실행 가능한 튜토리얼 설계

> 아래는 2026-09-19 독립 입문 실습의 설계·구현 기록이다. 본편 앱의 현재 상태는 `docs/PROJECT_CONTEXT.md`, GitHub Pages 통합은 `docs/2026-09-20-github-pages-reader.md`를 따른다.

2026-09-19 사용자 요청으로 학습용 실습·DocC·읽기 페이지의 범위를 Chapter 4까지 확장한다. 기존 Chapter 1 본편 앱 Task 6–7의 상태와 외부 게시 승인 상태는 별개다.

## 학습 경로

- Chapter 2 `02-OpeningTheDoor`: 카메라 → 수평면 탐지 → 탭한 수평면에 돼지 배치. 기본 편집 파일은 ContentView.swift 하나다.
- Chapter 3 `03-RealHideAndSeek`: 메시 지원 확인 → 메시 기반 가려짐 → 같은 위치에서 켬/끔 비교. 자동 숨을 곳 탐색이나 가구 분류는 구현하지 않는다. 사용자가 실제 물체 뒤의 빈 바닥에 배치하고 카메라를 움직여 비교한다.
- Chapter 4 `04-Comparison`: 카메라 없는 RealityKit 장면 → PatrolComponent 추가 → 속도·정지 변경 → 실제 PatrolSystem 코드를 읽으며 SceneKit과 비교한다. 실기기 없이도 이 장은 수행할 수 있다.

## 구현 계약

최소 iOS 17, Swift 6, SwiftUI + RealityKit ARView를 사용한다. ARKit 세션과 메시 설정을 독자가 직접 읽게 하려는 선택이다. RealityView도 가능하나 이번 실습에서 뷰 API 전환까지 추가하지 않는다.

공통 준비 코드:

- `SpatialLessonView(configuration: ARWorldTrackingConfiguration, enableOcclusion: Bool = false, place: ((AnchorEntity) -> Void)? = nil)` — 카메라 권한, 지원 확인, 상태 안내, 탭 raycast, 앵커 수명, 재시도, 세션 종료를 담당한다. 구성은 시작 시 한 번 적용하며 가려짐 변경은 기존 세션·앵커를 유지한다.
- `TutorialPig.make() -> Entity` — 제공된 Piggy.usdc를 약 18cm 크기로 정규화한다. 모델이 없으면 명시적으로 이름 붙인 분홍 대체 상자를 사용한다.
- `ECSLessonView(configure: (Entity) -> Void)` — 비 AR 장면을 제공한다. updateUIView에서도 configure를 호출해 SwiftUI 상태 변경을 반영한다.
- `PatrolComponent(speed: Float)` — 초당 미터 단위 속도 데이터. System은 이 컴포넌트가 있는 Entity만 왕복 이동시킨다. 속도 0은 정지이며 컴포넌트 제거도 이동을 멈춘다.
- `PatrolMotion` — 경계 반사와 시간 간격 처리를 순수 연산으로 분리해 긴 프레임·경계·정지를 검증한다.

2장에는 `Door-01-ContentView.swift`(카메라), `Door-02-ContentView.swift`(수평면), `Door-03-ContentView.swift`(돼지) 전체 파일을 제공한다. 3장은 `Hide-01-ContentView.swift`(메시·가려짐 끔), `Hide-02-ContentView.swift`(켬), `Hide-03-ContentView.swift`(실행 중 Toggle). 4장은 `Compare-01-ContentView.swift`(컴포넌트 없음), `Compare-02-ContentView.swift`(속도 0.25), `Compare-03-ContentView.swift`(Toggle로 0 또는 0.25)다.

## 기기·실패 처리

- AR 카메라: NSCameraUsageDescription 설정을 준비 단계에 포함한다. 권한 거부 시 설정으로 이동할 수 있다.
- 시뮬레이터·AR 미지원 기기: 실기기가 필요하다는 안내를 표시하고 세션을 시작하지 않는다.
- 평면 탐지는 바닥뿐 아니라 책상 등 수평면도 찾는다. 바닥 분류로 표현하지 않는다.
- 탭은 기존 수평면 geometry의 raycast 결과가 있을 때만 배치한다. 결과 없음·tracking 제한 시 다시 시도할 위치를 안내한다.
- 메시: supportsSceneReconstruction(.mesh) 조건을 만족할 때만 구성한다. 미지원 기기에서 가려짐이 된다고 표시하지 않는다.
- 가려짐 비교는 세션을 재시작하거나 돼지를 새로 놓지 않는다.
- 세션 중단·오류·재시작에서는 상태 문구와 앵커 참조를 함께 갱신한다.

## 콘텐츠·다운로드·사이트

각 장은 별도 새 Xcode 앱에서 시작할 수 있다. Starter에 준비 파일과 모델, Answers에 세 단계의 전체 ContentView, README에 카메라·실기기·중복 파일 주의를 포함한다. ZIP 이름은 `OpeningTheDoor-Lab.zip`, `RealHideAndSeek-Lab.zip`, `Comparison-Lab.zip`이다.

DocC만 본문의 원본으로 유지한다. 읽기 페이지 경로는 Chapter 1 `/`, Chapter 2 `/chapters/2/`, Chapter 3 `/chapters/3/`, Chapter 4 `/chapters/4/`다. 모든 장에 4장 탐색과 이전·다음 장 이동을 제공한다. 준비 중 문구를 현재 범위에 맞게 바꾼다. 글꼴·변경 줄·복사·모바일 레이아웃은 기존 가독성 개선을 유지한다.

실제 AR 사진이 없으면 가려짐 성공 사진을 생성하거나 참고 사진을 검증 증거로 사용하지 않는다. 대신 따라 할 배치와 비교 절차를 정확하게 쓰고 실기기 검증 여부를 표시한다.

## 검증

9개 신규 코드 구간을 iOS 시뮬레이터·실기기 SDK에서 Swift 6 타입 검사한다. 다운로드 ZIP에서 추출한 최종 앱 3개를 빌드한다. 2·3장은 미지원 안내를, 4장은 실제 ECS 이동·정지를 시뮬레이터에서 확인한다. PatrolMotion은 경계·긴 프레임·시간 분할·속도 0을 검사한다. DocC 경고 0개, 네 읽기 페이지의 복사 원문·다운로드·링크·목차, 웹 빌드와 모바일을 검증한다. 카메라·실측 평면·메시 가려짐은 연결된 지원 실기기가 있을 때만 실제 검증 완료로 기록한다.

## 근거

- [Apple: reconstructed scene sample](https://developer.apple.com/documentation/arkit/visualizing-and-interacting-with-a-reconstructed-scene) — 메시 구성, 지원 기기, 환경의 occlusion 옵션.
- [Apple: SceneKit에서 RealityKit으로](https://developer.apple.com/videos/play/wwdc2025/288/) — 노드 속성과 ECS 책임의 차이, 기존 앱과 새 개발의 판단.
- 기존 `2026-08-19-beginner-first-docc-tutorial-design.md`의 학습 목표와 `docs/tutorial-feedback-validation.md`의 낮은 학습 부담을 함께 유지한다.
