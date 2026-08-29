# SceneKit에서 RealityKit으로 — 4개 챕터 완성 설계

> 상태: 사용자 검토 대기
>
> 범위: 앱의 Chapter 1–4 학습 경험, 실제 물체 뒤 숨기 안정화, 재시도·완료 흐름, 공개 DocC
>
> 공개 문서 기준 URL: `https://eunseo-com.github.io/2026TechMap_tutorial/tutorials/scenekittorealitykit/`

## 1. 결정 요약

이 설계는 기존 앱에 구현된 C3 섬과 RealityKit 숨바꼭질을 버리지 않고, 한 화면에 섞여 있던 과정을 네 개의 학습 챕터로 분리한다.

1. **Chapter 1 — 닫힌 세계**: C3 SceneKit 섬에서 돼지가 나무 뒤로 숨으려 하지만 코드로 만든 세계 안에서 곧 들킨다.
2. **Chapter 2 — 현실로 문 열기**: 카메라 권한, AR 세션, 바닥·메시 준비를 거쳐 현실 좌표계를 얻는다.
3. **Chapter 3 — 진짜 숨바꼭질**: 실제 물체를 선택하고, 18cm 돼지가 충분한 거리에서 물체 뒤로 이동해 실제 메시로 가려진 뒤, 사용자가 움직여 다시 찾는다.
4. **Chapter 4 — 차이 돌아보기**: SceneKit과 RealityKit을 세계·좌표·가림·책임 구조의 네 축으로 비교하고 튜토리얼을 완료한다.

Chapter 2와 Chapter 3은 같은 `ARView`와 같은 `ARSession`을 유지한다. Chapter 2에서 준비된 세션을 Chapter 3 진입 때 다시 시작하지 않는다. 진행 상태는 한 개의 상태 기계에서 파생하며, 화면이 별도의 챕터 번호를 독립적으로 저장해 상태가 어긋나지 않게 한다.

사용자가 이 문서를 승인하면 다음 이전 기준을 대체한다.

- Chapter 1 하나에 SceneKit·권한·RealityKit·실제 숨기까지 모두 포함했던 범위 구분
- Chapter 1을 단순 방·가짜 소파 예제로 되돌리고 Chapter 2–4의 앱 구현을 보류했던 초기 교육 구상
- 돼지 중심점 하나만 raycast해 가림과 재발견을 판정했던 정책
- 높이 0.35m, 최소 카메라 거리 0.45m의 임시 배치 값

기존 방·가짜 소파 코드는 SceneKit 개념을 설명하는 참고 예제로 남길 수 있지만, 실행 앱의 Chapter 1은 현재 C3 섬 경험을 기준으로 한다.

## 2. 목표와 완료 조건

### 목표

- 돼지가 카메라 화면을 과도하게 가리지 않는 현실적인 크기와 거리로 배치된다.
- “옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐.” 안내는 실제 물체 메시가 돼지 실루엣을 충분히 가린 뒤에만 나타난다.
- 사용자는 화면 탭이 막히지 않은 상태에서 실제로 움직여 돼지를 찾고, 다시 숨기거나 비교 장으로 진행할 수 있다.
- Chapter 1부터 Chapter 4까지 진행·오류·재시도·완료 경로가 끊기지 않는다.
- 앱 구현과 공개 DocC가 같은 챕터 의미, 같은 수치, 같은 코드 계약을 설명한다.
- 공개 DocC는 네 챕터, 고유 이미지, 정상 링크, 한국어 접근성, 재현 가능한 빌드·배포 검증을 갖는다.

### 완료의 의미

자동 테스트와 Simulator는 상태·수학·UI 연결·빌드·문서 구조를 검증한다. 실제 메시 가림, 실제 크기 체감, 물리적 이동 재발견과 그 증거 스크린샷은 LiDAR 지원 실기기에서만 완료로 판정한다. 실기기가 연결되지 않은 동안 구현과 자동 검증은 계속 진행하되, 실기기 항목을 Simulator 결과로 완료 처리하지 않는다.

### 제외 범위

- 실제 물체가 의자인지 소파인지 자동 분류하는 기능
- LiDAR 미지원 기기에서 가짜 깊이 마스크로 오클루전을 흉내 내는 기능
- C3 금융·저장·Watch 기능
- SceneKit API를 RealityKit API로 일대일 자동 변환하는 도구
- 점수, 계정, 네트워크, 분석 SDK처럼 학습 흐름과 무관한 제품 기능

## 3. 전체 경험 흐름

```text
Chapter 1
openingNarration
  → readyForPigTap
  → walkingBehindTree
  → hiddenInClosedWorld
  → discoveredByCamera

Chapter 2
requestingCameraPermission
  → cameraDenied ───────────────┐
  → cameraRestricted ───────────┤
  → scanningReality            │
  → realityReady               │
  → lidarUnavailable ──────────┤
  → sessionFailed ─────────────┤
  → scanTimedOut ──────────────┤
                               │
Chapter 3                     │
waitingForRealTarget           │
  → walkingBehindRealObject    │
  → verifyingOcclusion         │
  → hiddenInReality            │
  → discoveredInReality        │
  → realityAssetFailed ────────┤
       ↘ 다시 숨기기 ──────────┘ (waitingForRealTarget)

Chapter 4
comparison(entryReason)
  → completed
  → 처음부터 다시 보기 (openingNarration)
```

