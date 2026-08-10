# Chapter 1 — C3 월드에서 현실 세계로 탈출하기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** C3_Piggy의 SceneKit 섬에서 돼지가 나무 뒤로 숨었다가 카메라 회전에 들키고, LiDAR로 재구성한 실제 물체 뒤로 다시 숨는 iOS 17 체험을 만든다.

**Architecture:** 기존 Draft PR의 방·가짜 소파 코드는 기준선으로 보존하되, 앱의 진입 화면은 새 `EscapeRootView`로 교체한다. 순수 상태 전이·숨기 좌표·발견 판정은 UIKit/SceneKit/RealityKit에서 분리해 XCTest로 검증하고, C3 월드 어댑터와 `ARView` 코디네이터는 그 결과를 실제 노드·세션·제스처에 적용한다. SceneKit과 RealityKit은 동일한 돼지 포즈/놀람 반응 계약을 공유하지만, 실제 카메라 화각은 변경하지 않고 AR 화면 컨테이너만 1.12배 확대한다.

**Tech Stack:** Swift 6, SwiftUI, SceneKit, SpriteKit, ARKit, RealityKit, AVFoundation, XCTest, Tuist 4, DocC, iOS 17.0.

## Global Constraints

- 작업 브랜치·작업 트리: `ch1-reality-escape`, `/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.worktrees/ch1-reality-escape`.
- 배포 타깃은 iOS 17.0으로 유지한다. AR UI는 iOS 17에서도 사용할 수 있는 `ARView` + `UIViewRepresentable`로 구현한다.
- C3 참고 원본은 `/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy`다. 아래 C3 에셋은 바이트 변경 없이 앱 리소스로 복사한다: `Ground_Color.usdc`, `Piggy.usdc`, `Piggy_running.usdz`, `Piggy_surprised.usdz`, `Cylinder_Tree1_Color.usdc`, `Cylinder_Tree2_Color.usdc`, `Manger_Color.usdc`, `Stone_Color.usdc`, `Coin_Color.usdc`, `Warehouse_Color.usdc`, `Wood_Color.usdc`.
- C3의 카메라 궤도, 조명, 섬 타일·장식물 배치, 돼지 USD 축 보정·걷기 애니메이션 패턴만 재사용한다. SwiftData, 금융 상태, 용돈·작은 돼지, WatchConnectivity, Watch 앱과 그 UI는 가져오지 않는다.
- 시스템 카메라 권한 문구는 `피기가 현실의 물체 뒤에 숨을 수 있도록 카메라를 사용합니다.`로 고정한다.
- SceneKit 나레이션은 `AvenirNext-Bold`(한글 시스템 폴백 허용), SwiftUI 안내는 `.system(..., design: .rounded)`의 bold/heavy·흰색·얕은 검은 그림자를 쓴다. 새 폰트/이미지 에셋을 추가하지 않는다.
- SceneKit 발견과 RealityKit 재발견은 `Piggy_surprised` 전환·"아, 들켰네… 제대로 숨고 싶은데." 자막·바깥 돼지 노드 1.5배 확대(0.16초)·1.0배 복귀(0.34초)를 동시에 시작한다. RealityKit은 추가로 `ARView` 컨테이너를 1.12배 확대 후 복귀한다.
- 실제 숨기는 `ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)`이 참인 LiDAR 지원 실기기에서만 시작한다. 시뮬레이터의 빌드/단위 테스트는 ARKit 실제 오클루전 검증을 대체하지 않는다.
- `ARView.environment.sceneUnderstanding.options`는 `[.occlusion, .collision, .physics, .receivesLighting]`로 설정한다. `.occlusion`은 실제 재구성 메쉬 뒤의 가상 돼지를 렌더링하지 않게 하고, `.collision`은 실제 메쉬 탭·가림 판정 raycast에 사용한다. [Apple 문서](https://developer.apple.com/documentation/realitykit/arview/environment-swift.struct/sceneunderstanding-swift.struct/options-swift.struct)
- 생성된 `.xcodeproj`, `.build`, DerivedData, `.claude/` 활동 로그는 추적하지 않는다. 기존 또는 새로 발견한 추적되지 않은 파일은 명시 요청 없이 이동·삭제·스테이징하지 않는다.
- 실패한 테스트·빌드·실행·API/에셋 실험·실기기 검증은 재시도 또는 보류 결정 전에 `docs/LEARNING_LOG.md`에 재현 조건, 실제 관찰값, 원인/가설, 조치, 검증, 배운 점을 기록한다. 자동 테스트가 대신할 수 없는 실기기 확인은 `실기기 대기`로 남긴다.
- 각 태스크는 해당 XCTest/빌드 증거와 `docs/WORK_LOG.md` 갱신을 같은 커밋에 포함한다. 커밋·PR에는 작업자·도구·모델 표기와 `Co-Authored-By` 트레일러를 넣지 않는다.

## File Structure

| 경로 | 책임 |
| --- | --- |
| `PiggyEscape/Project.swift` | 카메라 권한 Info.plist와 앱/테스트 타깃 리소스 등록 |
| `PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift` | 전체 경험 상태·합법 이벤트·나레이션 문자열 |
| `PiggyEscape/PiggyEscape/Sources/Escape/HidePlanning.swift` | 나무·실제 물체의 카메라 반대편 좌표와 발견 판정 |
| `PiggyEscape/PiggyEscape/Sources/C3World/C3IslandBuilder.swift` | 금융 기능이 제거된 C3 섬 타일·장식물·이름 있는 나무 구성 |
| `PiggyEscape/PiggyEscape/Sources/C3World/C3PigModelFactory.swift` | idle/running/surprised USD 모델, 축 보정, 표준 높이, 바닥 정렬 |
| `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift` | C3 궤도 카메라·조명·섬·돼지·숨기 실행을 소유 |
| `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift` | `SCNView`, 탭/팬/핀치 제스처와 SceneKit 콜백 연결 |
| `PiggyEscape/PiggyEscape/Sources/C3World/NarrationOverlayScene.swift` | C3 스타일의 SpriteKit 나레이션/자막 레이블 |
| `PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift` | 실제 세로 면·바닥·카메라 입력의 유효성·숨기 위치·재발견 판정 |
| `PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift` | RealityKit 돼지 포즈 교체·이동·1.5배 놀람 반응 |
| `PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift` | `ARView` 세션·메쉬·평면·사용자 탭·실제 오클루전·재발견 감시 |
| `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift` | 장면 전환, 권한 요청, C3 스타일 안내 오버레이, AR 화면 확대 |
| `PiggyEscape/PiggyEscape/Sources/ContentView.swift` | 루트 경험 화면 진입점 |
| `PiggyEscape/PiggyEscapeTests/*` | 순수 상태/수학, C3 노드, AR 계획·코디네이터 계약 회귀 테스트 |
| `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/*` | C3 월드→실제 오클루전 흐름을 설명하는 Chapter 1 튜토리얼 |
| `docs/PROJECT_CONTEXT.md`, `docs/WORK_LOG.md`, `docs/TROUBLESHOOTING.md` | 공통 인수인계, 실제 검증 결과, ARKit 제한과 출처 |
| `docs/LEARNING_LOG.md` | 실패·검증 한계의 재현 조건, 원인/가설, 조치, 재발 방지 근거 |

---

### Task 1: C3 에셋과 카메라 권한을 앱 타깃에 등록한다

**Files:**
- Modify: `PiggyEscape/Project.swift`
- Modify: `PiggyEscape/PiggyEscape/Resources/Ground_Color.usdc`
- Modify: `PiggyEscape/PiggyEscape/Resources/Piggy.usdc`
- Modify: `PiggyEscape/PiggyEscape/Resources/Wood_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Piggy_running.usdz`
- Create: `PiggyEscape/PiggyEscape/Resources/Piggy_surprised.usdz`
- Create: `PiggyEscape/PiggyEscape/Resources/Cylinder_Tree1_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Cylinder_Tree2_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Manger_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Stone_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Coin_Color.usdc`
- Create: `PiggyEscape/PiggyEscape/Resources/Warehouse_Color.usdc`
- Modify: `PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift`
- Create: `docs/LEARNING_LOG.md`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `Bundle.main`에서 `Piggy`, `Piggy_running`, `Piggy_surprised`, 두 `Cylinder_Tree`와 섬 장식 에셋을 확장자 없이 찾을 수 있는 리소스 집합.
- Produces: 앱 빌드 산출물 Info.plist의 `NSCameraUsageDescription` 문자열.

- [ ] **Step 1: 실패·학습 기록을 만들고 실패 테스트를 추가한다.**

Create `docs/LEARNING_LOG.md` with the repository's fixed entry format before running the first intentional failing test. Every failure in this task must add an entry before the next retry.

`PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift`에 다음 테스트를 추가한다.

```swift
@MainActor
func test_c3EscapeAssets_loadFromTheAppBundle() {
    let names = [
        "Ground_Color", "Piggy", "Piggy_running", "Piggy_surprised",
        "Cylinder_Tree1_Color", "Cylinder_Tree2_Color", "Manger_Color",
        "Stone_Color", "Coin_Color", "Warehouse_Color", "Wood_Color"
    ]

    for name in names {
        let node = AssetLoader.object(named: name)
        XCTAssertNotNil(node, "expected bundled C3 asset \(name)")
        XCTAssertFalse(node?.childNodes.isEmpty ?? true, "expected geometry hierarchy for \(name)")
    }
}
```

- [ ] **Step 2: 테스트가 새 에셋 누락으로 실패하는지 확인한다.**

Run:

```bash
cd PiggyEscape
tuist generate --no-open
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/AssetLoaderTests/test_c3EscapeAssets_loadFromTheAppBundle test
```

Expected: `Piggy_running`, `Piggy_surprised` 또는 C3 장식물 이름의 bundle lookup assertion이 실패한다.

- [ ] **Step 3: C3 원본을 바이트 변경 없이 복사하고 복사 결과를 검증한다.**

Run:

```bash
for asset in Ground_Color.usdc Piggy.usdc Wood_Color.usdc Piggy_running.usdz Piggy_surprised.usdz Cylinder_Tree1_Color.usdc Cylinder_Tree2_Color.usdc Manger_Color.usdc Stone_Color.usdc Coin_Color.usdc Warehouse_Color.usdc; do
  cmp -s "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/$asset" "PiggyEscape/PiggyEscape/Resources/$asset" || cp "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/$asset" "PiggyEscape/PiggyEscape/Resources/$asset"
  cmp -s "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/$asset" "PiggyEscape/PiggyEscape/Resources/$asset"
done
```

Expected: every final `cmp` exits with status 0; the existing three files are only overwritten if their bytes differed from the source.

- [ ] **Step 4: Tuist Info.plist 설정에 카메라 사용 목적을 추가한다.**

`PiggyEscape/Project.swift`의 앱 타깃 `infoPlist`를 아래와 같이 변경한다.

```swift
infoPlist: .extendingDefault(with: [
    "NSCameraUsageDescription": "피기가 현실의 물체 뒤에 숨을 수 있도록 카메라를 사용합니다."
]),
```

- [ ] **Step 5: 리소스와 생성된 Info.plist를 검증한다.**

Run:

```bash
cd PiggyEscape
tuist generate --no-open
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/piggyescape-build \
  -only-testing:PiggyEscapeTests/AssetLoaderTests test
plutil -extract NSCameraUsageDescription raw -o - \
  /tmp/piggyescape-build/Build/Products/Debug-iphonesimulator/PiggyEscape.app/Info.plist
```

Expected: `AssetLoaderTests` pass and `plutil` prints `피기가 현실의 물체 뒤에 숨을 수 있도록 카메라를 사용합니다.`.

- [ ] **Step 6: 인수인계를 갱신하고 커밋한다.**

`docs/WORK_LOG.md`의 현재 인수인계에 C3 에셋·카메라 권한 등록 완료, 실행한 테스트, 다음 Task 2를 기록한다.

```bash
git add PiggyEscape/Project.swift PiggyEscape/PiggyEscape/Resources \
  PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift docs/LEARNING_LOG.md docs/WORK_LOG.md
git commit -m "Add C3 escape assets and camera permission"
```

---

### Task 2: 경험 상태와 숨기 좌표를 순수 로직으로 만든다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/HidePlanning.swift`
- Create: `PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/HidePlanningTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `EscapeExperienceState`, `EscapeExperienceEvent`, `EscapeExperienceMachine.send(_:) -> Bool`.
- Produces: `TreeHidePlanner.destination(treeCenter:treeRadius:cameraPosition:pigRadius:floorY:) -> SIMD3<Float>`.
- Produces: a complete state machine without importing UIKit, SceneKit, ARKit, or RealityKit; actual physical-object planning is introduced in Task 5.

- [ ] **Step 1: 상태 전이와 좌표 계산의 실패 테스트를 작성한다.**

`PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift`:

```swift
import XCTest
@testable import PiggyEscape

final class EscapeExperienceStateTests: XCTestCase {
    func test_pigTapIsIgnoredUntilOpeningNarrationCompletes() {
        var machine = EscapeExperienceMachine()
        XCTAssertFalse(machine.send(.pigTapped))
        XCTAssertEqual(machine.state, .openingNarration)

        XCTAssertTrue(machine.send(.narrationFinished))
        XCTAssertTrue(machine.send(.pigTapped))
        XCTAssertEqual(machine.state, .walkingBehindTree)
    }

    func test_discoverySequenceCanReachRealityOnlyInOrder() {
        var machine = EscapeExperienceMachine(state: .hiddenInClosedWorld)
        XCTAssertTrue(machine.send(.closedWorldPigDiscovered))
        XCTAssertEqual(machine.state, .discoveredByCamera)
        XCTAssertTrue(machine.send(.closedWorldFadeFinished))
        XCTAssertEqual(machine.state, .requestingCameraPermission)
        XCTAssertTrue(machine.send(.cameraAuthorized))
        XCTAssertEqual(machine.state, .scanningReality)
    }
}
```

`PiggyEscape/PiggyEscapeTests/HidePlanningTests.swift`:

```swift
import XCTest
import simd
@testable import PiggyEscape

final class HidePlanningTests: XCTestCase {
    func test_treeDestinationIsOnTheCameraOppositeSideAndOnTheFloor() {
        let target = TreeHidePlanner.destination(
            treeCenter: SIMD3(0, 0, 0), treeRadius: 0.5,
            cameraPosition: SIMD3(0, 2, 4), pigRadius: 0.25, floorY: 0
        )
        XCTAssertLessThan(target.z, 0)
        XCTAssertEqual(target.y, 0, accuracy: 0.0001)
    }

}
```

- [ ] **Step 2: 새 타입 부재로 테스트가 컴파일 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/EscapeExperienceStateTests \
  -only-testing:PiggyEscapeTests/HidePlanningTests test
```

Expected: `EscapeExperienceMachine`과 `TreeHidePlanner`를 찾지 못해 컴파일 실패한다.

- [ ] **Step 3: 합법 전이만 허용하는 상태 기계를 구현한다.**

`EscapeExperienceState.swift`에 아래 계약을 구현한다. `.cameraDenied`와 `.lidarUnavailable`은 종료 상태이며, `reset`만 `.openingNarration`으로 돌린다.

```swift
enum EscapeExperienceState: Equatable {
    case openingNarration, readyForPigTap, walkingBehindTree, hiddenInClosedWorld
    case discoveredByCamera, requestingCameraPermission, scanningReality
    case waitingForRealTarget, walkingBehindRealObject, hiddenInReality, discoveredInReality
    case cameraDenied, lidarUnavailable
}

enum EscapeExperienceEvent {
    case narrationFinished, pigTapped, pigReachedTree, closedWorldPigDiscovered
    case closedWorldFadeFinished, cameraAuthorized, cameraDenied, meshSupported
    case meshUnsupported, realTargetAccepted, pigReachedRealObject, realityPigDiscovered, reset
}

struct EscapeExperienceMachine {
    private(set) var state: EscapeExperienceState
    init(state: EscapeExperienceState = .openingNarration) { self.state = state }
    mutating func send(_ event: EscapeExperienceEvent) -> Bool {
        switch (state, event) {
        case (_, .reset): state = .openingNarration
        case (.openingNarration, .narrationFinished): state = .readyForPigTap
        case (.readyForPigTap, .pigTapped): state = .walkingBehindTree
        case (.walkingBehindTree, .pigReachedTree): state = .hiddenInClosedWorld
        case (.hiddenInClosedWorld, .closedWorldPigDiscovered): state = .discoveredByCamera
        case (.discoveredByCamera, .closedWorldFadeFinished): state = .requestingCameraPermission
        case (.requestingCameraPermission, .cameraAuthorized): state = .scanningReality
        case (.requestingCameraPermission, .cameraDenied): state = .cameraDenied
        case (.scanningReality, .meshSupported): state = .waitingForRealTarget
        case (.scanningReality, .meshUnsupported): state = .lidarUnavailable
        case (.waitingForRealTarget, .realTargetAccepted): state = .walkingBehindRealObject
        case (.walkingBehindRealObject, .pigReachedRealObject): state = .hiddenInReality
        case (.hiddenInReality, .realityPigDiscovered): state = .discoveredInReality
        default: return false
        }
        return true
    }
}
```

The implementation must map `cameraAuthorized` to `.scanningReality`, then `meshSupported` to `.waitingForRealTarget`; `realityPigDiscovered` is accepted only from `.hiddenInReality` and changes state to `.discoveredInReality`.

- [ ] **Step 4: 나무 뒤 숨기 계산을 결정론적으로 구현한다.**

`HidePlanning.swift`에 `TreeHidePlanner`를 구현한다. 카메라에서 나무 중심으로 향하는 XZ 방향을 정규화한 뒤 반대편에 돼지를 배치하고, 중심 거리는 `treeRadius + pigRadius + 0.08`, Y는 정확히 `floorY`를 쓴다. 카메라와 나무의 XZ가 같아 방향을 정할 수 없으면 기본 방향 `(0, 0, -1)`을 쓴다.

```swift
enum TreeHidePlanner {
    static func destination(treeCenter: SIMD3<Float>, treeRadius: Float,
                            cameraPosition: SIMD3<Float>, pigRadius: Float,
                            floorY: Float) -> SIMD3<Float> {
        let towardCamera = SIMD3(cameraPosition.x - treeCenter.x, 0, cameraPosition.z - treeCenter.z)
        let direction = simd_length_squared(towardCamera) > 0.0001
            ? simd_normalize(towardCamera)
            : SIMD3<Float>(0, 0, 1)
        let distance = treeRadius + pigRadius + 0.08
        return SIMD3(treeCenter.x - direction.x * distance, floorY, treeCenter.z - direction.z * distance)
    }
}
```

- [ ] **Step 5: 순수 로직 테스트를 통과시킨다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/EscapeExperienceStateTests \
  -only-testing:PiggyEscapeTests/HidePlanningTests test
```

Expected: 두 테스트 클래스의 모든 테스트가 통과한다.

- [ ] **Step 6: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift \
  PiggyEscape/PiggyEscape/Sources/Escape/HidePlanning.swift \
  PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift \
  PiggyEscape/PiggyEscapeTests/HidePlanningTests.swift docs/WORK_LOG.md
git commit -m "Add escape state and hide planning"
```

---

### Task 3: 금융 기능 없이 C3 섬·돼지·궤도 카메라를 이식한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/C3World/C3IslandBuilder.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/C3World/C3PigModelFactory.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift`
- Create: `PiggyEscape/PiggyEscapeTests/C3IslandBuilderTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/C3PigModelFactoryTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `C3IslandBuilder.build() -> SCNNode`, with root `"C3Island"`, a selectable `"HideTree"`, and `"BigPigSpawn"`.
- Produces: `C3PigModelFactory.makeContainer(pose:) -> SCNNode`, `C3PigPose.idle`, `.running`, `.surprised`, and `C3PigModelFactory.setPose(_:on:)`.
- Produces: `@MainActor final class C3ClosedWorld` with `scene`, `pigContainer`, `hideTree`, `cameraYaw`, `rotateCamera(byYaw:)`, and `zoom(by:)`.

- [ ] **Step 1: C3 월드 계층과 모델 교체의 실패 테스트를 작성한다.**

```swift
@MainActor
func test_buildCreatesNamedExistingTreeAndBigPigSpawn() {
    let island = C3IslandBuilder.build()
    XCTAssertEqual(island.name, "C3Island")
    XCTAssertNotNil(island.childNode(withName: "HideTree", recursively: true))
    XCTAssertNotNil(island.childNode(withName: "BigPigSpawn", recursively: true))
}

@MainActor
func test_pigContainerKeepsInnerModelCorrectionWhenPoseChanges() {
    let pig = C3PigModelFactory.makeContainer(pose: .idle)
    let originalScale = pig.scale
    C3PigModelFactory.setPose(.surprised, on: pig)
    XCTAssertEqual(pig.name, "EscapePig")
    XCTAssertEqual(pig.scale.x, originalScale.x, accuracy: 0.0001)
    XCTAssertEqual(pig.scale.y, originalScale.y, accuracy: 0.0001)
    XCTAssertEqual(pig.scale.z, originalScale.z, accuracy: 0.0001)
    XCTAssertNotNil(pig.childNode(withName: "PigModel_surprised", recursively: false))
}

@MainActor
func test_worldUsesOrthographicC3OrbitCamera() {
    let world = C3ClosedWorld()
    XCTAssertTrue(world.cameraNode.camera?.usesOrthographicProjection ?? false)
    XCTAssertEqual(world.cameraNode.camera?.orthographicScale ?? 0, 6.0, accuracy: 0.001)
}
```

- [ ] **Step 2: 구현 전 테스트가 타입 부재로 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/C3IslandBuilderTests \
  -only-testing:PiggyEscapeTests/C3PigModelFactoryTests \
  -only-testing:PiggyEscapeTests/C3ClosedWorldTests test
```

Expected: C3 world types are not found and the test target fails to compile.

- [ ] **Step 3: C3 섬 빌더의 비금융 부분만 이식한다.**

`C3IslandBuilder`는 C3의 `IslandBuilder.buildFlatGroundIsland`, `buildFlatGroundDecorations`, `makeFlatGroundDecoration`, `flatGroundMetrics`, 변환을 반영한 `geometryBounds`를 이식한다. 아래 이름·배치 규칙을 고정한다.

```swift
enum C3IslandBuilder {
    static func build() -> SCNNode {
        let island = SCNNode()
        island.name = "C3Island"
        // Ground_Color 중앙 타일 + 6개 외곽 타일, C3와 같은 X축 -π/2 회전과 √2 가로 스케일
        // Cylinder_Tree1_Color 장식 컨테이너의 이름은 "HideTree"로 지정
        // BigPigSpawn은 중앙 타일의 실제 윗면 중앙에 배치
        return island
    }
}
```

Keep C3 decoration positions for the two trees, manger, stones, coin, warehouse, and wood. Do not copy `SmallPigSpawn_*`, allowance-pig placement, coin emission, balance scaling, or SwiftData imports.

- [ ] **Step 4: USD 축 보정과 세 가지 돼지 포즈 팩토리를 구현한다.**

```swift
enum C3PigPose: String { case idle, running, surprised }

enum C3PigModelFactory {
    static func makeContainer(pose: C3PigPose) -> SCNNode {
        let container = SCNNode()
        container.name = "EscapePig"
        setPose(pose, on: container)
        return container
    }

    static func setPose(_ pose: C3PigPose, on container: SCNNode) {
        container.childNodes.forEach { $0.removeFromParentNode() }
        let model = loadNormalizedModel(named: pose == .idle ? "Piggy" : "Piggy_\(pose.rawValue)")
        model.name = "PigModel_\(pose.rawValue)"
        container.addChildNode(model)
        if pose == .running { playEmbeddedAnimations(on: model) }
    }
}
```

`loadNormalizedModel` must wrap the source art in an inner node, apply C3's `SCNVector3(.pi / 2, 0, .pi)` axis correction, normalize the inner model to 1.5m height, place its lowest transformed vertex at `y == 0`, and apply the C3 outer facing yaw `3 * .pi / 4`. The outer `EscapePig` node must never carry the normalization scale.

- [ ] **Step 5: C3 궤도 카메라·조명·중앙 돼지 월드를 구현한다.**

```swift
@MainActor
final class C3ClosedWorld {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pigContainer: SCNNode
    let hideTree: SCNNode
    private(set) var cameraYaw: Float = .pi / 4
    private let orbitRadius: Float = 17
    private let orbitHeight: Float = 12
    private var orthographicScale: CGFloat = 6
    private let directionalLightNode: SCNNode

    func rotateCamera(byYaw delta: Float) {
        cameraYaw += delta
        cameraNode.position = SCNVector3(
            orbitRadius * sin(cameraYaw), orbitHeight, orbitRadius * cos(cameraYaw)
        )
        directionalLightNode.eulerAngles = SCNVector3(-.pi / 3, cameraYaw - .pi / 4, 0)
    }

    func zoom(by factor: Float) {
        guard factor > 0 else { return }
        orthographicScale = min(12, max(3, orthographicScale / CGFloat(factor)))
        cameraNode.camera?.orthographicScale = orthographicScale
    }
}
```

Use the C3 gradient background, ambient intensity 800, directional intensity 520, deferred soft shadow settings, radius 17, height 12, and orthographic scale 6. Add the island and the idle `EscapePig` at `BigPigSpawn`; expose the actual `HideTree` node for Task 4.

- [ ] **Step 6: C3 world tests를 통과시킨다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/C3IslandBuilderTests \
  -only-testing:PiggyEscapeTests/C3PigModelFactoryTests \
  -only-testing:PiggyEscapeTests/C3ClosedWorldTests test
```

Expected: named island/tree/spawn, outer-vs-inner model transform, and orthographic camera tests pass.

- [ ] **Step 7: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/C3World \
  PiggyEscape/PiggyEscapeTests/C3IslandBuilderTests.swift \
  PiggyEscape/PiggyEscapeTests/C3PigModelFactoryTests.swift \
  PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift docs/WORK_LOG.md
git commit -m "Add C3 closed world adapter"
```

---

### Task 4: SceneKit의 나레이션·탭·가짜 숨기·카메라 발견을 연결한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/C3World/NarrationOverlayScene.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift`
- Create: `PiggyEscape/PiggyEscapeTests/ClosedWorldEscapeTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/NarrationOverlaySceneTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `C3ClosedWorldSceneView(onNarrationFinished:onDiscovered:)`.
- Produces: `C3ClosedWorld.tapPig() -> Bool`, `completeOpeningNarration()`, `finishTreeHideForTesting()`, `isDiscoveredAfterCameraRotation() -> Bool`, and `performSurpriseReaction()`; its test-visible read-only state is `currentPose`, `lastCaption`, and `surprisePeakScale`.
- Produces: `NarrationOverlayScene.show(_:)`, `showSurpriseCaption()`, and `captionText` for deterministic verification.

- [ ] **Step 1: 내레이션 게이트·발견 조건·놀람 반응의 실패 테스트를 작성한다.**

```swift
@MainActor
func test_tapIsIgnoredBeforeNarrationAndStartsRunningAfterIt() {
    let world = C3ClosedWorld()
    XCTAssertFalse(world.tapPig())
    world.completeOpeningNarration()
    XCTAssertTrue(world.tapPig())
    XCTAssertEqual(world.currentPose, .running)
}

@MainActor
func test_cameraDiscoveryNeedsYawChangeAndVisiblePig() {
    let world = C3ClosedWorld()
    world.completeOpeningNarration()
    _ = world.tapPig()
    world.finishTreeHideForTesting()
    XCTAssertFalse(world.isDiscoveredAfterCameraRotation())
    world.rotateCamera(byYaw: .pi / 2)
    XCTAssertTrue(world.isDiscoveredAfterCameraRotation())
}

@MainActor
func test_surpriseCaptionAndScaleReactionStartTogether() {
    let world = C3ClosedWorld()
    world.performSurpriseReaction()
    XCTAssertEqual(world.currentPose, .surprised)
    XCTAssertEqual(world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
    XCTAssertEqual(world.surprisePeakScale, 1.5, accuracy: 0.0001)
}
```

- [ ] **Step 2: 테스트가 새 API 부재로 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests \
  -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test
```

Expected: state, overlay, and surprise API lookup errors cause a compile failure.

- [ ] **Step 3: SpriteKit 나레이션 오버레이를 구현한다.**

```swift
final class NarrationOverlayScene: SKScene {
    private(set) var captionText = ""
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

    func showOpeningNarration() {
        show("아, 나 좀 그만 쳐다보지. 나 숨고 싶어…")
    }

    func showSurpriseCaption() {
        show("아, 들켰네… 제대로 숨고 싶은데.")
    }
}
```

Set white text, black 0.18-alpha shadow, a 12-point rounded dark backing panel, and a short fade/scale action. `show(_:)` must set `captionText` synchronously before starting animations so tests do not depend on an `SKView` frame clock.

- [ ] **Step 4: 가짜 숨기와 발견 반응을 C3 월드에 구현한다.**

On an accepted pig tap, change to `.running`, calculate `TreeHidePlanner.destination` from the actual transformed `HideTree` bounds and current C3 camera position, rotate the outer `EscapePig` toward the destination, and run `SCNAction.move(to:duration:)` at 1.1 world units/second. After reaching the destination, change to `.idle`, record the current yaw, and wait for the next eligible camera rotation.

Treat a discovery as eligible only when all conditions hold: the pig has reached the tree, absolute wrapped yaw difference is at least `0.70` radians, the pig is inside the camera frustum (`pigContainer.isInsideFrustum(of: cameraNode) == true`), and discovery has not run before. Then set `.surprised`, call the overlay callback in the same method, and run the following outer-node action under key `"escapePig.surpriseScale"`.

```swift
let grow = SCNAction.scale(to: 1.5, duration: 0.16)
grow.timingMode = .easeOut
let restore = SCNAction.scale(to: 1.0, duration: 0.34)
restore.timingMode = .easeInEaseOut
pigContainer.runAction(.sequence([grow, restore]), forKey: "escapePig.surpriseScale")
```

- [ ] **Step 5: C3-style SceneKit view and gestures를 구현한다.**

`C3ClosedWorldSceneView` must create an `SCNView` with `allowsCameraControl = false`, C3 custom lighting, `overlaySKScene`, a one-tap recognizer that first `hitTest`s the touch and only passes hits that are descendants of `EscapePig` to `tapPig()`, a pan recognizer that calls `rotateCamera(byYaw:)`, and a two-finger pinch that calls `zoom(by:)`. Use a C3-equivalent mapping of full screen width to `π` yaw and reset the gesture translation each callback.

- [ ] **Step 6: SceneKit interaction tests를 통과시키고 Simulator에서 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests \
  -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: tests pass and the Simulator build shows the C3 island, initial narration, tap-gated running pig, and discovery caption when the camera is panned.

- [ ] **Step 7: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/C3World \
  PiggyEscape/PiggyEscapeTests/ClosedWorldEscapeTests.swift \
  PiggyEscape/PiggyEscapeTests/NarrationOverlaySceneTests.swift docs/WORK_LOG.md
git commit -m "Add C3 pig hide and discovery flow"
```

---

### Task 5: 실제 물체 숨기 계획과 LiDAR 지원 판정을 구현한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityCapability.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityCapabilityTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `RealitySurfaceHit(point:normal:)`, `RealityFloor(point:)`, `RealityHidePlanner.plan(hit:cameraPosition:floor:) -> RealityHidePlanResult`.
- Produces: `protocol RealityMeshSupporting { var supportsMeshWithClassification: Bool { get } }` and `SystemRealityMeshSupport`.
- Produces: `RealityRevealMonitor` that records initial mesh blocking and emits one `true` result only after the physical mesh no longer precedes the pig.

- [ ] **Step 1: 실제 면 선택과 한 번만 재발견하는 실패 테스트를 작성한다.**

```swift
func test_verticalSurfacePlacesPigOnCameraOppositeSideOfObject() {
    let result = RealityHidePlanner.plan(
        hit: RealitySurfaceHit(point: SIMD3(1, 0.9, 0), normal: SIMD3(1, 0, 0)),
        cameraPosition: SIMD3(3, 1.5, 0), floor: RealityFloor(point: SIMD3(1, 0, 0))
    )
    guard case let .accepted(position) = result else { return XCTFail("expected accepted target") }
    XCTAssertLessThan(position.x, 1)
    XCTAssertEqual(position.y, 0, accuracy: 0.0001)
}

func test_horizontalSurfaceAndMissingFloorAreRejected() {
    XCTAssertEqual(
        RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 1, 0)),
            cameraPosition: SIMD3(0, 1.5, 1), floor: RealityFloor(point: SIMD3(0, 0, 0))
        ),
        .rejected(.selectVerticalSide)
    )
    XCTAssertEqual(
        RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: SIMD3(1, 0.8, 0), normal: SIMD3(1, 0, 0)),
            cameraPosition: SIMD3(3, 1.5, 0), floor: nil
        ),
        .rejected(.findFloor)
    )
}

