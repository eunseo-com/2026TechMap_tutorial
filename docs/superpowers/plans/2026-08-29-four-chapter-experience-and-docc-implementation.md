# SceneKit에서 RealityKit으로 — 4개 챕터·DocC 완성 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to execute this plan task-by-task. Each behavior change follows `superpowers:test-driven-development`; completion claims follow `superpowers:verification-before-completion`. iOS 빌드·실행·런타임 UI 확인은 `Build iOS Apps`의 `ios-debugger-agent` 절차를 함께 따른다.

**Goal:** 현재 C3 SceneKit→RealityKit 체험을 Chapter 1–4의 끊기지 않는 학습 흐름으로 완성하고, 18cm 돼지의 다중 지점 실제 가림·이동 재발견·replay를 안정화한 뒤 같은 계약의 공개 DocC를 기준 URL에 배포한다.

**Architecture:** 기존 `EscapeExperienceMachine`을 유일한 흐름 상태 기계로 확장하고 `TutorialChapter`는 상태에서 파생한다. Chapter 2와 3은 하나의 `RealityHideARView`·`ARSession`을 유지한다. RealityKit 프레임워크 호출은 coordinator와 observation provider에 한정하고, readiness·floor region·scale·view-space sample·가림·재발견·비교 모델은 결정론적 타입으로 분리한다. 각 hide cycle은 자체 anchor/controller/generation을 가진다. 공개 문서는 저장소 루트 DocC catalog 하나만 사용한다.

**Tech Stack:** Swift 5 language mode(현재 프로젝트 설정), SwiftUI, SceneKit, SpriteKit, ARKit, RealityKit, AVFoundation, XCTest/XCUITest, Tuist 4, DocC, iOS 17.0, GitHub Pages. Swift 6 strict concurrency는 별도 준비 게이트이며 현재 지원 완료로 주장하지 않는다.

## 시작 기준선

- 작업 브랜치: `ch1-reality-escape`
- 작업 트리: `/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.worktrees/ch1-reality-escape`
- 승인 설계: `docs/superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md`
- 도구 기준선: Xcode 26.6, Swift 6.3.3 toolchain, Tuist 4.204.0, 프로젝트 `SWIFT_VERSION=5`
- 2026-08-29 기준 전체 XCTest: iPhone 17 Pro iOS 26.5 Simulator, 112/112·0 failures, `** TEST SUCCEEDED **`
- 기준 결과 bundle: `/tmp/piggyescape-four-chapter-baseline/Logs/Test/Test-PiggyEscape-2026.08.29_23-31-56-+0900.xcresult`
- 현재 Debug·Release generic Simulator build는 통과하며, Swift 6 strict build는 `C3ClosedWorldSceneView.swift`의 non-Sendable cancellation handle로 실패한다.
- paired iPhone 16 Pro는 현재 `ddiServicesAvailable:false`, `tunnelState:unavailable`이고 Xcode destination에 없어 실기기 gate는 연결·잠금 해제·신뢰 복구가 필요하다.
- `origin/main`은 공개 4장 DocC·Pages pipeline을 가지며 앱 브랜치와 9/52로 갈라져 있다. 사전 `merge-tree`에서 예상된 내용 충돌은 `docs/PROJECT_CONTEXT.md` 한 파일이다.
- 미추적 `.claude/`는 사용자 소유다. 이동·삭제·스테이징하지 않는다.

## 공통 실행 규칙