### 챕터 라우팅 규칙

`TutorialChapter`는 `closedWorld`, `openingReality`, `realHideAndSeek`, `comparison` 네 값을 가진다. 현재 챕터는 `EscapeExperienceState`에서 계산하는 읽기 전용 값이다.

| 상태 | 표시 챕터 | 주 화면 |
| --- | --- | --- |
| `openingNarration` ~ `discoveredByCamera` | Chapter 1 | C3 SceneKit |
| `requestingCameraPermission`, `cameraDenied`, `cameraRestricted`, `scanningReality`, `realityReady`, `lidarUnavailable`, `sessionFailed`, `scanTimedOut` | Chapter 2 | 권한 안내 또는 RealityKit |
| `waitingForRealTarget` ~ `discoveredInReality`, `realityAssetFailed` | Chapter 3 | 동일한 RealityKit |
| `comparison(entryReason)`, `completed(entryReason)` | Chapter 4 | 비교·완료 SwiftUI |

기존 `EscapeExperienceMachine`을 유일한 흐름 상태 기계로 확장한다. 별도의 `ChapterFlowMachine`은 만들지 않는다. `ComparisonEntryReason`은 `completedHide`, `cameraDenied`, `cameraRestricted`, `lidarUnavailable`, `sessionFailed`, `scanTimedOut`, `assetFailed` 중 하나이며 `comparison`과 `completed`가 같은 값을 보존한다.

핵심 신규 전이는 다음과 같다.

| 현재 상태 | 이벤트 | 다음 상태·효과 |
| --- | --- | --- |
| `requestingCameraPermission` | `cameraAuthorized` | `scanningReality` |
| `requestingCameraPermission` | `cameraAuthorizationDenied` | `cameraDenied` |
| `requestingCameraPermission` | `cameraAuthorizationRestricted` | `cameraRestricted` |
| `scanningReality` | `meshUnsupported` | `lidarUnavailable` |
| `scanningReality` | `environmentReady` | `realityReady` |
| `scanningReality` | `scanDeadlineElapsed` | `scanTimedOut` |
| Chapter 2·3의 AR 상태 | `sessionDidFail` | 현재 AR·cycle을 정리하고 `sessionFailed` |
| `realityReady` | `startRealHide` | `waitingForRealTarget` |
| `waitingForRealTarget` | `realTargetAccepted` | `walkingBehindRealObject` |
| `walkingBehindRealObject` | `movementFinished` | `verifyingOcclusion` |
| `verifyingOcclusion` | `occlusionRetryStarted` | `walkingBehindRealObject` |
| `verifyingOcclusion` | `occlusionVerified` | `hiddenInReality` |
| `verifyingOcclusion` | `occlusionExhausted` | cycle을 정리하고 `waitingForRealTarget` |
| `hiddenInReality` | `realityPigDiscovered` | `discoveredInReality` |
| Chapter 3의 active hide 상태 | `sessionInterrupted` | cycle을 정리하고 `waitingForRealTarget`; interruption overlay 유지 |
| Chapter 3의 모델 로드 상태 | `realityAssetLoadFailed` | cycle을 정리하고 `realityAssetFailed` |
| `discoveredInReality` | `replayRealHide` | cycle을 정리하고 `waitingForRealTarget` |
| `discoveredInReality` | `reviewDifferences` | `comparison(.completedHide)` |
| `cameraDenied` | `openSettings` | 상태를 유지하고 명시적 1회 권한 재확인 예약 |
| `cameraDenied` | Settings 복귀 뒤 `cameraAuthorized` | 새 AR generation의 `scanningReality` |
| `sessionFailed`·`scanTimedOut` | `retryReality` | 새 AR generation의 `scanningReality` |
| `realityAssetFailed` | `retryReality` | 새 hide-cycle generation의 `waitingForRealTarget` |
| Chapter 2·3 오류 상태 | `skipToComparison` | 현재 오류를 reason으로 보존한 `comparison` |
| `comparison(reason)` | `finishTutorial` | `completed(reason)` |
| `comparison`·`completed` | `retryChapter3` | 지원 기기에서 새 AR generation의 `scanningReality` |
| 모든 상태 | `reset` | 모든 generation을 갱신하고 `openingNarration` |

`cameraDenied`에서 Settings를 실제로 연 뒤 권한이 허용되면 기존 계약대로 `cameraAuthorized → scanningReality`를 허용한다. `cameraRestricted`에는 Settings CTA를 표시하지 않는다. 잘못된 순서나 중복 이벤트는 상태를 바꾸지 않는다. 비동기 callback은 experience generation과 hide-cycle generation을 함께 확인하며, replay나 화면 해제 뒤 이전 generation의 callback은 무시한다.

## 4. 런타임 구조

### 얇은 챕터 라우터

`EscapeRootView`는 3D 로직을 직접 소유하지 않고 현재 상태가 요구하는 컨테이너만 선택한다.