func test_floorTooFarFromTheObjectIsRejected() {
    XCTAssertEqual(
        RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: SIMD3(0, 0.8, 0), normal: SIMD3(0, 0, 1)),
            cameraPosition: SIMD3(0, 1.5, 2), floor: RealityFloor(point: SIMD3(2, 0, 0))
        ),
        .rejected(.findFloor)
    )
}

func test_revealMonitorFiresOnlyAfterFirstBlockedFrameThenVisibleFrame() {
    var monitor = RealityRevealMonitor()
    XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2))
    XCTAssertFalse(monitor.update(meshDistance: 1, pigDistance: 2))
    XCTAssertTrue(monitor.update(meshDistance: nil, pigDistance: 2))
    XCTAssertFalse(monitor.update(meshDistance: nil, pigDistance: 2))
}
```

- [ ] **Step 2: 테스트가 Reality types 부재로 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/RealityHidePlannerTests \
  -only-testing:PiggyEscapeTests/RealityCapabilityTests test
```

Expected: Reality planning and capability types cannot be found.

- [ ] **Step 3: ARKit-independent 입력 타입과 재발견 모니터를 구현한다.**

```swift
import simd

struct RealitySurfaceHit: Equatable { let point: SIMD3<Float>; let normal: SIMD3<Float> }
struct RealityFloor: Equatable { let point: SIMD3<Float> }

struct RealityRevealMonitor {
    private var hasObservedBlockingMesh = false
    private var hasReportedReveal = false

    mutating func update(meshDistance: Float?, pigDistance: Float) -> Bool {
        let blocked = meshDistance.map { $0 + 0.03 < pigDistance } ?? false
        hasObservedBlockingMesh = hasObservedBlockingMesh || blocked
        guard hasObservedBlockingMesh, !blocked, !hasReportedReveal else { return false }
        hasReportedReveal = true
        return true
    }
}

enum RealityHideRejection: Equatable { case selectVerticalSide, moveFartherAway, findFloor }
enum RealityHidePlanResult: Equatable { case accepted(SIMD3<Float>), rejected(RealityHideRejection) }

enum RealityHidePlanner {
    static let verticalNormalMaximumY: Float = 0.35
    static let minimumCameraDistance: Float = 0.45
    static let objectClearance: Float = 0.28
    static let maximumFloorDistance: Float = 1.2

    static func plan(hit: RealitySurfaceHit, cameraPosition: SIMD3<Float>,
                     floor: RealityFloor?) -> RealityHidePlanResult {
        guard abs(hit.normal.y) <= verticalNormalMaximumY else { return .rejected(.selectVerticalSide) }
        guard simd_distance(hit.point, cameraPosition) >= minimumCameraDistance else { return .rejected(.moveFartherAway) }
        guard let floor else { return .rejected(.findFloor) }
        let floorOffset = SIMD2(hit.point.x - floor.point.x, hit.point.z - floor.point.z)
        guard simd_length(floorOffset) <= maximumFloorDistance else { return .rejected(.findFloor) }
        guard simd_length_squared(hit.normal) > 0.0001 else { return .rejected(.selectVerticalSide) }
        let normal = simd_normalize(hit.normal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0 ? normal : -normal
        let hiddenPoint = hit.point - towardCamera * objectClearance
        return .accepted(SIMD3(hiddenPoint.x, floor.point.y, hiddenPoint.z))
    }
}
```