- 소스 변경 전 실패 테스트를 추가하고, 의도한 assertion 또는 타입 부재로 RED가 난 것을 확인한다.
- 한 태스크는 한 계약만 GREEN으로 만든다. 무관한 리팩터링은 섞지 않는다.
- 매 RED/GREEN 명령은 실제 실행 수, failures, 최종 `TEST SUCCEEDED`를 확인한다. `tuist test` exit code만 근거로 쓰지 않는다.
- 실패·환경 제약·예상 밖 동작은 다음 재시도 전에 `docs/LEARNING_LOG.md`에 기록한다.
- 의미 있는 태스크마다 `docs/WORK_LOG.md`의 현재 인수인계와 작업 이력을 같은 커밋에 갱신한다.
- 생성 `.xcodeproj`, DerivedData, `.claude/`, 로컬 site build는 추적하지 않는다.
- 실제 LiDAR 가림과 화면 체감은 Simulator로 완료 처리하지 않는다.
- Simulator 런타임 검증 전 `Build iOS Apps` 세션 기본값을 조회하고, 부팅된 iPhone Simulator를 확인한 뒤 프로젝트·scheme·simulator 기본값을 지정한다. 부팅된 Simulator가 없으면 임의로 부팅하지 않고 사용자에게 부팅을 요청하되, 소스·결정론적 테스트 작업은 계속한다.
- 커밋·PR에는 작업자·도구·모델·AI 생성 표기와 `Co-Authored-By`를 넣지 않는다.

테스트 destination은 아래 값을 기본으로 사용한다.

```bash
SIM_DEST='platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro'
```

---

### Task 1: 공개 DocC 기준선을 기능 브랜치에 통합한다

**Files:**
- Merge: `origin/main`
- Resolve: `docs/PROJECT_CONTEXT.md`
- Add from `origin/main`: `Tutorials/SceneKitToRealityKit.docc/**`
- Add from `origin/main`: `scripts/build-docc-site.sh`
- Add from `origin/main`: `.github/workflows/deploy-docc.yml`
- Add from `origin/main`: `Web/index.html`
- Modify: `docs/WORK_LOG.md`

**Contract:** 앱 구현 커밋과 공개 Pages 문서 이력을 한 브랜치에서 재현할 수 있어야 한다. 로컬 dirty `main`은 건드리지 않는다.

- [ ] `git status --short`가 `.claude/` 외에 깨끗하고 `git fetch --prune origin`이 최신인지 확인한다.
- [ ] `git merge --no-ff --no-commit origin/main`을 실행한다. `docs/PROJECT_CONTEXT.md` 충돌은 승인된 4장 범위·현재 검증 기준을 보존하고, 공개 DocC 경로 설명만 통합한다.
- [ ] `git diff --check`, `git status --short`, `git log --graph -5 --oneline`으로 merge 결과를 확인한다.
- [ ] 공개 기준 catalog를 임시 경로에 빌드한다.

```bash
bash scripts/build-docc-site.sh /tmp/piggyescape-public-base.doccarchive
test -f /tmp/piggyescape-public-base.doccarchive/data/tutorials/scenekittorealitykit.json
```

- [ ] 전체 앱 XCTest 112개가 merge 뒤에도 통과하는지 확인한다.
- [ ] `docs/WORK_LOG.md`에 merge와 기준선 결과를 기록하고 merge commit을 완료한다.

---

### Task 2: 단일 4개 챕터 상태 기계와 파생 챕터를 만든다

**Files:**
- Modify: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/TutorialChapter.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceLifetime.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/TutorialChapterTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/EscapeExperienceLifetimeTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- `ComparisonEntryReason`
- 승인 설계의 상태·이벤트를 가진 `EscapeExperienceState`, `EscapeExperienceEvent`
- 유일한 `EscapeExperienceMachine.send(_:) -> Bool`
- `EscapeExperienceState.chapter -> TutorialChapter`
- `RealityCallbackToken(experienceGeneration:realityGeneration:hideCycleGeneration:)`과 stale callback gate

- [ ] 다음 RED 테스트를 먼저 추가한다.
  - `realityReady + startRealHide → waitingForRealTarget`
  - movement→verification→retry/verified/exhausted
  - discovery→replay 또는 comparison
  - denied/restricted/lidar/session/timeout/asset 오류의 retry·skip
  - comparison reason이 completed에 보존됨
  - 모든 상태의 reset과 잘못된 순서·중복 이벤트 거부
  - 각 상태가 정확한 Chapter 1–4로 파생됨
  - reset, 새 AR retry, 새 hide cycle이 필요한 generation만 증가시키고 이전 token을 거부함