- Chapter 1: `C3ClosedWorldSceneView`
- Chapter 2–3: 하나의 `RealityHideARView`
- Chapter 4: `ComparisonView`와 `TutorialCompletionView`
- 공통: `ChapterProgressView`, 상태 안내, 명시적 CTA

Chapter 2에서 `RealityHideARView`가 나타나면 세션을 한 번 시작한다. `realityReady`가 되어도 뷰 identity를 바꾸지 않는다. “숨바꼭질 시작”을 누르면 AR 화면을 그대로 둔 채 타깃 선택만 활성화한다.

### AR 상호작용 모드

AR coordinator는 외부 상태에서 파생된 모드를 받는다.

- `preparing`: 세션과 메시·바닥 준비만 수행한다. 화면 탭으로 타깃을 만들지 않는다.
- `selectingTarget`: Chapter 3에서만 세로 물체 선택을 받는다.
- `moving`: 새 선택을 잠그고 돼지 이동·가림 검증을 수행한다.
- `searching`: 타깃 선택을 잠그고 재발견만 관찰한다.
- `revealed`: AR 추적은 유지하지만 새 선택은 CTA를 누르기 전까지 받지 않는다.

SwiftUI의 안내 패널은 `.allowsHitTesting(false)`를 적용한다. 사용자가 눌러야 하는 버튼은 별도의 safe-area CTA 영역에 두고 최소 44×44pt 터치 영역을 보장한다.

### 수명과 정리

- Chapter 4로 넘어가거나 전체 화면을 닫을 때 update subscription, tap recognizer, 예약 task, 앵커와 AR session을 명시적으로 정리한다.
- 각 hide cycle은 새 `pigAnchor`, 새 `RealityPigVisualController`, 새 attachment gate와 증가하는 cycle generation을 소유한다. 유효 타깃을 수락한 뒤 그 cycle의 anchor를 scene에 정확히 한 번 추가한다.
- “다시 숨기기”와 가림 검증 실패는 현재 cycle의 예약·subscription·controller load를 취소하고 anchor를 scene에서 제거한 뒤 cycle generation을 증가시킨다. AR session은 재시작하지 않고 Chapter 3의 타깃 선택으로 돌아간다.
- “처음부터 다시 보기”는 experience generation을 증가시키고 AR 컨테이너를 새 identity로 생성해 Chapter 1부터 시작한다.
- 모델 비동기 로드와 늦은 AR callback은 experience generation과 cycle generation이 모두 일치할 때만 화면 상태를 바꾼다.

## 5. 챕터별 상세 경험

### Chapter 1 — 닫힌 세계

기존 C3 섬·나무·돼지 포즈·궤도 카메라 표현을 유지한다.

1. 나레이션이 끝나기 전 돼지 탭은 무시한다.
2. 탭하면 돼지는 기존 `Cylinder_Tree` 뒤로 걷는다.
3. 도착 뒤 0.40초를 유지하면 카메라 조작 여부와 무관하게 놀란 모델, “아, 들켰네… 제대로 숨고 싶은데.”, 1.5배→1.0배 반응을 한 번 실행한다.
4. 0.70초 페이드가 끝나면 Chapter 2의 카메라 권한 단계로 넘어간다.

Chapter 1의 학습 결론은 “이 장면의 나무와 숨기 규칙은 개발자가 만든 세계 안에만 있다”이다. SceneKit 자체가 ARKit과 함께 쓰일 수 없다는 뜻으로 설명하지 않는다.

### Chapter 2 — 현실로 문 열기

1. 카메라 권한을 아직 결정하지 않았다면 시스템 권한을 한 번 요청한다.
2. 허용되면 유효한 레이아웃의 `ARView`에서 world tracking을 한 번 시작한다.
3. LiDAR 메시 재구성 지원을 확인하고 수평·수직 평면, 분류된 바닥, 메시 업데이트를 관찰한다. 지원 여부 확인은 준비 완료와 구분한다.
4. **최소 한 개의 `ARMeshAnchor`와 최소 한 개의 분류된 수평 floor를 모두 관찰했을 때만** `realityReady`가 된다. 화면에는 “공간 형태”와 “바닥”의 준비 상태를 따로 보여준다.
5. 두 항목이 준비되면 스캔 완료 설명과 “숨바꼭질 시작” CTA가 나타난다. CTA 전에는 AR 탭을 무시한다. Chapter 3의 각 타깃은 선택 지점 근처의 floor를 다시 검증한다.
6. CTA를 누르면 같은 세션에서 Chapter 3의 `waitingForRealTarget`으로 전이한다.

권한 거부 화면은 “설정 열기”와 “차이 먼저 보기”를 제공한다. 설정을 실제로 연 경우에만 다음 active에서 권한을 한 번 다시 읽는다. 시스템 제한 상태는 `cameraRestricted`로 구분하고 변경할 수 없는 Settings 버튼을 보여 주지 않는다. LiDAR 미지원 화면은 지원 기기 조건과 이유를 설명하고 Chapter 4로 진행할 수 있게 한다.

