# Verified RealityKit Hiding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Piggy behind a selected real object and show the find-Piggy guidance only after mesh occlusion is verified.

**Architecture:** Keep target planning in `RealityHidePlanner`, then give the coordinator a pure, bounded occlusion-verification policy after every walking completion. The coordinator obtains the real mesh distance from `ARView`, passes only distance data to the policy, and emits the existing reached callback only for a verified hidden result. Temporary physical-device camera diagnostic launch modes are removed after the regular flow retains its regression tests.

**Tech Stack:** Swift 6, SwiftUI, ARKit, RealityKit, XCTest, iOS 17.

## Global Constraints

- Keep the C3 world→RealityKit automatic transition and the iPhone 16 Pro camera fix intact: do not attach the Piggy world anchor while scanning; attach it once only after a valid target is accepted.
- A vertical real-world mesh hit and verified floor remain prerequisites for a hide attempt.
- Use the existing 0.03 m mesh-distance safety margin for occlusion.
- Retry only along the selected surface's camera-opposite horizontal direction, with bounded distance and attempts.
- Do not send `onPigReachedTarget` or enter `hiddenInReality` until a mesh hit is closer than Piggy by the safety margin.
- On retry exhaustion, disable Piggy, return to `waitingForTarget`, and show `RealityAvailabilityMessage.scanFirst`.
- Do not add new assets, fonts, financial state, Watch functionality, or a LiDAR fallback.
- Record the physical diagnosis, failed commands, verification results, and remaining iPhone 16 Pro checks in `docs/LEARNING_LOG.md` and `docs/WORK_LOG.md`; do not stage `.claude/`.

---

### Task 1: Pure post-walk occlusion policy

**Files:**
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift`

**Interfaces:**
- Consumes: existing `RealityHidePlanner.objectClearance` and the existing 0.03 m mesh margin used by `RealityRevealMonitor`.
- Produces: `RealityHideAttempt`, `RealityHideVerificationDecision`, and `RealityHideVerificationPolicy.decide(meshDistance:pigDistance:attempt:)` for the AR coordinator.

- [ ] **Step 1: Write the failing policy tests**

```swift
func test_verifiedMeshOcclusionCompletesTheHideAttempt() {
    let attempt = RealityHideAttempt(
        destination: SIMD3(0, 0, -1),
        retreatDirection: SIMD3(0, 0, -1),
        retryCount: 0
    )

    XCTAssertEqual(
        RealityHideVerificationPolicy.decide(
            meshDistance: 0.7,
            pigDistance: 1.0,
            attempt: attempt
        ),
        .hidden
    )
}

func test_unoccludedPigRetriesOnlyTowardTheObjectBackSide() {
    let attempt = RealityHideAttempt(
        destination: SIMD3(0, 0, -1),
        retreatDirection: SIMD3(0, 0, -1),
        retryCount: 0
    )

    XCTAssertEqual(
        RealityHideVerificationPolicy.decide(
            meshDistance: nil,
            pigDistance: 1.0,
            attempt: attempt
        ),
        .retry(RealityHideAttempt(
            destination: SIMD3(0, 0, -1.18),
            retreatDirection: SIMD3(0, 0, -1),
            retryCount: 1
        ))
    )
}

func test_unoccludedPigRequiresNewTargetAfterTheBoundedRetries() {
    let finalAttempt = RealityHideAttempt(
        destination: SIMD3(0, 0, -1.36),
        retreatDirection: SIMD3(0, 0, -1),
        retryCount: 2
    )

    XCTAssertEqual(
        RealityHideVerificationPolicy.decide(
            meshDistance: nil,
            pigDistance: 1.4,
            attempt: finalAttempt
        ),
        .selectAnotherTarget
    )
}
```

- [ ] **Step 2: Run the focused policy tests to verify RED**

Run:

```bash
cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests test
```

Expected: test-target compilation fails because `RealityHideAttempt`, `RealityHideVerificationDecision`, and `RealityHideVerificationPolicy` do not exist.

- [ ] **Step 3: Implement the smallest pure policy**

```swift
struct RealityHideAttempt: Equatable {
    let destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let retryCount: Int
}

enum RealityHideVerificationDecision: Equatable {
    case hidden
    case retry(RealityHideAttempt)
    case selectAnotherTarget
}

enum RealityHideVerificationPolicy {
    static let meshSafetyMargin: Float = 0.03
    static let retryDistance: Float = 0.18
    static let maximumRetries = 2

