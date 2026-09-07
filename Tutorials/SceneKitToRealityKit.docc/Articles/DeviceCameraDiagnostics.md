# 실기기 카메라 진단 — 레이아웃, 세션과 준비 상태 분리

이 문서는 Chapter 2의 카메라 배경 문제를 조사하며 확인한 수명 경계를 기록한다. 과거 한 실기기에서 관찰한 검은 화면을 모든 기기의 보편적 원인으로 확대하지 않고, 다시 확인할 수 있는 진단 순서만 남긴다.

## 관찰한 증상과 범위

한 iPhone 16 Pro 환경에서 C3 장면 뒤 카메라 권한을 허용했지만 안내 아래의 `ARView` 배경이 검게 남은 적이 있었다. 당시 변경을 한 항목씩 분리한 결과, AR configuration 옵션보다 내부 view의 layout, session 시작과 content attachment 순서가 문제 경계를 설명했다.

이 기록은 해당 재현의 결론이다. OS·기기·권한·tracking 상태가 다른 검은 화면까지 같은 원인이라고 단정하지 않는다.

## 먼저 구분할 네 상태

| 상태 | 확인할 사실 |
| --- | --- |
| 카메라 권한 | authorized인지, denied/restricted인지 |
| view layout | 내부 `ARView`가 window에 붙고 bounds가 비어 있지 않은지 |
| session 시작 | valid layout 뒤 한 generation에서 한 번 시작했는지 |
| 환경 준비 | 실제 mesh와 classified horizontal floor를 모두 관찰했는지 |
| 현재 관찰 | 최신 mesh·floor 수와 tracking이 지금도 target 선택을 허용하는지 |

세션 시작은 환경 readiness 준비 완료와 동일하지 않다. camera frame이 들어와도 mesh나 floor가 아직 하나뿐이면 Chapter 2의 준비 상태를 유지한다.

유효한 layout과 non-empty bounds를 확인한 뒤 session을 시작한다. 이후 mesh 그리고 classified floor를 모두 관찰해야 ready가 된다.

## 현재 코드가 강제하는 순서

1. SwiftUI가 Reality container를 표시한다.
2. container가 `layoutSubviews`에서 내부 `ARView`의 frame을 확정한다.
3. window가 있고 width·height가 0보다 클 때 session start gate를 한 번 연다.
4. scanning 중에는 pig anchor를 attach하지 않는다.
5. mesh와 classified floor를 모두 관찰하면 one-shot ready를 알리되, 현재 관찰 snapshot은 계속 갱신한다.
6. 현재 tracking이 normal이고 mesh와 floor가 지금도 있을 때만 “숨바꼭질 시작” CTA를 활성화한다.
7. 사용자가 CTA를 누르면 같은 view·session으로 Chapter 3에 들어간다.
8. Chapter 3에서 실제 surface hit, 거리·floor region과 전체 측면 route가 모두 유효한 target을 수락한 뒤에만 cycle anchor를 attach한다.

이 순서는 session configuration, readiness와 hide content의 수명을 분리한다. 새 target을 받을 때마다 session을 다시 시작하지 않는다.

## 최초 준비와 현재 telemetry를 함께 진단하기

`RealityEnvironmentReadiness`는 최초 mesh+floor 관찰을 latch해 Chapter 2의 한 번뿐인 준비 전이를 지킨다. `RealityScanTelemetryTracker`는 그와 별도로 최신 `ARFrame`의 mesh anchor 수, triangle 수, classified floor 수와 tracking을 최대 4 Hz로 공개한다. 같은 timestamp는 다시 세지 않으며, tracking 또는 mesh/floor 유무가 바뀌면 다음 0.25초 주기를 기다리지 않고 즉시 전달한다.

현재 수치는 공간을 다시 비추면 늘거나 줄 수 있다. mesh anchor 수는 물체 수가 아니고, triangle 수도 방 전체의 스캔 완료율이 아니다. 카메라 위에는 화면 안의 실제 mesh 삼각형 최대 120개의 채움 없는 선만 그린다. 이 선이 없는 공간을 안전하거나 비어 있다고 추정하지 않는다.