- [ ] focused test가 새 case·event 부재로 컴파일 실패하는 RED를 확인한다.

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination "$SIM_DEST" \
  -only-testing:PiggyEscapeTests/EscapeExperienceStateTests \
  -only-testing:PiggyEscapeTests/TutorialChapterTests \
  -only-testing:PiggyEscapeTests/EscapeExperienceLifetimeTests test
```

- [ ] 기존 상태 기계를 확장한다. 별도의 `ChapterFlowMachine`이나 독립 mutable chapter 값은 만들지 않는다.
- [ ] `cameraDenied`의 Settings 복귀 허용, `cameraRestricted`의 Settings 금지, `ComparisonEntryReason` 보존을 구현한다.
- [ ] generation 수명은 상태 enum에 섞지 않고 `EscapeExperienceLifetime`이 소유하며, 모든 AR 외부 callback이 token 일치를 통과해야만 이벤트를 보낼 수 있게 한다.
- [ ] focused tests GREEN, 이어 기존 `EscapeRootCoordinatorTests`까지 실행한다.
- [ ] 작업 로그를 갱신하고 아래 파일만 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/TutorialChapter.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceLifetime.swift \
  PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift \
  PiggyEscape/PiggyEscapeTests/TutorialChapterTests.swift \
  PiggyEscape/PiggyEscapeTests/EscapeExperienceLifetimeTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Add four-chapter experience flow"
```

---

### Task 3: Reality 준비 상태와 Chapter 3 이전 탭 잠금을 분리한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityEnvironmentReadiness.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityDeadlineScheduler.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityEnvironmentReadinessTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityDeadlineSchedulerTests.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- `RealityEnvironmentReadiness.observeMesh()`, `.observeClassifiedFloor()`, `.isReady`
- `RealityHideInteractionMode`: `preparing`, `selectingTarget`, `moving`, `searching`, `revealed`
- readiness callback은 `hasMesh && hasClassifiedFloor` 최초 성립 때 한 번만 전달
- 취소 가능한 20초 scan, 10초 interruption, 1.5초 occlusion deadline의 공용 scheduler 경계

- [ ] mesh만·floor만으로는 ready가 아니고, 순서와 무관하게 둘 다 관찰한 뒤 한 번만 ready가 되는 RED 테스트를 추가한다.
- [ ] `.preparing`의 tap은 hit test와 내부 status를 바꾸지 않고, `.selectingTarget`에서만 한 번 수락하는 coordinator RED 테스트를 추가한다.
- [ ] controlled scheduler로 세 deadline 상수, 취소, 한 번 발화와 owner 해제 뒤 무발화를 검증한다.
- [ ] 기존 `hasObservedMesh || hasObservedFloor` private 정책 때문에 RED가 나는지 확인한다.
- [ ] 순수 readiness 타입을 구현하고 AR anchor update가 두 신호를 전달하게 한다.
- [ ] production deadline은 취소 가능한 `Task`가 구현하고 테스트는 wall-clock sleep 없이 제어한다.
- [ ] representable update가 interaction mode를 coordinator에 동기화하고 tap handler 시작부에서 mode를 검사하게 한다.
- [ ] session start gate와 카메라 검은 화면 방지 회귀 테스트를 함께 GREEN으로 만든다.
- [ ] focused tests와 전체 112+ suite를 실행하고 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityEnvironmentReadiness.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityDeadlineScheduler.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift \
  PiggyEscape/PiggyEscapeTests/RealityEnvironmentReadinessTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityDeadlineSchedulerTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Gate real hiding on complete room readiness"