active scanning 20초 동안 mesh와 floor가 모두 준비되지 않으면 `scanTimedOut`으로 전이한다. AR session 실패는 즉시 `sessionFailed`로 전이한다. tracking interruption은 기존 화면 위에 중단 안내를 표시하고 update 집계를 멈춘다. Chapter 3에서 interruption이 시작되면 현재 hide cycle을 정리하고, 10초 안에 종료될 때 `waitingForRealTarget`으로 복귀한다. Chapter 2에서는 같은 시간 안에 종료되면 `scanningReality`로 복귀한다. 10초를 넘기면 어느 챕터에서든 `sessionFailed`로 전이한다. `scanTimedOut`과 `sessionFailed`는 “다시 스캔”으로 새 AR generation을 시작하거나 “차이 먼저 보기”로 Chapter 4에 갈 수 있다.

### Chapter 3 — 진짜 숨바꼭질

1. “카메라에서 90cm 이상 떨어진 실제 물체의 옆면을 탭해줘.”라고 안내한다.
2. 세로 면, 거리, 동일 위치의 분류된 바닥과 floor footprint를 검증한다.
3. 유효한 타깃이면 18cm 돼지를 선택 면의 카메라 쪽 바닥에 표시하고 반대편 바닥으로 걷게 한다.
4. 이동 완료 뒤 실제 메시가 돼지의 실루엣을 충분히 가렸는지 여러 update에서 확인한다.
5. 가림이 확인된 뒤에만 “옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐.”로 바꾼다.
6. 사용자가 충분히 이동하거나 방향을 바꾸고 돼지 실루엣이 안정적으로 다시 보이면 놀란 모델·자막·돼지 확대·화면 확대를 한 번 실행한다.
7. 완료 패널에서 “다시 숨기기” 또는 “차이 돌아보기”를 선택한다.

RealityKit 돼지 에셋 로드가 실패하면 현재 cycle을 정리하고 `realityAssetFailed`를 표시한다. 이 화면은 “다시 불러오기”로 새 cycle의 타깃 선택에 돌아가거나 “차이 먼저 보기”로 Chapter 4에 갈 수 있다. 같은 오류가 반복되어도 사용자를 빈 AR 화면에 가두지 않는다.

### Chapter 4 — 차이 돌아보기

AR session을 정리한 뒤 SwiftUI 비교 화면을 표시한다. 비교의 첫 열은 API 이름이 아니라 책임을 묻는다.

| 비교 질문 | SceneKit 닫힌 세계 | RealityKit 현실 연결 |
| --- | --- | --- |
| 세계를 어디서 얻는가? | 개발자가 노드와 좌표로 구성한다 | AR session이 관찰한 공간을 함께 사용한다 |
| 위치의 기준은 무엇인가? | 장면 원점과 부모 노드 | 현실의 추적 좌표와 anchor |
| 앞뒤 관계를 무엇이 결정하는가? | 선언한 geometry와 렌더링 규칙 | 선언한 entity에 더해 인식된 실제 mesh가 가린다 |
| 책임을 어디에 두는가? | `SCNNode`에 geometry·physics·action을 모은다 | Entity에 필요한 Component와 System을 조합한다 |

`ComparisonEntryReason`이 `.completedHide`면 실제 숨기·재발견을 완료한 관찰을 요약한다. 우회해서 들어왔다면 완료한 것처럼 표시하지 않고 권한 제한, LiDAR 미지원, session 실패, scan timeout 또는 asset 실패 이유와 아직 남은 실기기 단계를 함께 보여 준다.

마지막에는 다음 세 CTA를 제공한다.

- `튜토리얼 완료`: `completed` 상태와 완료 요약을 표시한다.
- `Chapter 3 다시 하기`: 카메라 권한과 LiDAR 조건을 만족할 때 새 AR generation으로 Chapter 2 준비부터 다시 시작한다. 조건을 만족하지 않으면 비활성화 사유를 텍스트로 표시한다.
- `처음부터 다시 보기`: Chapter 1로 완전히 초기화한다.

## 6. 돼지 크기와 배치 정책

### 크기

- 모든 RealityKit 돼지 포즈의 목표 시각 높이는 **0.18m**다.
- 높이는 에셋 원본 scale이 아니라 축 보정과 바닥 정렬을 마친 `visualBounds`로 측정한다.
- idle, running, surprised 모델을 바꿔도 바깥 anchor의 기준 높이는 유지한다.
- 놀람 반응 1.5배는 0.18m 기준 scale에 곱하는 상대 배율이다. 애니메이션이 끝나면 해당 포즈의 0.18m 기준 scale로 돌아온다.
- bounds가 비어 있거나 유한하지 않으면 모델 설치를 실패로 종료하고 타깃 선택 안내로 복구한다. 임의의 거대 fallback scale은 사용하지 않는다.

### 타깃 거리와 위치