- [ ] **Step 4: 시스템 지원 판정과 안내 문자열을 구현한다.**

```swift
import ARKit

protocol RealityMeshSupporting {
    var supportsMeshWithClassification: Bool { get }
}

struct SystemRealityMeshSupport: RealityMeshSupporting {
    var supportsMeshWithClassification: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }
}

enum RealityAvailabilityMessage {
    static let unavailable = "이 기능은 LiDAR로 공간을 읽을 수 있는 기기에서 사용할 수 있어."
    static let scanFirst = "주변 바닥과 숨을 물체를 조금 더 스캔해줘."
    static let selectVerticalSide = "숨을 물체의 옆면을 탭해줘."
    static let moveFartherAway = "조금 떨어진 물체의 옆면을 탭해줘."
}
```

The test fake must set `supportsMeshWithClassification` to both `true` and `false`; it must not call ARKit on Simulator to simulate LiDAR support.

```swift
private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}

func test_injectedCapabilityDoesNotDependOnTheSimulator() {
    XCTAssertTrue(FakeRealityMeshSupport(supportsMeshWithClassification: true).supportsMeshWithClassification)
    XCTAssertFalse(FakeRealityMeshSupport(supportsMeshWithClassification: false).supportsMeshWithClassification)
}
```

- [ ] **Step 5: Reality planning tests를 통과시킨다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/RealityHidePlannerTests \
  -only-testing:PiggyEscapeTests/RealityCapabilityTests test