```

---

### Task 4: 18cm 크기와 안전한 floor region 배치를 구현한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/PigScalePolicy.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift`
- Create: `PiggyEscape/PiggyEscapeTests/PigScalePolicyTests.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- `PigScalePolicy.targetHeight = 0.18`
- invalid/degenerate bounds를 실패로 끝내는 scale 계산
- `RealityFloorRegion` snapshot: anchor id, transform, center, extent, Y rotation
- `RealityHidePlan`: start, destination, retreat direction, floor region
- `RealityHideAttempt`가 같은 region을 보존

- [ ] target height가 0.18m이고 0·NaN·무한 bounds를 거부하는 RED 테스트를 추가한다.
- [ ] idle/running/surprised 모델 교체와 surprise 1.5→1.0 뒤에도 기준 높이가 보존되는 테스트를 추가한다.
- [ ] 0.90m 미만 거부·정확히 0.90m 수용 테스트를 추가한다.
- [ ] surface hit는 2cm tolerance, start/destination/retry는 동일 footprint 10cm inset을 요구하는 RED 테스트를 추가한다.
- [ ] 첫 목적지가 밖이면 `.findFloor`, retry가 밖이면 `.selectAnotherTarget`인지 확인한다.
- [ ] `RealityPigVisualController.install`이 invalid bounds를 성공 처리하는 현재 동작과 planner 타입 차이로 RED를 확인한다.
- [ ] scale policy와 floor-aware plan을 최소 구현하고 coordinator 호출부를 새 plan 타입에 맞춘다.
- [ ] focused visual/planner/coordinator tests GREEN 후 전체 suite를 실행하고 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/PigScalePolicy.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift \
  PiggyEscape/PiggyEscapeTests/PigScalePolicyTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Use physical pig scale and safe floor regions"
```

---

### Task 5: view-space 5점 가림·재발견 정책을 순수 로직으로 만든다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionPolicy.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityOcclusionPolicyTests.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- `PigOcclusionSampleID`: center, top, bottom, left, right
- `PigOcclusionSampler.samples(boundsCorners:cameraRight:cameraUp:)`
- `OcclusionSampleState`: blocked, visible, invalid
- `RealityOcclusionObservation(frameTimestamp:samples:cameraPose:)`
- `StableHideMonitor`와 확장된 `RealityRevealMonitor`

- [ ] 회전한 돼지와 서로 다른 camera right/up에서도 좌·우 ray가 분리되고 bounds support 80%를 쓰는 RED 테스트를 추가한다.
- [ ] `pigDistance - meshDistance > 0.03`만 blocked, 정확히 3cm와 더 가까운 차이는 visible인 exhaustive 분류 테스트를 추가한다.
- [ ] hide는 all-valid + center blocked + 4/5 blocked, 서로 다른 timestamp 두 frame을 요구하는 테스트를 추가한다.
- [ ] 같은 timestamp 중복, invalid, 3/5 blocked, center visible이 streak를 reset하는지 확인한다.
- [ ] 60번째 고유 frame 포함, 61번째 미처리와 deadline 판정의 순수 정책 테스트를 추가한다.
- [ ] reveal은 movement 0.15m 또는 rotation 15°를 latch하고 all-valid + center visible + 3/5 visible의 서로 다른 두 frame 뒤 한 번만 발생하는지 테스트한다.
- [ ] 2 blocked가 있어도 3/5 aggregate candidate를 유지하고 invalid/center blocked/<3 visible만 reset하는지 테스트한다.
- [ ] 기존 중심 ray 정책이 RED인 것을 확인하고 새 순수 타입을 구현한다.
- [ ] focused policy/planner tests GREEN 후 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionPolicy.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift \
  PiggyEscape/PiggyEscapeTests/RealityOcclusionPolicyTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Add stable silhouette occlusion policy"