- 선택 표면은 AR 카메라에서 **최소 0.90m** 떨어져야 한다.
- 면 법선의 `abs(y)`는 0.35 이하여야 한다.
- 선택 때 사용한 분류된 `RealityFloorPlane`의 anchor identifier, transform, center, extent와 Y축 회전을 `RealityFloorRegion` snapshot으로 hide cycle에 보존한다. planner와 retry 정책은 높이 한 점만 받지 않고 이 region을 함께 받는다.
- 선택 surface hit의 XZ는 floor footprint에 0.02m tracking tolerance를 적용했을 때 포함되어야 한다.
- 카메라 쪽 시작점은 선택 면에서 카메라 방향으로 0.28m, 첫 목적지는 반대 방향으로 0.28m 떨어진 점이다. 두 점을 같은 floor region의 Y로 투영한다.
- 0.18m 돼지의 몸이 floor 가장자리에 걸리지 않도록 시작점·첫 목적지·모든 retry anchor의 XZ는 floor footprint에서 0.10m 안쪽에 있어야 한다. 둘 중 하나라도 첫 계획에서 벗어나면 `.findFloor`로 거부한다.
- 재시도는 카메라 반대 방향으로 0.18m씩 최대 두 번 수행한다. 후보가 보존한 region의 0.10m inset 밖이면 이동하지 않고 즉시 `.selectAnotherTarget`을 반환한다.

## 7. 다중 지점 가림과 재발견 정책

### 실루엣 샘플

고정된 model-local X축은 카메라 각도에 따라 화면의 좌우를 대표하지 못한다. 따라서 각 관찰에서 보정된 `visualBounds`의 여덟 모서리를 world 좌표로 변환하고, 현재 카메라의 right·up 방향에 대한 support point를 구한다.

| 샘플 | 계산 | 의도 |
| --- | --- | --- |
| 중심 | world bounds 중심 | 몸통 중심 |
| 위 | 중심에서 camera-up 최대 support point 방향의 80% | 화면 위쪽 노출 탐지 |
| 아래 | 중심에서 camera-up 최소 support point 방향의 80% | 화면 아래쪽 노출 탐지 |
| 왼쪽 | 중심에서 camera-right 최소 support point 방향의 80% | 현재 화면 왼쪽 노출 탐지 |
| 오른쪽 | 중심에서 camera-right 최대 support point 방향의 80% | 현재 화면 오른쪽 노출 탐지 |

카메라 right·up 벡터가 유효하지 않거나 bounds의 여덟 모서리를 만들 수 없으면 그 frame 전체를 `invalid`로 처리한다. 80% inset은 빈 bounding-box 모서리만 겨냥하는 것을 피하면서 포즈·돼지 회전·관찰 방향에 따라 실제 화면 실루엣을 따라가게 한다. 카메라를 돼지의 local X축 방향으로 옮긴 회귀 테스트에서도 좌우 ray가 겹치지 않아야 한다.

각 점은 `blocked`, `visible`, `invalid` 중 하나다.

- `blocked`: `pigDistance - meshDistance > 0.03m`다. 정확히 0.03m인 경계는 `visible`로 분류한다.
- `visible`: 카메라 앞·화면 안의 유효한 샘플이고, mesh hit가 없거나 `pigDistance - meshDistance <= 0.03m`다. 3cm 이내의 앞선 hit와 샘플 뒤 hit를 포함한다.
- `invalid`: camera transform 부재, 카메라 뒤, projection 실패, 화면 밖, 유한하지 않은 거리다.

같은 샘플러와 분류기를 초기 숨기 검증과 재발견에 모두 사용한다.

한 관찰은 같은 `ARFrame`에서 얻은 camera transform, 다섯 world sample, projection과 mesh hit 결과를 묶은 값이다. `ARFrame.timestamp`가 직전 값보다 큰 frame만 새 관찰로 세며, 하나의 frame을 여러 `SceneEvents.Update`가 읽어도 연속 수와 frame 예산에는 한 번만 반영한다.

### 숨기 완료

한 관찰에서 아래 조건을 모두 만족하면 `occluded`다.

- 다섯 샘플이 모두 유효하다.
- 중심이 `blocked`다.
- 다섯 점 중 최소 네 점이 `blocked`다.

`occluded`가 timestamp가 다른 **연속 두 관찰**에서 유지되어야 숨김 완료다. 이동 애니메이션 완료만으로 `hiddenInReality`가 되지 않는다.

각 이동 시도는 최대 60개의 서로 다른 AR frame 또는 1.5초의 monotonic-clock deadline 중 먼저 도달한 시점까지 관찰한다. 60번째 frame은 deadline 전이면 판정에 포함하고, 그 frame까지 연속 두 번을 얻지 못하면 즉시 실패한다. `now >= deadline`인 frame은 포함하지 않는다. deadline은 scene update가 멎어도 발화하는 취소 가능한 scheduler가 소유하며 retry·replay·화면 해제 때 취소한다.

시도 안에 연속 두 번을 얻지 못하면 0.18m 재이동을 시도한다. 최대 두 번의 재이동 뒤에도 실패하면 돼지 anchor와 cycle 상태를 제거하고 “물체를 더 스캔하거나 다른 옆면을 선택해줘.”와 함께 `waitingForRealTarget`으로 돌아간다.

### 물리적 재발견

숨김 완료의 두 번째 관찰에 사용한 camera pose를 cycle의 기준 pose로 고정한다. 이후의 blocked·invalid 관찰은 이 기준을 바꾸지 않는다.