```

Expected: vertical/horizontal/distance/floor rejection, camera-opposite target, capability fake, and one-time reveal monitor tests all pass.

- [ ] **Step 6: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift \
  PiggyEscape/PiggyEscape/Sources/Reality/RealityCapability.swift \
  PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityCapabilityTests.swift docs/WORK_LOG.md
git commit -m "Add reality hide planning"
```

---

### Task 6: RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기를 구현한다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift`
- Create: `PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `@MainActor final class RealityPigVisualController` with `loadIdlePig()`, `walk(to:completion:)`, `showSurprised()`, `playSurpriseScale()`, `worldPosition`, `currentPose`, `surprisePeakScale`, `surpriseRestoreScale`, and `makeForTesting()`.
- Produces: `RealityHideARView(onScanningReady:onTargetAccepted:onRevealed:onUnavailable:onMessage:)`.
- Consumes: Task 5 `RealityHidePlanner`, `RealityRevealMonitor`, `RealityMeshSupporting`.

- [ ] **Step 1: RealityKit visual state와 AR coordinator 의존성의 실패 테스트를 작성한다.**

```swift
@MainActor
func test_surpriseVisualUsesSamePeakAndRestoreScaleAsSceneKit() {
    let controller = RealityPigVisualController.makeForTesting()
    controller.showSurprised()
    controller.playSurpriseScale()
    XCTAssertEqual(controller.currentPose, .surprised)
    XCTAssertEqual(controller.surprisePeakScale, 1.5, accuracy: 0.0001)
    XCTAssertEqual(controller.surpriseRestoreScale, 1.0, accuracy: 0.0001)
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}