```

---

### Task 6: AR coordinator를 cycle별 5점 관찰과 bounded retry에 연결한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionObservationProvider.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- production provider가 같은 `ARFrame`의 camera transform과 5개 project/hit 결과를 한 observation으로 생성
- hide cycle마다 새 `pigAnchor`, controller, attachment gate, cycle generation
- `restartHideCycle()`과 완전한 cycle teardown
- 60 unique frame 또는 1.5초 cancellable deadline

- [ ] 한 center ray만 blocked이고 나머지가 visible이면 hide 완료 callback이 나가지 않는 RED 테스트를 추가한다.
- [ ] 4/5+center의 서로 다른 두 frame 뒤에만 `onPigReachedTarget`이 한 번 나가는 테스트를 추가한다.
- [ ] 같은 ARFrame timestamp의 여러 scene update가 한 번만 집계되는지 확인한다.
- [ ] deadline이 update 없이 발화하고 retry task·deadline이 replay/dismantle에서 취소되는지 controlled scheduler로 테스트한다.
- [ ] retry가 같은 floor region 안에서만 이동하고 exhausted 시 anchor 제거·waiting 복구를 확인한다.
- [ ] 다시 숨기기 두 번에서 cycle마다 새 anchor가 정확히 한 번 attach되고 이전 asset callback이 무시되는지 확인한다.
- [ ] reveal이 같은 5점 observation과 movement latch를 사용하며 한 번만 callback하는지 확인한다.
- [ ] production observation provider와 cycle context를 구현한다. 실제 AR camera transform은 변경하지 않는다.
- [ ] focused coordinator/policy tests와 전체 suite를 실행하고 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityOcclusionObservationProvider.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift \
  PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Verify real hiding across the pig silhouette"
```

---

### Task 7: Chapter 1–3 라우팅·안내·오류·replay를 연결한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/ChapterProgressView.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/ChapterProgressTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- 상태에서 파생한 1/4…4/4 진행 표시
- Chapter 2·3의 동일 structural path `RealityHideARView`
- CTA 전 preparing, CTA 뒤 selectingTarget
- 정보 overlay는 hit testing false, CTA safe-area 영역만 true
- scan 20초, interruption 10초의 주입 가능한 scheduler

- [ ] Chapter 1 발견·0.70초 fade 뒤 Chapter 2, ready CTA 뒤 Chapter 3 전이 RED 테스트를 추가한다.
- [ ] Chapter 2→3에서 AR view identity/session start count가 1인 테스트를 추가한다.
- [ ] 상태별 interaction mode, 새로운 정확한 안내 문자열, 44pt CTA와 overlay hit-test 계약을 테스트한다.
- [ ] denied만 Settings를 보이고 restricted/lidar는 보이지 않는지, 모든 오류가 retry 또는 skip-to-comparison을 제공하는지 테스트한다.
- [ ] scan timeout, session failure, interruption 복구와 stale experience/cycle callback 무시를 controlled scheduler로 테스트한다.
- [ ] 발견 후 `다시 숨기기`가 같은 AR session에서 waiting target으로 돌아가고 `차이 돌아보기`가 comparison으로 가는지 테스트한다.
- [ ] 루트의 기존 `showsClosedWorldView = !showsRealityView` 이분법을 chapter switch로 교체한다.
- [ ] Reality view는 Chapter 2–3 동안 같은 코드 위치와 identity를 유지한다. state마다 `.id`를 바꾸지 않는다.
- [ ] 기존 root coordinator를 별도 파일로 옮기고 `EscapeExperienceLifetime` token을 모든 AR event mapping에서 검사한다.
- [ ] focused root/state/coordinator tests와 전체 suite를 실행하고 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Escape/ChapterProgressView.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift \
  PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift \
  PiggyEscape/PiggyEscapeTests/ChapterProgressTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Connect the first three tutorial chapters"