다음 중 하나가 먼저 충족되어야 재발견 관찰을 셀 수 있다.

- 기준 위치에서 **0.15m 이상 이동**
- 기준 forward 방향에서 **15° 이상 회전**

두 임계값 중 하나를 한 번 넘으면 `hasMeaningfulViewpointChange`를 해당 hide cycle 동안 `true`로 latch한다. 이후 기준점 가까이 돌아오더라도 이 이동 이력은 지우지 않으며, 실제 노출의 연속 조건은 별도로 다시 만족해야 한다.

이동 조건 뒤 한 관찰에서 다음을 모두 만족하면 `revealed`다.

- 다섯 샘플이 모두 유효하다.
- 중심이 `visible`이다.
- 다섯 점 중 최소 세 점이 `visible`이다.

`revealed`가 timestamp가 다른 연속 두 관찰에서 유지될 때만 한 번 발견된다. 다섯 점 중 일부가 blocked여도 중심 visible·전체 visible 3/5 조건을 만족하면 후보를 유지한다. 어떤 invalid가 있거나, 중심이 visible이 아니거나, visible이 세 점보다 적어 **aggregate `revealed` 조건이 거짓인 관찰**이 들어오면 visible 연속 수만 0으로 초기화하고 기준 pose와 latch된 이동 이력은 보존한다.

## 8. 안내, 오류, 접근성

### 상태 안내

| 상태 | 기본 안내 |
| --- | --- |
| `scanningReality` | “주변과 바닥이 보이도록 천천히 비춰줘.” |
| `realityReady` | “현실 공간을 찾았어. 이제 진짜 숨바꼭질을 시작할 수 있어.” |
| `waitingForRealTarget` | “90cm 이상 떨어진 물체의 옆면을 탭해줘.” |
| `walkingBehindRealObject` | “피기가 숨으러 가고 있어.” |
| `verifyingOcclusion` | “정말 가려졌는지 확인하고 있어.” |
| `hiddenInReality` | “옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐.” |
| `discoveredInReality` | “찾았다! 다시 숨길까, 차이를 돌아볼까?” |
| `cameraDenied` | 카메라가 필요한 이유 + “설정 열기”·“차이 먼저 보기” |
| `cameraRestricted`·`lidarUnavailable` | 변경할 수 없는 기기 조건 + “차이 먼저 보기” |
| `sessionFailed`·`scanTimedOut` | 원인과 재스캔 방법 + “다시 스캔”·“차이 먼저 보기” |
| `realityAssetFailed` | 모델 로드 실패 + “다시 불러오기”·“차이 먼저 보기” |

거부 이유는 행동 가능한 문장으로 구분한다: 세로 옆면 선택, 더 먼 거리, 바닥 추가 스캔, 메시 추가 스캔, 다른 물체 선택, 에셋 재시도.

### 접근성

- 정보 패널은 AR 탭을 가로채지 않는다.
- 모든 CTA는 VoiceOver label·hint와 최소 44pt 터치 영역을 가진다.
- Dynamic Type에서 패널은 돼지를 가리는 고정 높이 대신 내용 크기와 safe area를 사용한다.
- 상태가 바뀔 때 핵심 안내를 접근성 announcement로 한 번 전달하되 매 frame 반복하지 않는다.
- Reduce Motion에서는 돼지·화면 확대를 생략하고 모델·텍스트 상태 변화만 사용한다.
- 텍스트는 배경과 4.5:1 이상의 대비를 유지하며 색만으로 상태를 구분하지 않는다.

## 9. 공개 DocC 단일 원본

### 원본 정책

저장소 루트의 `Tutorials/SceneKitToRealityKit.docc`를 유일한 공개·검증 원본으로 사용한다. 현재 앱 경로의 `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc` 복사본은 구현 단계에서 제거하고, 앱 target은 DocC를 runtime resource로 포함하지 않는다. 문서는 `scripts/build-docc-site.sh`의 독립 `docc convert` 경로로 빌드한다.

공개 사이트의 네 챕터를 이 원본으로 가져온 뒤, 앱의 실제 상태·수치·타입 이름과 맞게 고친다. 로컬 dirty `main`을 직접 수정하지 않고 현재 기능 worktree에서 `origin/main`의 공개 문서·배포 파이프라인을 통합한다.

### 정보 구조

```text
Tutorials/SceneKitToRealityKit.docc/
├── SceneKitToRealityKit.tutorial
├── Tutorials/
│   ├── 01-ClosedWorld.tutorial
│   ├── 02-OpeningTheDoor.tutorial
│   ├── 03-RealHideAndSeek.tutorial
│   ├── 04-Comparison.tutorial
│   └── Resources/*.swift
├── Articles/
│   ├── SceneGraphDeepDive.md
│   ├── RealityKitECS.md
│   ├── DeviceCameraDiagnostics.md
│   └── MigrationWorksheet.md
└── Resources/
    ├── chapter-01-closed-world.*
    ├── chapter-02-opening-reality.*
    ├── chapter-03-real-hide-and-seek.*
    ├── chapter-04-comparison.*
    └── ...
```

### 콘텐츠와 이미지