func test_coordinatorReportsUnavailableWithoutStartingARSession() {
    let support = FakeRealityMeshSupport(supportsMeshWithClassification: false)
    let coordinator = RealityHideARView.Coordinator(meshSupport: support)
    XCTAssertFalse(coordinator.canStartMeshSession)
}
```

- [ ] **Step 2: 테스트가 RealityKit visual/controller 부재로 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests \
  -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test
```

Expected: the new visual controller and AR view coordinator are absent, causing a compile failure.

- [ ] **Step 3: RealityKit 돼지 모델과 동일한 놀람 반응을 구현한다.**

Use a stable outer `Entity` named `"RealityEscapePig"`; remove and replace only its `"RealityPigModel_<pose>"` child. Load `Piggy.usdc`, `Piggy_running.usdz`, and `Piggy_surprised.usdz` from the app bundle with RealityKit's asynchronous entity loader, retain the C3-facing yaw and normalized height from Task 3, and call `generateCollisionShapes(recursive: true)` after a model loads.

```swift
func playSurpriseScale() {
    surprisePeakScale = 1.5
    surpriseRestoreScale = 1.0
    outerEntity.move(to: Transform(scale: SIMD3(repeating: 1.5),
                                   rotation: outerEntity.transform.rotation,
                                   translation: outerEntity.transform.translation),
                     relativeTo: outerEntity.parent, duration: 0.16, timingFunction: .easeOut)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
        self?.outerEntity.move(to: Transform(scale: SIMD3(repeating: 1),
                                             rotation: self?.outerEntity.transform.rotation ?? simd_quatf(),
                                             translation: self?.outerEntity.transform.translation ?? .zero),
                               relativeTo: self?.outerEntity.parent, duration: 0.34, timingFunction: .easeInOut)
    }
}
```