    static func decide(
        meshDistance: Float?,
        pigDistance: Float,
        attempt: RealityHideAttempt
    ) -> RealityHideVerificationDecision {
        if let meshDistance, meshDistance + meshSafetyMargin < pigDistance {
            return .hidden
        }
        guard attempt.retryCount < maximumRetries else { return .selectAnotherTarget }
        return .retry(RealityHideAttempt(
            destination: attempt.destination + attempt.retreatDirection * retryDistance,
            retreatDirection: attempt.retreatDirection,
            retryCount: attempt.retryCount + 1
        ))
    }
}
```

- [ ] **Step 4: Run the focused policy tests to verify GREEN**

Run the Step 2 command.

Expected: `RealityHidePlannerTests` passes with 0 failures.

- [ ] **Step 5: Commit the policy and tests**

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityHidePlanner.swift PiggyEscape/PiggyEscapeTests/RealityHidePlannerTests.swift
git commit -m 'Add RealityKit hide verification policy'
```

### Task 2: Gate the RealityKit reached callback on mesh occlusion

**Files:**
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift`

**Interfaces:**
- Consumes: `RealityHideAttempt`, `RealityHideVerificationPolicy.decide(meshDistance:pigDistance:attempt:)`, existing `RealityPigVisualController.walk(to:completion:)`, and the existing scene attachment gate.
- Produces: a `RealityHideARView.Coordinator` that sends `onPigReachedTarget` exactly once only after `.hidden`.

- [ ] **Step 1: Write coordinator RED tests for the callback boundary**

```swift
func test_movementCompletionDoesNotReachTheTargetUntilMeshOccludesPiggy() {
    let loader = ControlledRealityEntityLoader()
    let visualController = RealityPigVisualController.makeForTesting(entityLoader: loader.load)
    var reachedCount = 0
    let coordinator = RealityHideARView.Coordinator(
        meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
        visualController: visualController,
        onPigReachedTarget: { reachedCount += 1 }
    )

    coordinator.acceptHideTarget(
        destination: SIMD3(0, 0, -1),
        initialPosition: SIMD3(0, 0, -0.44)
    )
    loader.succeedNext()
    loader.succeedNext()

    coordinator.processHideArrival(meshDistance: nil, pigDistance: 1.0)

    XCTAssertEqual(reachedCount, 0)
    XCTAssertEqual(coordinator.status, .walking)
}

func test_verifiedHideArrivalReachesTheTargetOnce() {
    let coordinator = makeCoordinatorWithCompletedWalk()

    coordinator.processHideArrival(meshDistance: 0.7, pigDistance: 1.0)
    coordinator.processHideArrival(meshDistance: 0.7, pigDistance: 1.0)

    XCTAssertEqual(reachedCount, 1)
    XCTAssertEqual(coordinator.status, .hidden)
}

func test_failedHideVerificationReturnsToTargetSelectionAfterBoundedRetries() {
    let coordinator = makeCoordinatorWithCompletedWalk()

    coordinator.processHideArrival(meshDistance: nil, pigDistance: 1.0)
    completePendingRetryWalk()
    coordinator.processHideArrival(meshDistance: nil, pigDistance: 1.0)
    completePendingRetryWalk()
    coordinator.processHideArrival(meshDistance: nil, pigDistance: 1.0)

    XCTAssertEqual(coordinator.status, .waitingForTarget)
    XCTAssertFalse(visualController.outerEntity.isEnabled)
}
```

- [ ] **Step 2: Run the focused coordinator tests to verify RED**

Run:

```bash
cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test
```

Expected: test-target compilation fails because `processHideArrival(meshDistance:pigDistance:)` does not exist.

- [ ] **Step 3: Integrate one attempt at a time**

```swift
private var hideAttempt: RealityHideAttempt?

private func finishWalking(_ attempt: RealityHideAttempt) {
    guard let arView else {
        return recoverFromUnverifiedHide()
    }
    let pigPosition = visualController.worldPosition
    let cameraPosition = Self.position(from: arView.session.currentFrame!.camera.transform)
    let pigDistance = simd_distance(cameraPosition, pigPosition)
    let meshDistance = arView.hitTest(
        from: cameraPosition,
        to: pigPosition,
        query: .nearest,
        mask: .sceneUnderstanding
    ).first.map { simd_distance(cameraPosition, $0.position) }
    processHideArrival(meshDistance: meshDistance, pigDistance: pigDistance)
}

