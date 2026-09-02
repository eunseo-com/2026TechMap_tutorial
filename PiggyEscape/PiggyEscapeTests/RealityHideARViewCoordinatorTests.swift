import Combine
import RealityKit
import XCTest
import simd
@testable import PiggyEscape

@MainActor
final class RealityHideARViewCoordinatorTests: XCTestCase {
    func test_pigSceneAttachmentWaitsForAnAcceptedTargetAndRunsOnce() {
        var gate = RealityPigSceneAttachmentGate()

        XCTAssertFalse(gate.consumeIfReady(hasAcceptedTarget: false))
        XCTAssertTrue(gate.consumeIfReady(hasAcceptedTarget: true))
        XCTAssertFalse(gate.consumeIfReady(hasAcceptedTarget: true))
    }

    func test_sessionStartGateWaitsForLaidOutARViewAndStartsOnce() {
        var gate = RealityARSessionStartGate()
        let containerBounds = CGRect(x: 0, y: 0, width: 390, height: 844)

        XCTAssertFalse(gate.consumeIfReady(hasWindow: false, containerBounds: containerBounds, arViewBounds: containerBounds))
        XCTAssertFalse(gate.consumeIfReady(hasWindow: true, containerBounds: containerBounds, arViewBounds: .zero))
        XCTAssertTrue(gate.consumeIfReady(hasWindow: true, containerBounds: containerBounds, arViewBounds: containerBounds))
        XCTAssertFalse(gate.consumeIfReady(hasWindow: true, containerBounds: containerBounds, arViewBounds: containerBounds))
    }