The production implementation must not change `ARView.cameraTransform`, `ARSession`, or the real camera lens during this reaction.

- [ ] **Step 4: ARView의 LiDAR mesh session과 실제 면 탭을 구현한다.**

Create `ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)`. Before `session.run`, guard `meshSupport.supportsMeshWithClassification`; otherwise call `onUnavailable` and do not run a session. For supported devices configure exactly:

```swift
let configuration = ARWorldTrackingConfiguration()
configuration.planeDetection = [.horizontal, .vertical]
configuration.sceneReconstruction = .meshWithClassification
arView.environment.sceneUnderstanding.options = [.occlusion, .collision, .physics, .receivesLighting]
arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
```

On the user's one-finger tap, call `arView.hitTest(point, query: .nearest, mask: .sceneUnderstanding)`. Convert the nearest `CollisionCastHit` position and surface normal to `RealitySurfaceHit`; obtain a nearby horizontal floor from `ARPlaneAnchor` values in the current frame; then call Task 5's planner. Present `RealityAvailabilityMessage` for every rejection. On acceptance, walk the running pig to the result, change it to idle after arrival, and begin the reveal monitor.

- [ ] **Step 5: 실제 메쉬 가림이 사라졌을 때 한 번만 재발견을 실행한다.**

Subscribe to `SceneEvents.Update` only while the pig is hidden. Each frame, project the pig's world position into the `ARView`, query the real mesh at that screen point, and compare the mesh collision distance to the current AR camera-to-pig distance:

