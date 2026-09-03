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

세션 시작은 환경 readiness 준비 완료와 동일하지 않다. camera frame이 들어와도 mesh나 floor가 아직 하나뿐이면 Chapter 2의 준비 상태를 유지한다.

유효한 layout과 non-empty bounds를 확인한 뒤 session을 시작한다. 이후 mesh 그리고 classified floor를 모두 관찰해야 ready가 된다.

## 현재 코드가 강제하는 순서

1. SwiftUI가 Reality container를 표시한다.
2. container가 `layoutSubviews`에서 내부 `ARView`의 frame을 확정한다.
3. window가 있고 width·height가 0보다 클 때 session start gate를 한 번 연다.
4. scanning 중에는 pig anchor를 attach하지 않는다.
5. mesh와 classified floor를 모두 관찰하면 one-shot ready를 알린다.
6. 사용자가 CTA를 누르면 같은 view·session으로 Chapter 3에 들어간다.
7. Chapter 3에서 실제 surface hit, 거리와 floor region이 모두 유효한 target을 수락한 뒤에만 cycle anchor를 attach한다.

이 순서는 session configuration, readiness와 hide content의 수명을 분리한다. 새 target을 받을 때마다 session을 다시 시작하지 않는다.

## 검은 화면을 좁히는 질문

1. 권한 상태가 `.authorized`인가?
2. `ARView.window`가 존재하고 bounds가 유효한가?
3. session 시작 callback이 같은 generation에서 중복되지 않았는가?
4. tracking interruption 또는 session failure가 전달되었는가?
5. scanning 전에 pig anchor나 model load를 시작하지 않았는가?
6. Chapter 전환으로 Reality subtree가 의도치 않게 다시 만들어지지 않았는가?

각 질문을 한 번에 하나씩 확인한다. scene reconstruction이나 plane detection을 끄고 화면이 바뀌었다는 사실만으로 원인을 확정하지 않는다.

## 표시와 상태가 어긋날 때

- camera 배경은 보이지만 mesh 표시가 없다면 scene reconstruction 지원과 실제 주변 스캔을 확인한다.
- `showSceneUnderstanding` mesh는 보이지만 ready가 아니라면 “바닥” 진행이 완료되었는지 확인한다.
- ready인데 CTA 전 tap이 target을 만든다면 interaction mode가 `.preparing`인지 확인한다.
- CTA 뒤에도 mesh debug가 화면을 덮는다면 Chapter 3 전환에서 debug option을 제거했는지 확인한다.
- accepted hit marker가 엉뚱한 곳에 보인다면 marker 입력이 실제 accepted surface position인지 확인한다.

## 실기기 대기

다음 항목은 source 구조만으로 완료 처리하지 않는다.

- [ ] 실제 camera 배경과 tracking interruption·복귀
- [ ] 실제 `showSceneUnderstanding` mesh와 classified floor 진행
- [ ] ready one-shot 피드백과 accepted hit marker 위치
- [ ] 실제 floor fit, 0.18m 크기와 0.90m target 거리
- [ ] 물리적 occlusion·reveal과 다시 숨기기 lifecycle

이 항목은 LiDAR 지원 실기기에서 관찰하기 전까지 모두 실기기 대기다. 이번 최신 변경 검증에서는 Simulator runtime을 실행하지 않았으며 generic iPhoneOS build도 camera·mesh 동작 증거가 아니다.

## 관련 문서

- <doc:02-OpeningTheDoor>
- <doc:03-RealHideAndSeek>
- <doc:RealityKitECS>