    func test_coordinatorReportsUnavailableWithoutStartingARSession() {
        var unavailableCount = 0
        var lastMessage: String?
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: false),
            onUnavailable: { unavailableCount += 1 },
            onMessage: { lastMessage = $0 }
        )

        XCTAssertFalse(coordinator.canStartMeshSession)
        XCTAssertFalse(coordinator.startMeshSessionIfSupported())
        XCTAssertFalse(coordinator.didStartMeshSession)
        XCTAssertEqual(unavailableCount, 1)
        XCTAssertEqual(lastMessage, RealityAvailabilityMessage.unavailable)
    }

    func test_hideRejectionsMapToTheApprovedGuidance() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true)
        )

        XCTAssertEqual(coordinator.message(for: .selectVerticalSide), RealityAvailabilityMessage.selectVerticalSide)
        XCTAssertEqual(coordinator.message(for: .moveFartherAway), RealityAvailabilityMessage.moveFartherAway)
        XCTAssertEqual(coordinator.message(for: .findFloor), RealityAvailabilityMessage.scanFirst)
    }

    func test_scanningReadinessRequiresBothMeshAndClassifiedFloorBeforeReportingOnce() {
        var readyCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            onScanningReady: { readyCount += 1 }
        )

        XCTAssertFalse(coordinator.processScanningObservation(hasMesh: false, hasFloor: false))
        XCTAssertEqual(readyCount, 0)
        XCTAssertFalse(coordinator.processScanningObservation(hasMesh: true, hasFloor: false))
        XCTAssertEqual(readyCount, 0)
        XCTAssertTrue(coordinator.processScanningObservation(hasMesh: false, hasFloor: true))
        XCTAssertEqual(readyCount, 1)
        XCTAssertFalse(coordinator.processScanningObservation(hasMesh: true, hasFloor: true))
        XCTAssertEqual(readyCount, 1)
    }

    func test_preparingModeRejectsTargetSelectionWithoutChangingStatus() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true)
        )
        coordinator.interactionMode = .preparing

        XCTAssertFalse(coordinator.processTargetSelection(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        ))
        XCTAssertEqual(coordinator.status, .waitingForTarget)
    }

    func test_selectingTargetModeAcceptsOneTargetThenLocksFurtherSelections() {
        var acceptedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            onTargetAccepted: { acceptedCount += 1 }
        )
        coordinator.interactionMode = .selectingTarget

        XCTAssertTrue(coordinator.processTargetSelection(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        ))
        XCTAssertFalse(coordinator.processTargetSelection(
            destination: SIMD3(0, 0, -2),
            initialPosition: SIMD3(0, 0, -1.44)
        ))
        XCTAssertEqual(acceptedCount, 1)
        XCTAssertEqual(coordinator.status, .verifyingOcclusion)
    }

    func test_revealIsReportedOnceAfterStableHideAndViewpointChange() {
        var revealCount = 0
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            onRevealed: { revealCount += 1 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        recordStableHide(in: coordinator, referencePose: blockedPose)

        XCTAssertFalse(coordinator.processRevealObservation(observation(
            timestamp: 3,
            states: visibleSamples(),
            pose: blockedPose
        )))
        XCTAssertFalse(coordinator.processRevealObservation(observation(
            timestamp: 4,
            states: visibleSamples(),
            pose: movedPose
        )))
        XCTAssertTrue(coordinator.processRevealObservation(observation(
            timestamp: 5,
            states: visibleSamples(),
            pose: movedPose
        )))
        XCTAssertFalse(coordinator.processRevealObservation(observation(
            timestamp: 6,
            states: visibleSamples(),
            pose: movedPose
        )))
        XCTAssertEqual(revealCount, 1)
        XCTAssertEqual(visualController.currentPose, .surprised)
        XCTAssertEqual(visualController.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(visualController.surpriseRestoreScale, 1.0, accuracy: 0.0001)
    }

    func test_reduceMotionRevealChangesPoseWithoutPlayingThePigScalePulse() {
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            scanPresentation: RealityScanPresentation(
                showsSceneUnderstanding: false,
                reduceMotion: true
            )
        )
        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -2),
            initialPosition: SIMD3(0, 0, -0.8)
        )
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        recordStableHide(in: coordinator, referencePose: blockedPose)

        XCTAssertFalse(coordinator.processRevealObservation(observation(
            timestamp: 3,
            states: visibleSamples(),
            pose: movedPose
        )))
        XCTAssertTrue(coordinator.processRevealObservation(observation(
            timestamp: 4,
            states: visibleSamples(),
            pose: movedPose
        )))
        XCTAssertEqual(visualController.currentPose, .surprised)
        XCTAssertEqual(visualController.surprisePeakScale, 1, accuracy: 0.0001)
        XCTAssertEqual(visualController.surpriseRestoreScale, 1, accuracy: 0.0001)
    }

    func test_markerOnlyShowsForAnAcceptedSelectionAndCancelsWithItsCycle() {
        let marker = TrackingAcceptedSurfaceMarker()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            acceptedSurfaceMarker: marker
        )
        let plan = makeHidePlan(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.4)
        )
        let hit = RealitySurfaceHit(point: SIMD3(0, 0.4, -0.7), normal: SIMD3(0, 0, 1))

        XCTAssertFalse(coordinator.processTargetSelection(plan: plan, acceptedHit: hit))
        XCTAssertEqual(marker.showCount, 0)

        coordinator.interactionMode = .selectingTarget
        XCTAssertTrue(coordinator.processTargetSelection(plan: plan, acceptedHit: hit))
        XCTAssertEqual(marker.showCount, 1)
        XCTAssertEqual(marker.lastPoint, hit.point)
        XCTAssertEqual(marker.lastNormal, hit.normal)

        coordinator.restartHideCycle()
        XCTAssertEqual(marker.cancelCount, 1)
    }

    func test_invalidRevealObservationResetsVisibleStabilityButKeepsTheBlockingPose() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockingPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        recordStableHide(in: coordinator, referencePose: blockingPose)

        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 3, states: visibleSamples(), pose: movedPose)))
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 4, states: invalidSamples(), pose: movedPose)))
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 5, states: visibleSamples(), pose: movedPose)))
        XCTAssertTrue(coordinator.processRevealObservation(observation(timestamp: 6, states: visibleSamples(), pose: movedPose)))
    }

    func test_invalidSampleDoesNotCountAsAVisibleFrame() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        recordStableHide(in: coordinator, referencePose: blockedPose)

        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 3, states: invalidSamples(), pose: movedPose)))
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 4, states: visibleSamples(), pose: movedPose)))
        XCTAssertTrue(coordinator.processRevealObservation(observation(timestamp: 5, states: visibleSamples(), pose: movedPose)))
    }

    func test_projectionGateRequiresOnscreenPointAndPigInFrontOfCamera() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 400)
        let cameraTransform = matrix_identity_float4x4

        XCTAssertTrue(RealityProjectionGate.canObserve(
            projectedPoint: CGPoint(x: 100, y: 200),
            viewportBounds: bounds,
            pigPosition: SIMD3(0, 0, -2),
            cameraTransform: cameraTransform
        ))
        XCTAssertFalse(RealityProjectionGate.canObserve(
            projectedPoint: CGPoint(x: 250, y: 200),
            viewportBounds: bounds,
            pigPosition: SIMD3(0, 0, -2),
            cameraTransform: cameraTransform
        ))
        XCTAssertFalse(RealityProjectionGate.canObserve(
            projectedPoint: CGPoint(x: 100, y: 200),
            viewportBounds: bounds,
            pigPosition: SIMD3(0, 0, 2),
            cameraTransform: cameraTransform
        ))
        XCTAssertFalse(RealityProjectionGate.canObserve(
            projectedPoint: nil,
            viewportBounds: bounds,
            pigPosition: SIMD3(0, 0, -2),
            cameraTransform: cameraTransform
        ))
    }

    func test_targetAcceptedAndReachedCallbacksAreSeparatedByMovementCompletion() {
        typealias Completion = (Result<Entity, Error>) -> Void
        var pendingLoads: [(asset: String, completion: Completion)] = []
        let visualController = RealityPigVisualController.makeForTesting { asset, completion in
            pendingLoads.append((asset, completion))
            return nil
        }
        var events: [String] = []
        var revealCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            onTargetAccepted: { events.append("accepted") },
            onMovementFinished: { events.append("moved") },
            onPigReachedTarget: { events.append("reached") },
            onRevealed: { revealCount += 1 }
        )

        XCTAssertFalse(visualController.outerEntity.isEnabled)
        coordinator.acceptHideTarget(
            destination: SIMD3(0.6, 0, -1.7),
            initialPosition: SIMD3(0, 0, -0.8)
        )

        XCTAssertTrue(visualController.outerEntity.isEnabled)
        XCTAssertEqual(visualController.worldPosition.y, 0, accuracy: 0.0001)
        XCTAssertEqual(events, ["accepted"])
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 1, states: visibleSamples(), pose: movedPose)))
        XCTAssertEqual(revealCount, 0)

        let runningLoad = pendingLoads.removeFirst()
        XCTAssertEqual(runningLoad.asset, "Piggy_running")
        runningLoad.completion(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        XCTAssertEqual(events, ["accepted"])

        let idleLoad = pendingLoads.removeFirst()
        XCTAssertEqual(idleLoad.asset, "Piggy")
        idleLoad.completion(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        XCTAssertEqual(events, ["accepted", "moved"])

        recordStableHide(in: coordinator, referencePose: blockedPose)
        XCTAssertEqual(events, ["accepted", "moved", "reached"])

        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 3, states: visibleSamples(), pose: movedPose)))
        XCTAssertTrue(coordinator.processRevealObservation(observation(timestamp: 4, states: visibleSamples(), pose: movedPose)))
        XCTAssertEqual(revealCount, 0)
        let surprisedLoad = pendingLoads.removeFirst()
        XCTAssertEqual(surprisedLoad.asset, "Piggy_surprised")
        surprisedLoad.completion(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        XCTAssertEqual(revealCount, 1)
    }

    func test_runningLoadFailureReturnsToRetryableWaitingStateAndReportsError() {
        let loader = ControlledRealityEntityLoader()
        let visualController = RealityPigVisualController.makeForTesting(entityLoader: loader.load)
        var errorCount = 0
        var messages: [String] = []
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            onError: { errorCount += 1 },
            onMessage: { messages.append($0) }
        )

        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1), initialPosition: SIMD3(0, 0, -0.2))
        XCTAssertEqual(coordinator.status, .walking)
        loader.failNext()

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
        XCTAssertEqual(errorCount, 1)
        XCTAssertEqual(messages, [RealityAvailabilityMessage.pigAssetLoadFailed])
        XCTAssertEqual(RealityAvailabilityMessage.pigAssetLoadFailed, "돼지를 불러오지 못했어. 잠시 후 다시 시도해줘.")
    }

    func test_idleLoadFailureAfterMovementReturnsToRetryableWaitingState() {
        let loader = ControlledRealityEntityLoader()
        let visualController = RealityPigVisualController.makeForTesting(entityLoader: loader.load)
        var errorCount = 0
        var reachedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            onPigReachedTarget: { reachedCount += 1 },
            onError: { errorCount += 1 }
        )

        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1), initialPosition: SIMD3(0, 0, -0.2))
        loader.succeedNext()
        XCTAssertEqual(coordinator.status, .walking)
        loader.failNext()

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
        XCTAssertEqual(reachedCount, 0)
        XCTAssertEqual(errorCount, 1)
    }

    func test_surprisedLoadFailureTearsDownTheCycleWithoutRetryingInTheBackground() {
        let loader = ControlledRealityEntityLoader()
        let visualController = RealityPigVisualController.makeForTesting(entityLoader: loader.load)
        var errorCount = 0
        var revealCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            onRevealed: { revealCount += 1 },
            onError: { errorCount += 1 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1), initialPosition: SIMD3(0, 0, -0.2))
        loader.succeedNext()
        loader.succeedNext()
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.16, 0, 0), forward: SIMD3(0, 0, -1))
        recordStableHide(in: coordinator, referencePose: blockedPose)
        XCTAssertEqual(coordinator.status, .hidden)

        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 3, states: visibleSamples(), pose: movedPose)))
        XCTAssertTrue(coordinator.processRevealObservation(observation(timestamp: 4, states: visibleSamples(), pose: movedPose)))
        XCTAssertEqual(coordinator.status, .revealing)
        loader.failNext()

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertFalse(coordinator.hasActiveHideCycle)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
        XCTAssertEqual(revealCount, 0)
        XCTAssertEqual(errorCount, 1)
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 5, states: visibleSamples(), pose: movedPose)))
        XCTAssertFalse(coordinator.processRevealObservation(observation(timestamp: 6, states: visibleSamples(), pose: movedPose)))
    }

    func test_hideMovementDoesNotReachTheTargetUntilMeshOcclusionIsVerified() {
        var reachedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 },
            onPigReachedTarget: { reachedCount += 1 }
        )

        coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        )
        _ = coordinator.processHideObservation(observation(
            timestamp: 1,
            states: visibleSamples(),
            pose: RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        ), now: 0.1)

        XCTAssertEqual(reachedCount, 0)
        XCTAssertEqual(coordinator.status, .verifyingOcclusion)
    }

    func test_centerOnlyOcclusionCannotCompleteHideVerification() {
        var reachedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 },
            onPigReachedTarget: { reachedCount += 1 }
        )
        let pose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let centerOnly: [PigOcclusionSampleID: OcclusionSampleState] = [
            .center: .blocked,
            .top: .visible,
            .bottom: .visible,
            .left: .visible,
            .right: .visible
        ]

        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        )

        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 1, states: centerOnly, pose: pose),
            now: 0.1
        ), .waiting)
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 2, states: centerOnly, pose: pose),
            now: 0.2
        ), .waiting)
        XCTAssertEqual(coordinator.status, .verifyingOcclusion)
        XCTAssertEqual(reachedCount, 0)
    }

    func test_duplicateFrameTimestampCannotCompleteStableHide() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 }
        )
        let pose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        )

        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 1, states: hiddenSamples(), pose: pose),
            now: 0.1
        ), .waiting)
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 1, states: hiddenSamples(), pose: pose),
            now: 0.2
        ), .waiting)
        XCTAssertEqual(coordinator.status, .verifyingOcclusion)
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 2, states: hiddenSamples(), pose: pose),
            now: 0.3
        ), .hidden(referencePose: pose))
    }

    func test_twoUniqueFourOfFiveOccludedFramesReachTheTargetOnce() {
        var reachedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            monotonicNow: { 0 },
            onPigReachedTarget: { reachedCount += 1 }
        )

        coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        )
        let pose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 1, states: hiddenSamples(), pose: pose),
            now: 0.1
        ), .waiting)
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 2, states: hiddenSamples(), pose: pose),
            now: 0.2
        ), .hidden(referencePose: pose))
        XCTAssertEqual(coordinator.processHideObservation(
            observation(timestamp: 3, states: hiddenSamples(), pose: pose),
            now: 0.3
        ), .waiting)

        XCTAssertEqual(reachedCount, 1)
        XCTAssertEqual(coordinator.status, .hidden)
    }

    func test_unoccludedHideReturnsToTargetSelectionAfterBoundedRetries() {
        let visualController = RealityPigVisualController.makeForTesting()
        var messages: [String] = []
        var retryCount = 0
        var exhaustedCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            onOcclusionRetryStarted: { retryCount += 1 },
            onOcclusionExhausted: { exhaustedCount += 1 },
            onMessage: { messages.append($0) }
        )

        coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.44)
        )
        XCTAssertTrue(coordinator.processOcclusionDeadline(now: 1.5))
        XCTAssertEqual(coordinator.currentHideAttempt?.retryCount, 1)
        XCTAssertEqual(coordinator.currentHideAttempt?.destination.z ?? .nan, -1.18, accuracy: 0.0001)
        XCTAssertTrue(coordinator.processOcclusionDeadline(now: 1.5))
        XCTAssertEqual(coordinator.currentHideAttempt?.retryCount, 2)
        XCTAssertEqual(coordinator.currentHideAttempt?.destination.z ?? .nan, -1.36, accuracy: 0.0001)
        XCTAssertTrue(coordinator.processOcclusionDeadline(now: 1.5))

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
        XCTAssertEqual(retryCount, 2)
        XCTAssertEqual(exhaustedCount, 1)
        XCTAssertEqual(messages, [])
    }

    func test_outOfInsetRetryReturnsToSelectionWithoutMovingPastTheAcceptedDestination() {
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 }
        )
        let region = RealityFloorRegion(
            anchorIdentifier: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
            transform: matrix_identity_float4x4,
            center: .zero,
            extent: SIMD2(1, 1)
        )
        let acceptedDestination = SIMD3<Float>(0, 0, -0.4)

        coordinator.acceptHideTarget(plan: RealityHidePlan(
            start: SIMD3(0, 0, 0.16),
            destination: acceptedDestination,
            retreatDirection: SIMD3(0, 0, -1),
            floorRegion: region
        ))
        XCTAssertTrue(coordinator.processOcclusionDeadline(now: 1.5))

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertEqual(visualController.worldPosition, acceptedDestination)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
    }

    func test_restartCreatesExactlyOneFreshCycleAndDetachesThePreviousPig() {
        let firstVisual = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: firstVisual,
            visualControllerFactory: { RealityPigVisualController.makeForTesting() },
            monotonicNow: { 0 }
        )

        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1), initialPosition: SIMD3(0, 0, -0.4))
        let firstAnchor = coordinator.currentPigAnchorIdentifier
        coordinator.restartHideCycle()

        XCTAssertFalse(coordinator.hasActiveHideCycle)
        XCTAssertFalse(firstVisual.outerEntity.isEnabled)
        XCTAssertEqual(coordinator.status, .waitingForTarget)

        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1.2), initialPosition: SIMD3(0, 0, -0.6))

        XCTAssertTrue(coordinator.hasActiveHideCycle)
        XCTAssertNotEqual(coordinator.currentPigAnchorIdentifier, firstAnchor)
        XCTAssertEqual(coordinator.cycleCreationCount, 2)
    }

    func test_rootCycleResetSequenceTearsDownTheActiveCoordinatorCycleOnce() {
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            monotonicNow: { 0 },
            hideCycleResetSequence: 4
        )

        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.4)
        )
        let generationBeforeReset = coordinator.cycleGeneration

        coordinator.synchronizeHideCycle(resetSequence: 5)

        XCTAssertEqual(coordinator.status, .waitingForTarget)
        XCTAssertFalse(coordinator.hasActiveHideCycle)
        XCTAssertFalse(visualController.outerEntity.isEnabled)
        XCTAssertGreaterThan(coordinator.cycleGeneration, generationBeforeReset)

        let generationAfterReset = coordinator.cycleGeneration
        coordinator.synchronizeHideCycle(resetSequence: 5)
        XCTAssertEqual(coordinator.cycleGeneration, generationAfterReset)
    }

    func test_verifiedHideRestartAndStopCancelTheirAttemptDeadlines() {
        let scheduler = TrackingRealityDeadlineScheduler()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting(),
            visualControllerFactory: { RealityPigVisualController.makeForTesting() },
            deadlineScheduler: scheduler,
            monotonicNow: { 0 }
        )
        let pose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))

        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.4)
        )
        XCTAssertEqual(scheduler.scheduleCount, 1)
        recordStableHide(in: coordinator, referencePose: pose)
        XCTAssertEqual(scheduler.cancelCount, 1)

        coordinator.restartHideCycle()
        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1.2),
            initialPosition: SIMD3(0, 0, -0.6)
        )
        XCTAssertEqual(scheduler.scheduleCount, 2)
        coordinator.restartHideCycle()
        XCTAssertEqual(scheduler.cancelCount, 2)

        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1.4),
            initialPosition: SIMD3(0, 0, -0.8)
        )
        XCTAssertEqual(scheduler.scheduleCount, 3)
        coordinator.stop()
        XCTAssertEqual(scheduler.cancelCount, 3)
        XCTAssertFalse(coordinator.hasActiveHideCycle)
    }

    func test_lateAssetCompletionFromRestartedCycleCannotAdvanceTheNewCycle() {
        typealias Completion = (Result<Entity, Error>) -> Void
        var firstLoads: [(String, Completion)] = []
        var secondLoads: [(String, Completion)] = []
        let firstVisual = RealityPigVisualController.makeForTesting { asset, completion in
            firstLoads.append((asset, completion))
            return nil
        }
        let secondVisual = RealityPigVisualController.makeForTesting { asset, completion in
            secondLoads.append((asset, completion))
            return nil
        }
        var movementCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: firstVisual,
            visualControllerFactory: { secondVisual },
            monotonicNow: { 0 },
            onMovementFinished: { movementCount += 1 }
        )

        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1),
            initialPosition: SIMD3(0, 0, -0.4)
        )
        let staleRunningCompletion = firstLoads.removeFirst().1
        coordinator.restartHideCycle()
        _ = coordinator.acceptHideTarget(
            destination: SIMD3(0, 0, -1.2),
            initialPosition: SIMD3(0, 0, -0.6)
        )

        staleRunningCompletion(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        XCTAssertEqual(movementCount, 0)
        XCTAssertEqual(coordinator.status, .walking)

        secondLoads.removeFirst().1(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        secondLoads.removeFirst().1(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
        XCTAssertEqual(movementCount, 1)
        XCTAssertEqual(coordinator.status, .verifyingOcclusion)
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}

@MainActor
private final class TrackingAcceptedSurfaceMarker: AcceptedSurfaceMarking {
    private(set) var showCount = 0
    private(set) var cancelCount = 0
    private(set) var lastPoint: SIMD3<Float>?
    private(set) var lastNormal: SIMD3<Float>?

    func attach(to arView: ARView) {}

    func show(point: SIMD3<Float>, normal: SIMD3<Float>, animated: Bool) {
        showCount += 1
        lastPoint = point
        lastNormal = normal
    }

    func cancel() {
        cancelCount += 1
    }
}

@MainActor
private final class ControlledRealityEntityLoader {
    typealias Completion = (Result<Entity, Error>) -> Void

    private var pending: [Completion] = []

    func load(_ asset: String, completion: @escaping Completion) -> AnyCancellable? {
        pending.append(completion)
        return nil
    }

    func succeedNext() {
        pending.removeFirst()(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
    }

    func failNext() {
        pending.removeFirst()(.failure(TestRealityEntityLoadError()))
    }
}

private struct TestRealityEntityLoadError: Error {}

@MainActor
private final class TrackingRealityDeadlineScheduler: RealityDeadlineScheduling {
    private(set) var scheduleCount = 0
    private(set) var cancelCount = 0

    func schedule<Owner: AnyObject>(
        _ deadline: RealityDeadline,
        owner: Owner,
        operation: @escaping @MainActor (Owner) -> Void
    ) -> any RealityDeadlineCancellable {
        scheduleCount += 1
        return TrackingRealityDeadlineCancellation { [weak self] in
            self?.cancelCount += 1
        }
    }
}

@MainActor
private final class TrackingRealityDeadlineCancellation: RealityDeadlineCancellable {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        let onCancel = onCancel
        self.onCancel = nil
        onCancel?()
    }
}

@MainActor
private extension RealityHideARView.Coordinator {
    func processTargetSelection(
        destination: SIMD3<Float>,
        initialPosition: SIMD3<Float>
    ) -> Bool {
        processTargetSelection(plan: makeHidePlan(
            destination: destination,
            initialPosition: initialPosition
        ))
    }

    func acceptHideTarget(
        destination: SIMD3<Float>,
        initialPosition: SIMD3<Float>
    ) -> Bool {
        acceptHideTarget(plan: makeHidePlan(
            destination: destination,
            initialPosition: initialPosition
        ))
    }
}

private func makeHidePlan(
    destination: SIMD3<Float>,
    initialPosition: SIMD3<Float>
) -> RealityHidePlan {
    let horizontalRetreat = SIMD3(
        destination.x - initialPosition.x,
        0,
        destination.z - initialPosition.z
    )
    return RealityHidePlan(
        start: initialPosition,
        destination: destination,
        retreatDirection: simd_normalize(horizontalRetreat),
        floorRegion: RealityFloorRegion(
            anchorIdentifier: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            transform: matrix_identity_float4x4,
            center: .zero,
            extent: SIMD2(10, 10)
        )
    )
}

private func observation(
    timestamp: TimeInterval,
    states: [PigOcclusionSampleID: OcclusionSampleState],
    pose: RealityCameraPose?
) -> RealityOcclusionObservation {
    RealityOcclusionObservation(
        frameTimestamp: timestamp,
        samples: states,
        cameraPose: pose
    )
}

private func hiddenSamples() -> [PigOcclusionSampleID: OcclusionSampleState] {
    [
        .center: .blocked,
        .top: .blocked,
        .bottom: .blocked,
        .left: .blocked,
        .right: .visible
    ]
}

private func visibleSamples() -> [PigOcclusionSampleID: OcclusionSampleState] {
    Dictionary(uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { ($0, .visible) })
}

private func invalidSamples() -> [PigOcclusionSampleID: OcclusionSampleState] {
    Dictionary(uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { ($0, .invalid) })
}

@MainActor
private func recordStableHide(
    in coordinator: RealityHideARView.Coordinator,
    referencePose: RealityCameraPose,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(
        coordinator.processHideObservation(
            observation(timestamp: 1, states: hiddenSamples(), pose: referencePose),
            now: 0.1
        ),
        .waiting,
        file: file,
        line: line
    )
    XCTAssertEqual(
        coordinator.processHideObservation(
            observation(timestamp: 2, states: hiddenSamples(), pose: referencePose),
            now: 0.2
        ),
        .hidden(referencePose: referencePose),
        file: file,
        line: line
    )
}