```swift
guard let point = arView.project(pigWorldPosition),
      let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
let meshDistance = arView.hitTest(point, query: .nearest, mask: .sceneUnderstanding).first.map {
    simd_distance(SIMD3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z), $0.position)
}
let pigDistance = simd_distance(SIMD3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z), pigWorldPosition)
if revealMonitor.update(meshDistance: meshDistance, pigDistance: pigDistance) {
    visualController.showSurprised()
    visualController.playSurpriseScale()
    onRevealed()
}
```

Cancel the update subscription after the monitor emits `true`; later frames must not recreate the surprise.

- [ ] **Step 6: unit tests를 통과시키고 실제 기기 검증 준비 상태를 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests \
  -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: deterministic controller/coordinator tests pass and the iOS build succeeds. Record that actual mesh occlusion still requires the LiDAR device test in Task 8.

- [ ] **Step 7: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality \
  PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift \
  PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift docs/WORK_LOG.md
git commit -m "Add RealityKit hide behind real objects"
```

---

### Task 7: 자동 SceneKit→RealityKit 전환과 C3 스타일 안내를 만든다

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/ContentView.swift`
- Create: `PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Produces: `EscapeRootView` as the only app-visible flow.
- Produces: `CameraAuthorizing.requestVideoAccess(_:)`, `SystemCameraAuthorizer`, and `EscapeRootCoordinator` with explicit callbacks for C3 discovery, fade completion, camera result, mesh support, and RealityKit discovery.
- Consumes: Task 2 state machine, Task 4 SceneKit callbacks, Task 6 AR callbacks.

- [ ] **Step 1: 전환 순서와 권한 거부의 실패 테스트를 작성한다.**

```swift
private final class FakeCameraAuthorizer: CameraAuthorizing {
    let result: Bool
    private(set) var requestCount = 0
    init(result: Bool) { self.result = result }
    func requestVideoAccess(_ completion: @escaping (Bool) -> Void) {
        requestCount += 1
        completion(result)
    }
}

func test_closedWorldDiscoveryWaitsForFadeBeforeCameraPrompt() {
    let authorizer = FakeCameraAuthorizer(result: true)
    var coordinator = EscapeRootCoordinator(cameraAuthorizer: authorizer)
    coordinator.closedWorldDiscoveryDidOccur()
    XCTAssertEqual(coordinator.machine.state, .discoveredByCamera)
    XCTAssertEqual(authorizer.requestCount, 0)
    coordinator.closedWorldFadeDidFinish()
    XCTAssertEqual(authorizer.requestCount, 1)
}

func test_deniedCameraShowsRecoveryInsteadOfStartingRealitySession() {
    let authorizer = FakeCameraAuthorizer(result: false)
    var coordinator = EscapeRootCoordinator(cameraAuthorizer: authorizer)
    coordinator.beginCameraRequestAfterFade()
    XCTAssertEqual(coordinator.machine.state, .cameraDenied)
    XCTAssertFalse(coordinator.showsRealityView)
}
```

- [ ] **Step 2: 테스트가 루트 coordinator 부재로 실패하는지 확인한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test
```

Expected: `EscapeRootCoordinator` and `CameraAuthorizing` cannot be found.

- [ ] **Step 3: 권한 주입 경계와 상태 기반 루트 coordinator를 구현한다.**

```swift
protocol CameraAuthorizing {
    func requestVideoAccess(_ completion: @escaping (Bool) -> Void)
}

struct SystemCameraAuthorizer: CameraAuthorizing {
    func requestVideoAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }
}
```

`closedWorldDiscoveryDidOccur()` must set `.discoveredByCamera` and show the surprise caption immediately. It must wait `0.70` seconds for the C3 world fade before calling `requestVideoAccess`. On a true callback it sends `.cameraAuthorized`, shows the AR scanning view, then accepts Task 6's supported/unavailable callback; on false it sends `.cameraDenied` and displays a Settings recovery button using `UIApplication.openSettingsURLString`.

- [ ] **Step 4: C3 느낌의 SwiftUI 오버레이와 RealityKit 화면 확대를 구현한다.**

```swift
@State private var realityScreenScale: CGFloat = 1

private func performRealitySurprise() {
    realityScreenScale = 1.12
    withAnimation(.easeOut(duration: 0.16)) { realityScreenScale = 1.12 }
    withAnimation(.easeInOut(duration: 0.34).delay(0.16)) { realityScreenScale = 1 }
}
```

Render `RealityHideARView` under `.scaleEffect(realityScreenScale)` and clip it to its parent. The caption panel must use white `.system(size: 20, weight: .heavy, design: .rounded)` text, black 0.18-alpha shadow, `.ultraThinMaterial`, 24-point rounded corners, and short opacity/scale transitions. It must not mutate ARView's camera transform or AR session while the SwiftUI effect runs.

- [ ] **Step 5: ContentView의 기준 화면을 새 경험 루트로 교체한다.**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        EscapeRootView()
            .ignoresSafeArea()
    }
}
```

The old `ClosedWorldSceneView` remains compiled as Draft PR reference code but must not be instantiated by `ContentView`.

- [ ] **Step 6: 루트 전환 테스트·앱 빌드를 검증한다.**

Run:

```bash
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test
xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: coordinator tests pass and the Simulator build begins in the C3 island rather than the old room.

- [ ] **Step 7: 인수인계를 갱신하고 커밋한다.**