```

---

### Task 8: Chapter 4 비교·완료·재시도 화면을 구현한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/ComparisonModel.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/ComparisonView.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/TutorialCompletionView.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift`
- Create: `PiggyEscape/PiggyEscapeTests/ComparisonModelTests.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- 순서가 고정된 world, coordinates, visibility, responsibilities 네 비교 축
- `ComparisonEntryReason`에 따른 완료/skip 요약
- 완료, Chapter 3 다시 하기, 처음부터 다시 보기 CTA

- [ ] 네 비교 축의 순서·SceneKit/RealityKit 설명과 reason별 요약 RED 테스트를 추가한다.
- [ ] completedHide가 아닌 reason을 실제 숨기 완료처럼 표시하지 않는 테스트를 추가한다.
- [ ] Chapter 4 진입 때 AR teardown이 한 번 실행되고 stale callback이 무시되는지 테스트한다.
- [ ] Chapter 3 재시도는 권한·LiDAR 지원 때 새 AR generation의 scanning으로, 전체 reset은 Chapter 1로 가는지 테스트한다.
- [ ] SwiftUI 비교·완료 화면을 구현하고 Dynamic Type, VoiceOver label/hint, 4.5:1 대비, Reduce Motion 경계를 적용한다.
- [ ] focused comparison/root tests와 전체 suite를 실행하고 커밋한다.

```bash
git add PiggyEscape/PiggyEscape/Sources/Escape/ComparisonModel.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/ComparisonView.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/TutorialCompletionView.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift \
  PiggyEscape/PiggyEscapeTests/ComparisonModelTests.swift \
  PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift \
  docs/WORK_LOG.md docs/LEARNING_LOG.md
git commit -m "Add comparison and completion chapter"
```

---

### Task 9: UI smoke test와 Swift 6 준비 경계를 추가한다

**Files:**
- Modify: `PiggyEscape/Project.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/UITestLaunchConfiguration.swift`
- Create: `PiggyEscape/PiggyEscapeUITests/ChapterFlowUITests.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/C3ClosedWorldSceneViewOwnershipTests.swift`
- Modify: `docs/WORK_LOG.md`

**Contract:** production Release에는 진단 경로가 없고, Debug UI test launch에서만 결정론적 chapter fixtures를 표시한다. 현재 Swift mode는 유지하되 strict concurrency diagnostic이 통과한다.

- [ ] Tuist에 `PiggyEscapeUITests` target을 추가하고 test host dependency를 연결한다.
- [ ] `#if DEBUG` launch argument로 Chapter 1–4와 error fixtures를 여는 최소 seam을 추가한다. 일반 launch에는 영향을 주지 않는다.
- [ ] 진행 표시, Chapter 2 CTA, passive 안내와 interactive CTA, Chapter 3 replay, Chapter 4 완료/reset의 XCUITest를 작성해 RED를 확인한다.
- [ ] 큰 Dynamic Type과 Reduce Motion launch 환경에서 핵심 CTA가 존재하고 tappable인지 검사한다.
- [ ] `C3AutoDiscoveryCancellable`의 Sendable/actor 수명을 실제 ownership test로 먼저 고정하고 Swift 6 strict build 오류를 수정한다.
- [ ] UI tests, 전체 unit tests, 현재 mode build, strict concurrency build를 실행한다.
- [ ] `Build iOS Apps`로 앱을 build/install/launch하고 Chapter 1–4 Debug fixture를 각각 연다. 화면 전이마다 semantic UI snapshot을 새로 받아 챕터 제목·핵심 CTA·hit target을 확인하고, 대표 화면 스크린샷을 검증 증거로 남긴다.
- [ ] 런타임 로그에 launch crash, assertion, unhandled session error가 없는지 확인한다. 이 Simulator 점검은 AR 가림의 실기기 수용 검증을 대체하지 않는다.

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination "$SIM_DEST" \
  -only-testing:PiggyEscapeUITests/ChapterFlowUITests test

xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/piggyescape-swift6 \
  CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete build
