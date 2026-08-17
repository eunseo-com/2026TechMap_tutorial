# C3 Automatic Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make C3 advance from the tree walk to the existing surprise and RealityKit permission transition without a camera pan.

**Architecture:** `C3ClosedWorld` emits one tree-arrival boundary. `C3ClosedWorldSceneView.Coordinator` owns the cancellable 0.40-second delay and then invokes a guarded automatic discovery. `EscapeRootView` keeps its existing surprise callback, 0.70-second fade, and one-shot camera request.

**Tech Stack:** Swift 6, SwiftUI, SceneKit, XCTest, Tuist/Xcode.

## Global Constraints

- Preserve the existing running walk, surprised asset, Korean subtitle, and 1.5→1.0 reaction.
- Tree arrival is the sole automatic discovery trigger; yaw/frustum no longer advances the story.
- Wait exactly 0.40 seconds, discover at most once, and cancel the wait when the C3 view is dismantled.
- Do not change the root permission sequence or RealityKit behavior.
- Do not stage `.claude/` or generated Xcode files. Record failures in `docs/LEARNING_LOG.md` and the verified result in `docs/WORK_LOG.md`.

---

### Task 1: Trigger C3 discovery after the tree walk

**Files:**

- Modify: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/ClosedWorldEscapeTests.swift`
- Modify: `docs/WORK_LOG.md`
- Modify only after a real failure: `docs/LEARNING_LOG.md`

**Interfaces:**

- `C3ClosedWorld` produces `var onTreeHideFinished: (() -> Void)?` and `@discardableResult func automaticallyDiscoverAfterTreeHide() -> Bool`.
- `C3ClosedWorldSceneView.Coordinator` consumes that callback and owns `autoDiscoveryTask: Task<Void, Never>?`.
- `EscapeRootCoordinator.closedWorldDiscoveryDidOccur()` remains the receiver of the existing surprise callback.

- [ ] **Step 1: Write the failing behavior tests**

Add these tests to `ClosedWorldEscapeTests` before production edits:

```swift
func test_treeArrivalNotifiesTheAutomaticProgressBoundaryOnce() {
    let world = C3ClosedWorld()
    var count = 0
    world.onTreeHideFinished = { count += 1 }
    world.completeOpeningNarration()
    XCTAssertTrue(world.tapPig())
    world.finishTreeHideForTesting()
    world.finishTreeHideForTesting()
    XCTAssertEqual(count, 1)
}

func test_treeArrivalAutomaticallyDiscoversWithoutCameraRotationOnlyOnce() {
    let world = C3ClosedWorld()
    world.completeOpeningNarration()
    XCTAssertTrue(world.tapPig())
    world.finishTreeHideForTesting()
    XCTAssertTrue(world.automaticallyDiscoverAfterTreeHide())
    XCTAssertEqual(world.currentPose, .surprised)
    XCTAssertEqual(world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
    XCTAssertFalse(world.automaticallyDiscoverAfterTreeHide())
}

func test_autoAdvanceDelayIsFourTenthsOfASecond() {
    XCTAssertEqual(C3AutoAdvance.treeArrivalDelay, 0.40, accuracy: 0.0001)
}
```

- [ ] **Step 2: Verify RED**

Run `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests test`.

Expected: compile fails because the callback, automatic discovery method, and delay constant do not exist.

- [ ] **Step 3: Add the minimum implementation**

In `C3ClosedWorld`, add:

```swift
enum C3AutoAdvance {
    static let treeArrivalDelay: TimeInterval = 0.40
}

var onTreeHideFinished: (() -> Void)?

@discardableResult
func automaticallyDiscoverAfterTreeHide() -> Bool {
    guard experience.state == .hiddenInClosedWorld,
          !hasDiscovered,
          experience.send(.closedWorldPigDiscovered) else { return false }
    hasDiscovered = true
    performSurpriseReaction()
    return true
}
```

After `finishTreeHide()` enters `hiddenInClosedWorld`, call `onTreeHideFinished?()` once. Delete the obsolete yaw/frustum discovery path. In the scene coordinator, weakly capture self in `onTreeHideFinished`, cancel any prior task, wait `C3AutoAdvance.treeArrivalDelay`, then call `world.automaticallyDiscoverAfterTreeHide()`. Cancel that task in `deinit` and `dismantleUIView`; remove the pan handler's discovery call.

- [ ] **Step 4: Verify GREEN**

Run the Step 2 command again. All focused C3 tests pass, including discovery without camera rotation.

- [ ] **Step 5: Verify the whole app**

Run these commands from `PiggyEscape`:

```bash
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-auto-progress-tests test
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-auto-progress-build build
```

Expected: zero XCTest failures and `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Record and commit**

Update `docs/WORK_LOG.md` with tap → tree arrival → automatic surprise/fade/permission and the exact verification result. Keep physical camera permission and LiDAR checks marked `실기기 대기`. Commit only tracked source, tests, and documentation with `Advance C3 escape after tree hide`.