- 각 챕터는 “왜 필요한가 → 장면 → 만들기 → 관찰 → 해석 → 다음 장”의 같은 리듬을 사용한다.
- 모든 `@Step`은 실제 변경 또는 실행 가능한 `@Code`, 기대 결과, 실패 징후를 연결한다.
- 같은 chapter icon을 반복하지 않는다. 네 장의 역할이 다른 고유 이미지를 제공하고 alt text도 각각의 의미를 설명한다.
- 구조를 설명하는 생성·제작 이미지는 “구조 도식”으로 명시한다. 실제 동작 증거처럼 표현하지 않는다.
- Chapter 3의 가려짐 전·후 이미지는 같은 기기·물체·위치에서 실제로 촬영한 두 장을 사용한다. 실기기 검증 전에는 증거 이미지를 꾸며 내지 않고 `실기기 대기`로 남긴다.
- Chapter 제목에는 안정적인 영문 번호 접두사를 포함해 하위 URL이 하이픈만으로 생성되지 않게 한다.
- 내부 `doc:` 링크, 순차 탐색, Resources의 “더 보기” 링크가 모두 실제 페이지로 해석되어야 한다.

### 코드 동기화

- 스니펫은 production core 정책과 같은 상수·조건을 설명한다.
- 복사한 축약 코드에는 대응 production 파일과 계약 테스트를 명시한다.
- 모든 Swift 스니펫은 iOS 17 Simulator SDK를 대상으로 독립 type-check한다.
- 문서가 “0.40초 예약 취소”, “90cm”, “5점 가림”, “15cm/15° 이동”, “두 관찰”을 말하면 실제 코드와 테스트가 같은 값을 가져야 한다.

### 접근성과 렌더링

- 생성된 한국어 페이지의 문서 언어는 `ko-KR`이어야 한다.
- `{count}`, `{number}` 같은 미해결 localization placeholder가 화면이나 접근성 이름에 남지 않아야 한다.
- 링크는 색뿐 아니라 밑줄·굵기 등 추가 단서가 있고 일반 텍스트 대비 4.5:1을 만족한다.
- theme asset과 `theme-settings.json` 요청은 404가 없어야 하며, 브라우저 console의 tutorial navigation 오류가 없어야 한다.
- 데스크톱과 390×844 모바일 viewport에서 챕터 카드, 코드, 이전/다음 탐색, CTA를 직접 확인한다.

## 10. 테스트와 검증 전략

### 결정론적 정책 XCTest

아래 정책 타입은 ARKit·RealityKit 호출 없이 테스트하지만, 현재 test bundle 자체는 iOS Simulator에 호스팅된다. 별도 Swift Package 추출은 이번 사용자 경험 완성의 필수 조건으로 두지 않는다.

- `EscapeExperienceMachine`: 1→2→3→4→완료, 표의 모든 전이, 중복·순서 위반, 권한·LiDAR·오류 우회, replay
- `PigScalePolicy`: 0.18m 정규화, 잘못된 bounds, 세 포즈의 크기 유지, 상대 surprise scale 복귀
- `RealityHidePlanner`: 0.90m 경계, 세로 면, floor footprint, 첫 목적지, 재시도 경계
- `PigOcclusionSampler`: 세 포즈·돼지 회전·카메라 방향별 view-space 다섯 world sample
- `OcclusionObservationPolicy`: 4/5+중심, invalid, strict 0.03m 여유, 서로 다른 AR frame 두 관찰, 60 frame/1.5초 종료
- `RealityRevealMonitor`: 이동·회전 경계와 latch, 3/5+중심 aggregate reset, 서로 다른 AR frame, 한 번 발견
- `ComparisonModel`: 네 비교 축의 순서와 완료 이벤트

### Coordinator·통합 XCTest

- mesh만 또는 floor만 관찰했을 때는 Chapter 2 준비가 끝나지 않고, 둘을 모두 관찰한 뒤 한 번만 `realityReady`가 됨
- Chapter 2 CTA 전 AR 탭 무시, CTA 뒤 한 번 수락
- 같은 `ARView`·session이 Chapter 2→3 전환에서 유지됨
- 시작점·첫 목적지·retry 후보가 같은 floor region의 inset 안에 있을 때만 cycle이 진행됨
- 걷기 완료만으로 찾기 안내가 나타나지 않음
- 가림 확인, 제한된 재이동, 실패 후 anchor 제거·재선택
- 같은 AR frame을 중복 update에서 읽어도 연속 관찰로 세지 않고 deadline callback이 update 정지 상태에서도 cycle을 종료함
- 다시 숨기기에서 subscription·task·anchor·reaction 상태가 cycle 단위로 초기화되고 다음 cycle의 새 anchor가 정확히 한 번 attach됨
- permission restricted, session failure, scan timeout, interruption, asset failure의 retry·Chapter 4 우회와 `ComparisonEntryReason` 보존
- Chapter 4 전환과 전체 replay에서 session·callback이 정리되고 stale callback이 무시됨
- 정보 overlay가 hit testing을 가로채지 않고 CTA만 상호작용함

### 빌드·Simulator