```

- [ ] 실행 결과를 기록하고 source·tests·manifest만 커밋한다.

---

### Task 10: 루트 DocC를 유일한 원본으로 만들고 앱 계약과 동기화한다

**Files:**
- Modify: `PiggyEscape/Project.swift`
- Delete: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/**`
- Modify: `Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Tutorials/01-ClosedWorld.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Tutorials/02-OpeningTheDoor.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Tutorials/03-RealHideAndSeek.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Tutorials/04-Comparison.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Articles/*.md`
- Modify/Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/*.swift`
- Create: `scripts/verify-docc-content.sh`
- Modify: `docs/WORK_LOG.md`

**Contract:** 하나의 root catalog만 빌드·배포되며 네 장이 production 상태·수치·오류·replay와 의미적으로 같다.

- [ ] `Project.swift`의 app sources에서 `PiggyEscape/Tutorials/**`를 제거하는 manifest test 또는 generated source-list 확인을 먼저 추가한다.
- [ ] content verifier가 4 tutorial, 4 article, 기대 snippet inventory, 0.18m/0.90m/5점/0.15m·15°/2 frame/replay 문구를 요구하도록 작성하고 현재 불일치 RED를 확인한다.
- [ ] 앱 내부 catalog를 정확한 tracked path만 제거한다. 루트 catalog는 보존한다.
- [ ] Chapter 1=C3 닫힌 세계, Chapter 2=권한+mesh/floor 준비, Chapter 3=실제 숨기, Chapter 4=체험 기반 비교로 전면 동기화한다.
- [ ] 각 step을 실행 가능한 `@Code`·실행 확인·실패 복구·해석과 연결한다.
- [ ] unresolved `doc:SceneGraphDeepDive`, Chapter 4 “Section 2”, 순차 링크와 article link를 고친다.
- [ ] 모든 snippet을 iOS 17 Simulator SDK로 독립 type-check한다.
- [ ] `tuist generate --no-open`, 앱 build, content verifier, DocC convert를 GREEN으로 만든다.
- [ ] 문서·snippet·manifest·work log를 커밋한다.

---

### Task 11: 네 챕터의 고유 시각 자료와 실제 증거 경계를 만든다

**Files:**
- Create/Modify: `Tutorials/SceneKitToRealityKit.docc/Resources/chapter-01-closed-world.*`
- Create/Modify: `Tutorials/SceneKitToRealityKit.docc/Resources/chapter-02-opening-reality.*`
- Create/Modify: `Tutorials/SceneKitToRealityKit.docc/Resources/chapter-03-real-hide-and-seek.*`
- Create/Modify: `Tutorials/SceneKitToRealityKit.docc/Resources/chapter-04-comparison.*`
- Add after device capture: Chapter 3 before/after evidence images
- Modify: four tutorial files
- Modify: `docs/WORK_LOG.md`, `docs/LEARNING_LOG.md`

**Contract:** chapter image는 서로 다르고 학습 의미가 있는 alt text를 가진다. 제작 도식과 실제 기기 증거를 혼동하지 않는다.

- [ ] `imagegen` skill로 동일한 시각 언어의 네 chapter illustration을 생성하되 각 장의 의미를 다르게 한다. 결과는 “구조 도식”으로 명시한다.
- [ ] Chapter 3의 기존 사용자 제공 실패 스크린샷을 사용할 경우 “수정 전 실패 예시”로만 표시하고, 파일 출처·crop 여부를 기록한다.
- [ ] 실제 LiDAR 기기가 연결되면 같은 물체·카메라 시작점에서 수정 후 숨김/발견 전·후를 캡처한다. 생성 이미지나 Simulator로 대체하지 않는다.
- [ ] 고유 alt text, 고대비, mobile crop을 확인하고 DocC warning이 0인지 검증한다.
- [ ] 실기기 이미지가 아직 없으면 정확히 `실기기 대기`로 남기되 나머지 도식·문서 작업은 커밋한다. 최종 완료·배포 게이트는 실제 증거 전까지 열어 두지 않는다.

---

### Task 12: DocC 빌드·접근성·링크·Pages 검증을 자동화한다

**Files:**
- Modify: `scripts/build-docc-site.sh`
- Create: `scripts/verify-docc-site.sh`
- Modify: `.github/workflows/deploy-docc.yml`
- Modify: `Web/index.html`
- Modify as required: DocC metadata/theme resources
- Modify: `docs/WORK_LOG.md`, `docs/LEARNING_LOG.md`

**Contract:** root와 네 tutorial·네 article route, 모든 asset/link/localization/accessibility gate가 로컬과 CI에서 같은 방식으로 실패한다.

- [ ] build script가 warning output을 보존하고 예상 root/tutorial/article JSON·HTML을 전부 검사하도록 실패 테스트를 만든다.
- [ ] verifier가 미해결 `doc:`, 404 theme asset, `{count}`/`{number}`, all-hyphen chapter namespace, 잘못된 `lang`, 중복 alt를 탐지하게 한다.
- [ ] Chapter name에 안정적인 `Chapter 1`…`Chapter 4` 접두사를 사용해 opaque route를 제거한다.
- [ ] 생성 HTML의 한국어 문서 언어를 `ko-KR`로 만들고 placeholder·roleless aria-label·대비 문제를 고친다. 필요한 후처리는 build script 안에서 결정론적으로 수행한다.
- [ ] 로컬 static server에서 전체 link crawl과 desktop/mobile(390×844) 브라우저 검사를 실행한다.
- [ ] axe 또는 동등한 접근성 검사를 CI에 추가하고 serious/critical 0을 요구한다.
- [ ] Pages workflow가 같은 build/verifier를 실행한 뒤에만 artifact를 업로드하도록 변경한다.
- [ ] build·verifier·browser 결과를 기록하고 커밋한다.

---

### Task 13: 전체 회귀·실기기·공개 배포를 완료한다

**Files:**
- Modify: `docs/PROJECT_CONTEXT.md`
- Modify: `docs/WORK_LOG.md`
- Modify: `docs/LEARNING_LOG.md`
- Modify: `README.md` if deployment instructions changed

- [ ] `git status --short`로 사용자 파일과 결과물 범위를 확인한다.
- [ ] Tuist 생성과 전체 unit/UI test를 실제 실행 수로 확인한다.
- [ ] `Build iOS Apps` 세션 기본값을 다시 확인한 뒤 최신 Debug 앱을 Simulator에서 build/run하고, Chapter 1→4 fixture 및 오류 fixture의 semantic UI snapshot과 스크린샷을 재검증한다.

```bash
cd PiggyEscape
tuist generate --no-open
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination "$SIM_DEST" \
  -derivedDataPath /tmp/piggyescape-final-tests test
```

- [ ] Debug·Release generic Simulator build를 각각 새 DerivedData에서 실행한다.
- [ ] Swift 6 strict diagnostic, DocC content/site verifier, 모든 snippet type-check를 다시 실행한다.
- [ ] LiDAR 실기기에서 권한, 18cm/90cm, mesh+floor readiness, 5점 가림, 이동 latch, replay 두 번, Chapter 4 전환을 승인 명세의 수용 목록대로 관찰한다.
- [ ] Chapter 3 실제 전·후 이미지를 catalog에 넣고 최종 DocC를 재빌드한다.
- [ ] 독립 코드 리뷰와 animation/accessibility 검토의 P0/P1을 해결한다.
- [ ] 기능 브랜치를 원격에 push하고 기본 브랜치에 통합한다. dirty 로컬 `main` checkout은 사용하지 않는다.
- [ ] Pages deployment 완료를 확인한 뒤 기준 URL과 네 chapter를 desktop/mobile로 열어 console·network·links·접근성을 재검증한다.
- [ ] `docs/WORK_LOG.md`의 모든 수용 목록을 실제 증거에 따라 체크하고 남은 항목이 없을 때만 완료 커밋을 만든다.

## 최종 완료 증거

- 앱: Chapter 1→2→3→4→completed 실제 상태 전이와 replay
- 정책: 18cm, 90cm, floor inset, view-space 5점, unique AR frame 2회, 15cm/15° latch
- 자동화: 전체 unit/UI tests, Debug/Release, strict concurrency diagnostic
- 실기기: LiDAR 가림·재발견·replay 관찰과 before/after capture
- 문서: 단일 root catalog, 4 tutorial, 4 article, type-checked snippets, warning 0
- 웹: 기준 Pages URL, 정상 route/assets/links, Korean language, serious/critical accessibility violation 0
- Git: `.claude/`와 생성물 제외, 작업 로그·학습 로그·검증 결과 포함, 기본 브랜치 통합