## 검은 화면을 좁히는 질문

1. 권한 상태가 `.authorized`인가?
2. `ARView.window`가 존재하고 bounds가 유효한가?
3. session 시작 callback이 같은 generation에서 중복되지 않았는가?
4. tracking interruption 또는 session failure가 전달되었는가?
5. scanning 전에 pig anchor나 model load를 시작하지 않았는가?
6. Chapter 전환으로 Reality subtree가 의도치 않게 다시 만들어지지 않았는가?

각 질문을 한 번에 하나씩 확인한다. scene reconstruction이나 plane detection을 끄고 화면이 바뀌었다는 사실만으로 원인을 확정하지 않는다.

## 표시와 상태가 어긋날 때

- camera 배경은 보이지만 얇은 mesh 선이 없다면 scene reconstruction 지원, tracking과 실제 주변 스캔을 확인한다.
- “공간” chip은 켜졌지만 ready가 아니라면 “바닥” chip이 classified floor를 현재 보고 있는지 확인한다.
- ready latch 뒤 CTA가 비활성화됐다면 현재 tracking·mesh·floor 중 무엇이 사라졌는지 아래 안내를 확인한다.
- CTA 전 tap이 target을 만든다면 interaction mode가 `.preparing`인지 확인한다.
- Chapter 3 중앙 preview와 실제 tap 결과가 다르면 tap 순간의 위치에서 scene-understanding hit과 floor를 다시 검사했는지 확인한다.
- accepted hit marker가 엉뚱한 곳에 보인다면 marker 입력이 실제 accepted surface position인지 확인한다.

학습 sheet가 열려 있을 때 AR 입력과 active-time deadline은 멈춘다. 닫을 때 이미 큐에 있던 최신 scan·준비·발견 event는 한 번만 처리하며, 비활성화 시간은 scan·interruption deadline에 포함하지 않는다.

## 현재 자동 검증 경계

현재 앱 checkpoint에는 정적 XCTest 222개가 있다. 실제 production Swift를 쓰는 host 정책 runtime 48/48과 browser failure contract 13/13이 통과했고, fresh generic iPhoneOS Swift 5·Swift 6 strict `build-for-testing` 및 현재 Swift 5 Release build가 exit 0이다. 물리 iPhone의 기준 unit XCTest 186/186은 이전 checkpoint의 결과이며, 최신 222개 전체 runtime을 이번 변경에서 실행한 것은 아니다. AppIntents dependency 부재 metadata warning 1건이 남지만 source compile warning은 관찰되지 않았다.

이 자동 결과는 카메라 시야, 실제 mesh 선, 측면 route의 자연스러움이나 LiDAR 가림을 증명하지 않는다. UI test는 0개이며 공개 Pages도 아직 이전 버전이다.

## 실기기 대기

다음 항목은 source 구조만으로 완료 처리하지 않는다.

- [ ] 실제 camera 배경과 tracking interruption·복귀
- [ ] 실제 채움 없는 mesh 선과 현재 mesh/floor chip, tracking 복구
- [ ] ready one-shot, 현재 상태 CTA, 중앙 preview·tap 재검사와 accepted hit marker 위치
- [ ] 실제 floor fit, 0.18m 크기, 0.90m target 거리와 측면 `convexCast` route
- [ ] 0.45m/s scene-time 이동, live obstruction 복구, 물리적 occlusion·reveal과 다시 숨기기 lifecycle

이 항목은 LiDAR 지원 실기기에서 관찰하기 전까지 모두 실기기 대기다. 이번 최신 변경 검증에서는 Simulator runtime을 실행하지 않았으며 generic iPhoneOS build도 camera·mesh 동작 증거가 아니다.

## 관련 문서

- <doc:02-OpeningTheDoor>
- <doc:03-RealHideAndSeek>
- <doc:RealityKitECS>