- `tuist generate --no-open`
- 현재 설정된 Swift language mode에서 전체 XCTest의 실제 실행 수와 `TEST SUCCEEDED` 확인
- Debug와 Release generic iOS Simulator build
- Chapter별 화면과 CTA를 주입 가능한 상태로 확인하는 UI smoke test
- Swift 6 strict concurrency build는 별도 준비 게이트로 실행한다. 현재 프로젝트를 Swift 6으로 완료했다고 주장하지 않으며, 알려진 `C3AutoDiscoveryCancellable` 격리 오류를 해결한 뒤에만 지원 상태를 바꾼다.

### DocC·공개 사이트

- 경고 없는 `docc convert`
- 네 tutorial과 네 article의 예상 output JSON·HTML 존재 확인
- 모든 Swift snippet type-check
- 미해결 `doc:` 링크, 404 asset, placeholder 문자열, 잘못된 language 검사
- 로컬 정적 서버에서 desktop/mobile link crawl과 접근성 audit
- Pages 배포 뒤 기준 URL과 네 챕터 순차 탐색 재확인

### LiDAR 실기기

- 권한 허용·거부·Settings 복구
- 0.18m 돼지가 0.90m 이상 타깃에서 화면을 과도하게 가리지 않음
- 시작점→물체 반대편 걷기, 5점 가림 확인 뒤 안내 전환
- 가장자리 한 점 노출, 좁은 물체, 메시 hole에서 조기 숨김 완료하지 않음
- 0.15m/15° 이전에는 발견하지 않고 이후 3/5+중심 두 관찰에서 한 번 발견
- 화면 밖·카메라 뒤 관찰 뒤 두 관찰을 새로 요구함
- 다시 숨기기 두 번과 Chapter 4 전환에서 이전 anchor·callback이 남지 않음
- 같은 조건의 Chapter 3 가려짐 전·후 스크린샷 확보

## 11. 통합과 배포

1. 이 명세를 검토·승인한 뒤 구현 계획을 작성한다.
2. 현재 기능 worktree에서 테스트 우선으로 앱 정책과 챕터 흐름을 구현한다.
3. `origin/main`의 루트 DocC와 Pages 파이프라인을 기능 브랜치에 통합하고 `docs/PROJECT_CONTEXT.md` 충돌은 이 명세 기준으로 해결한다.
4. 앱·문서·검증·인수인계를 같은 작업 단위로 커밋한다. `.claude/`, 생성 Xcode 프로젝트, DerivedData는 포함하지 않는다.
5. 자동 검증과 가능한 실기기 검증을 마친 뒤 변경을 원격 기본 브랜치에 통합한다.
6. Pages 배포가 끝나면 공개 URL을 desktop/mobile로 재검증한다.

## 12. 최종 수용 기준

- [ ] 앱에서 Chapter 1→2→3→4→완료가 중단 없이 이어진다.
- [ ] mesh와 분류된 floor를 모두 관찰한 뒤에만 Chapter 2 준비가 끝나고, Chapter 2→3에서 AR session이 재시작되지 않으며 그전 타깃 탭은 무시된다.
- [ ] RealityKit 돼지의 기준 높이가 0.18m이고 0.90m 미만 선택을 거부한다.
- [ ] 시작점·첫 목적지·모든 retry 후보가 보존한 floor region의 안전 inset 안에 있다.
- [ ] 숨김 완료는 view-space 5점 중 중심 포함 4점, 서로 다른 AR frame의 연속 두 유효 관찰 뒤에만 발생한다.
- [ ] 재발견은 0.15m 또는 15° 이력을 latch한 뒤 중심 포함 3점, 서로 다른 AR frame의 연속 두 유효 관찰에서 한 번만 발생한다.
- [ ] 실패한 가림은 제한된 재시도 뒤 돼지를 제거하고 타깃 선택으로 복구한다.
- [ ] 찾기 정보 패널이 AR 탭을 막지 않고 이동·회전 방법을 구체적으로 안내한다.
- [ ] 발견 후 다시 숨기기와 Chapter 4 진행이 모두 작동하고 이전 callback이 남지 않는다.
- [ ] 권한 거부·제한, LiDAR 미지원, session 실패, scan timeout, tracking interruption과 asset 실패가 막다른 화면 없이 정확한 retry 또는 Chapter 4로 이어진다.
- [ ] 전체 XCTest·Debug/Release build·DocC·snippet·브라우저 검증이 실제 실행 결과와 함께 기록된다.
- [ ] 공개 DocC의 네 챕터가 앱과 같은 계약을 설명하고 고유 이미지·정상 링크·한국어 접근성을 갖는다.
- [ ] LiDAR 실기기에서 실제 가림·물리적 재발견·replay를 관찰하고 Chapter 3 전·후 증거 이미지를 게시한다.

## 13. 참고 기준

- `docs/superpowers/specs/2026-08-10-ch1-reality-escape-design.md`
- `docs/superpowers/specs/2026-08-18-ch1-auto-advance-after-tree-hide-design.md`
- `docs/superpowers/specs/2026-08-18-ch1-verified-reality-hide-design.md`
- `docs/WORK_LOG.md`
- Apple, “Bringing your SceneKit projects to RealityKit”
- Apple, “Creating a game with scene understanding”