func processHideArrival(meshDistance: Float?, pigDistance: Float) {
    guard status == .walking, let hideAttempt else { return }
    switch RealityHideVerificationPolicy.decide(
        meshDistance: meshDistance,
        pigDistance: pigDistance,
        attempt: hideAttempt
    ) {
    case .hidden:
        status = .hidden
        onPigReachedTarget()
        if let arView {
            beginRevealMonitoring(in: arView)
        }
    case let .retry(nextAttempt):
        hideAttempt = nextAttempt
        walkPiggy(to: nextAttempt.destination)
    case .selectAnotherTarget:
        recoverFromUnverifiedHide()
    }
}
```

`acceptHideTarget` must initialize `hideAttempt` with the first destination and a normalized horizontal `destination - initialPosition` direction. `walkPiggy(to:)` must use the existing running→idle completion and call `finishWalking(_:)`; it must not call `onPigReachedTarget` directly. `recoverFromUnverifiedHide()` must reset the attempt, disable the outer entity, set `.waitingForTarget`, and send `RealityAvailabilityMessage.scanFirst`.

- [ ] **Step 4: Run the focused coordinator tests to verify GREEN**

Run the Step 2 command.

Expected: all `RealityHideARViewCoordinatorTests` pass with 0 failures, including the existing attachment-gate and reveal-monitor tests.

- [ ] **Step 5: Commit the coordinator integration and tests**

```bash
git add PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift
git commit -m 'Verify RealityKit hiding before discovery'
```

### Task 3: Remove temporary diagnostics and record the physical verification boundary

**Files:**
- Modify: `PiggyEscape/PiggyEscape/Sources/ContentView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/PiggyEscapeTests.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityCapability.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityCapabilityTests.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift`
- Modify: `PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift`
- Modify: `docs/LEARNING_LOG.md`
- Modify: `docs/WORK_LOG.md`

**Interfaces:**
- Consumes: the verified hide callback from Task 2 and the existing `EscapeRootCoordinator.realityPigDidReachTarget()` state boundary.
- Produces: normal `ContentView` launch behavior with no private diagnostic modes, current learning records, and a physically testable iPhone 16 Pro checklist.

- [ ] **Step 1: Restore the single production launch path and remove obsolete diagnostic tests**

```swift
struct ContentView: View {
    var body: some View {
        EscapeRootView()
            .ignoresSafeArea()
    }
}
```

Remove private diagnostic AR views, launch arguments, and the temporary diagnostic-only assertions from `ContentView.swift` and `PiggyEscapeTests.swift`. Preserve only the production session-start gate, one-time scene-attachment gate, AR session messages, and their tests. The regular root and AR coordinator tests remain the production launch regression coverage. Keep the verified 0.35 m temporary physical height only until the separate object-relative scaling design is approved; do not claim it matches a selected real object.

- [ ] **Step 2: Update handoff and learning records**

Add a new `LEARNING_LOG.md` entry that records the failed worktree `git fetch --prune origin`, the iPhone 16 Pro black-camera isolation ladder, the conclusion boundary, and the remaining unverified physical hide behavior. Update the first `WORK_LOG.md` handoff entry and checklist so camera display is marked observed, while object-relative scale, visible walking, mesh-verified hiding, and re-discovery remain `실기기 대기` until observed.

- [ ] **Step 3: Run complete automated verification**

Run:

```bash
cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests -only-testing:PiggyEscapeTests/PiggyEscapeTests test
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-verified-hide-tests test
xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-verified-hide-build build
```

Expected: focused tests and complete XCTest report 0 failures; Simulator build reports `BUILD SUCCEEDED`.

- [ ] **Step 4: Install and observe on iPhone 16 Pro**

Run the signed device build, install it with `xcrun devicectl`, then observe in this order: camera background appears; tapping a vertical real object first shows a visible running Piggy; only a mesh-occluded Piggy changes guidance to “직접 움직여서 피기를 찾아봐.”; retry exhaustion returns to scan guidance. Record each observed result without treating the Simulator as a substitute.

- [ ] **Step 5: Commit the cleanup, documentation, and verification evidence**

```bash
git add PiggyEscape/PiggyEscape/Sources/ContentView.swift PiggyEscape/PiggyEscapeTests/PiggyEscapeTests.swift PiggyEscape/PiggyEscape/Sources/Reality/RealityCapability.swift PiggyEscape/PiggyEscapeTests/RealityCapabilityTests.swift PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift PiggyEscape/PiggyEscape/Sources/Reality/RealityPigVisualController.swift PiggyEscape/PiggyEscapeTests/RealityPigVisualControllerTests.swift docs/LEARNING_LOG.md docs/WORK_LOG.md
git commit -m 'Clean up RealityKit camera diagnostics'
```
