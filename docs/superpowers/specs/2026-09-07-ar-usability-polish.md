# AR 시야·실시간 관찰·이동·학습 개선

상태: 2026-09-07 사용자 목표에 따라 구현 중. 기존 네 챕터와 no-Simulator 지침을 유지한다.

## 현재 코드에서 확인한 문제

- `EscapeRootView`는 상단 progress + 최소 104pt 내부 스캔 카드와 하단 title3 설명을 동시에 띄운다. 정보창의 hit testing을 끄는 것만으로는 가려진 카메라 시야가 회복되지 않는다.
- `RealityEnvironmentReadiness`는 mesh/floor 두 Bool을 latch하고, coordinator는 준비 완료 직후 scanning subscription을 취소한다. 따라서 진행 표시가 실제 메시 변화·추적 상태·타깃 적합성을 계속 보여 주지 못한다.
- `RealityHidePlanner`의 앞/뒤 두 점을 `walk(to:)`가 직선으로 잇는다. 실제 물체의 두 면 사이를 이동하면 물체를 통과한다. 회전은 즉시 적용하고 애니메이션 종료는 wall-clock으로 추정한다.
- 공개 컨셉 그림의 UI는 빈 막대로 되어 있고 실제 화면의 판단 기준·실패 복구·관찰 순서와 대응이 약하다.

## 구현 기준

1. **시야**: AR의 중앙은 카메라와 실제 표면 표시만 사용한다. 상단은 작은 챕터 + mesh/floor 상태, 하단은 짧은 다음 행동과 필요한 CTA로 구성한다. 긴 설명과 용어·코드는 명시적으로 여는 학습 sheet로 옮긴다. 큰 글씨에서는 안내를 스크롤 가능하게 하되 카메라를 덮는 영역을 제한한다. 모든 액션은 44pt 이상, 수동 상태 안내는 터치를 통과시킨다.
2. **관찰**: 실제 `ARFrame`의 mesh anchor/triangle 수, classified floor 수, tracking 상태를 최대 4Hz로 공개한다. 중복 timestamp는 세지 않고 tracking 변경은 즉시 전달한다. 최초 준비 latch와 현재 관찰 snapshot은 구분한다. session 중단·학습 sheet·화면 해제 때 선택과 발견 집계를 멈추고 복귀하면 연속 관찰을 새로 요구한다.
3. **표면**: 타깃 선택 중 카메라 중심의 실제 scene-understanding hit를 4Hz로 검사한다. 유효/너무 가까움/바닥 부족/세로면 필요 상태를 작은 reticle과 실제 hit marker로 표시한다. 탭은 그 순간 실제 hit를 다시 검증한다. 메시가 없는 곳에 가짜 박스·물체 semantic label·백분율을 만들지 않는다.
4. **이동**: 바닥 영역 내에서 물체 양옆으로 돌아가는 후보 경로를 만들고, 실제 메시를 가로지르는 segment와 몸통 여유가 없는 경로는 거절한다. 안전한 경로만 움직이고 회전·속도·포즈 전환과 취소 수명을 함께 처리한다. 가림 판정은 기존 5점·2프레임 기준을 유지한다.
5. **학습**: 챕터별로 ‘무엇을 관찰했나 → 왜 그런가 → 어떤 코드가 책임지는가 → 실패하면 무엇을 할까’를 설명한다. 앱 학습 sheet와 DocC에서 같은 용어·기준을 쓴다. 그림은 동작 단계와 UI 표시의 의미가 읽히도록 개선하고 실제 촬영·컨셉·설명 그림을 정확히 표시한다.

## 완료 증거와 한계

- 순수 정책은 실제 production Swift를 사용하는 host XCTest로 실행하고, 앱·통합 테스트 bundle은 generic iPhoneOS로 빌드한다. 기존 Simulator 금지 요청을 우선한다.
- 실기기 연결은 현재 사용자가 어렵다고 답했다. 실제 LiDAR 가림·자연스러운 이동·시야 체감 검증을 완료로 표시하지 않는다.
- DocC 예제 타입 검사, archive, 링크/이미지/언어, desktop/mobile 렌더·접근성을 확인한 뒤 기존 승인된 GitHub Pages에 배포한다.
- 위 다섯 요구 모두의 코드·화면·테스트·공개 배포 증거가 있어야 목표 완료로 판정한다.

참고: [ARFrame.anchors](https://developer.apple.com/documentation/arkit/arframe/anchors), [showSceneUnderstanding](https://developer.apple.com/documentation/realitykit/arview/debugoptions-swift.struct/showsceneunderstanding), [SwiftUI sheet](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:)).

## 구현 중 확정한 경계

- 중앙 카메라 위에는 채움 없는 실제 메시 삼각형 최대 120개 또는 실제 중심 hit의 작은 조준 표시만 올린다. 하단 안내는 세로 60pt·가로 44pt·접근성 큰 글씨 100pt로 제한하고, 넘치는 글은 이 작은 영역 안에서 스크롤한다. 상단 숫자는 물체 수·완료율이 아니다.
- 경로는 초기 출발점에서 바깥으로 0/0.15/0.30/0.45/0.60m, 측면 거리 0.40/0.50/0.60/0.70/0.80/1.0/1.2/1.4m, 추가 깊이 0/0.25/0.55/0.85m의 양방향 후보를 짧은 순으로 검사한다. 2026-09-08 사용자 경로 거절 보고와 돌출 가구·중간 폭 통로 RED를 근거로 고정 출발점·거친 측면 간격을 보수했다. 선택 당시 camera snapshot이 있을 때만 출발점을 확장하며, 새 시작점도 카메라와 0.90m 이상 떨어져야 한다. 인식된 바닥과 몸통 여유를 만족하고 실제 scene-understanding `convexCast`가 통과한 경로만 사용한다. 성공 route의 첫 점에 처음 배치하며, 바닥 부족·카메라 근접·충돌 거절을 구분한다. 측정하지 못한 공간의 안전이나 사람의 이동 경로를 보증하지 않는다.
- 실제 설치 모델의 XZ 경계로 몸통 여유를 다시 계산하며, 이동 중에도 새 메시와 충돌하는지 확인한다. 회전은 제자리에서 가장 짧은 각도로 진행하고 이동은 초당 0.45m·SceneEvents.Update 기반이다. 코너를 둥글게 잘라 장애물 안으로 들어가지 않는다.
- 가림/발견 중 추적 불안정은 다섯 점 전체 무효 + camera pose 없음으로 전달한다. 불안정한 pose를 이동 이력으로 세지 않으며 복구 후 두 개의 새 정상 관찰을 요구한다.
- 학습 창을 열 때 이미 큐에 있던 scan/발견 결과는 닫은 뒤 한 번만 처리한다. 아직 로딩 중인 발견 포즈는 취소하고 새 관찰을 요구한다. 이동/가림 확인 중 앱이 비활성화되면 돼지 이동을 취소하고 선택 단계로 복구한다. 백그라운드 시간은 스캔·중단 대기 시간에 포함하지 않는다.
- Chapter 1의 돼지 탭 수락도 루트에 전달하여 자동 이동 중에는 학습 창을 새로 열지 않는다.

충돌 API 근거: [Scene.convexCast](https://developer.apple.com/documentation/realitykit/scene/convexcast(convexshape:fromposition:fromorientation:toposition:toorientation:query:mask:relativeto:)), [CollisionGroup.sceneUnderstanding](https://developer.apple.com/documentation/realitykit/collisiongroup/sceneunderstanding). 설치된 iPhoneOS SDK 선언과 함께 대조했다.