```bash
git add PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift \
  PiggyEscape/PiggyEscape/Sources/ContentView.swift \
  PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift docs/WORK_LOG.md
git commit -m "Connect C3 world to RealityKit escape"
```

---

### Task 8: 전체 회귀·실기기 검증과 DocC/인수인계를 마무리한다

**Files:**
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/01-ClosedWorld.tutorial`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-01-01.swift`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-02-01.swift`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-03-01.swift`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-04-01.swift`
- Modify: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-05-01.swift`
- Create: `docs/PROJECT_CONTEXT.md`
- Modify: `docs/WORK_LOG.md`
- Modify: `docs/TROUBLESHOOTING.md`
- Modify: `docs/superpowers/plans/2026-08-10-ch1-reality-escape-implementation.md`

**Interfaces:**
- Produces: Chapter 1 DocC that teaches the C3 closed world, camera-driven failure to hide, camera-permission transition, LiDAR mesh occlusion, and physical rediscovery.
- Produces: Git-tracked shared context with actual automated and manual verification evidence, without claimed real-device results until they were observed.

- [ ] **Step 1: DocC snippets가 새 코드 계약을 설명하도록 실패 검증을 준비한다.**

Replace each existing room/fake-sofa snippet with a compilable focused excerpt: state gate, C3 named tree and model container, tree hide calculation/discovery reaction, `ARWorldTrackingConfiguration` + scene understanding options, and real mesh reveal monitor. Each snippet must define all names it uses inside the snippet or import them from the adjacent snippet's declared context.

Run:

```bash
cd PiggyEscape
tuist generate --no-open
xcodebuild docbuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/piggyescape-reality-docc
```

Expected before updating snippets: DocC content still describes room/fake sofa and no longer matches the running app, even if `docbuild` technically succeeds.

- [ ] **Step 2: 튜토리얼을 다섯 장면으로 다시 작성한다.**

Use this exact tutorial progression:

```text
1. C3가 이미 만든 섬과 궤도 카메라를 SceneKit에 놓는다.
2. 돼지는 나무 뒤로 가지만 사용자가 카메라를 돌리면 다시 보인다.
3. 놀란 돼지와 자막 뒤 시스템 카메라 권한이 전환점이 된다.
4. RealityKit은 LiDAR 메쉬와 수직 면 탭으로 실제 물체의 반대편을 계산한다.
5. 실제 깊이 오클루전이 돼지를 가리고, 사용자가 몸을 움직여 다시 찾아낸다.
```

Explain that `sceneReconstruction = .meshWithClassification` is guarded by `supportsSceneReconstruction`, and explain `.occlusion` as depth-only use of reconstructed geometry. Link the primary Apple documentation URLs already listed in the design spec; do not copy third-party descriptions.

- [ ] **Step 3: shared Markdown을 실제 상태로 갱신한다.**

Create `docs/PROJECT_CONTEXT.md` by reconciling the root workspace's collaboration rules with this branch's newer approved `reality-escape` design: the current approved scope is this C3→RealityKit Chapter 1 experience, the Draft PR remains the baseline, and Task 8 manual LiDAR verification is not completed until observed. In `docs/TROUBLESHOOTING.md`, record only observed limitations: ARKit cannot perform physical mesh occlusion in Simulator; camera permission can only be fully checked on device; and `ARView` screen scaling is deliberately not a lens/FOV change. In `docs/WORK_LOG.md`, state exact test commands and the remaining manual checks.

- [ ] **Step 4: 전체 자동 검증과 DocC 빌드를 실행한다.**

Run:

```bash
cd PiggyEscape
tuist generate --no-open
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/piggyescape-reality-tests test
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/piggyescape-reality-build build
xcodebuild docbuild -project PiggyEscape.xcodeproj -scheme PiggyEscape \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/piggyescape-reality-docc
```

Expected: all XCTest cases pass, build succeeds, and DocC produces `SceneKitToRealityKit.doccarchive` under `/tmp/piggyescape-reality-docc`.

- [ ] **Step 5: LiDAR 실기기에서 수동 수용 검증을 수행한다.**

Use the physical LiDAR-capable iPhone to verify this exact checklist, recording pass/fail and device/OS in `docs/WORK_LOG.md` only after observation.

```text
[ ] 앱 시작 시 C3 섬·기존 나무·초기 나레이션이 보인다.
[ ] 초기 나레이션이 끝나기 전 돼지 탭은 무시된다.
[ ] 탭 후 걷는 돼지가 나무의 현재 카메라 반대편으로 이동한다.
[ ] 카메라를 0.70 rad 이상 돌려 돼지가 보일 때 놀란 모델·자막·1.5배 확대 후 복귀가 한 번 실행된다.
[ ] 페이드 뒤 시스템 카메라 권한 문구가 표시되고, 허용 뒤 AR 스캔 안내가 열린다.
[ ] 실제 물체의 수직 옆면을 탭하면 돼지가 반대편 바닥으로 걸어간다.
[ ] 초기 시점에서 실제 물체의 LiDAR 메쉬가 돼지를 가린다.
[ ] 사용자가 실제로 옆으로 이동해 돼지를 다시 볼 때 놀란 모델·자막·1.5배 확대·1.12배 화면 확대가 한 번 실행되고 복귀한다.
[ ] 권한 거부, LiDAR 미지원, 수평면 탭, 너무 가까운 탭, 바닥 추적 부족은 각각 안내와 복구 경로를 보인다.
```

- [ ] **Step 6: 최종 인수인계를 기록하고 커밋한다.**

Only stage source-controlled Markdown and tutorial source files; never stage `/tmp` outputs or `.claude/`.

```bash
git add PiggyEscape/PiggyEscape/Tutorials docs/PROJECT_CONTEXT.md docs/WORK_LOG.md \
  docs/TROUBLESHOOTING.md docs/superpowers/plans/2026-08-10-ch1-reality-escape-implementation.md
git commit -m "Document C3 to RealityKit escape tutorial"
```

---

## Final Review Checklist

- [ ] `ContentView` starts only `EscapeRootView`; it does not instantiate the old room/fake-sofa view.
- [ ] Every C3 asset in the Global Constraints list matches the local C3 source with `cmp`.
- [ ] No imported source references `SwiftData`, `WatchConnectivity`, `Allowance`, `Ledger`, `balance`, or `GoldenPiggy`.
- [ ] SceneKit discovery requires real camera yaw/frustum conditions, not a timer.
- [ ] Both discovery scenes use the same surprised model, caption, 1.5 peak scale, and 1.0 restore scale.
- [ ] RealityKit uses actual mesh reconstruction with `.occlusion` and `.collision`, not a colored proxy wall.
- [ ] RealityKit rediscovery waits for at least one blocked mesh observation and fires once only.
- [ ] Full XCTest, build, DocC build, and manual LiDAR results are recorded with their actual outcomes.
- [ ] Every task has an updated `docs/WORK_LOG.md` entry and a commit without authorship markers.
