import Combine
import RealityKit
import XCTest
import simd
@testable import PiggyEscape

@MainActor
final class RealityHideARViewCoordinatorTests: XCTestCase {
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

    func test_scanningReadinessWaitsForTheFirstMeaningfulMeshOrFloorObservation() {
        var readyCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            onScanningReady: { readyCount += 1 }
        )

        XCTAssertFalse(coordinator.processScanningObservation(hasMesh: false, hasFloor: false))
        XCTAssertEqual(readyCount, 0)
        XCTAssertTrue(coordinator.processScanningObservation(hasMesh: true, hasFloor: false))
        XCTAssertEqual(readyCount, 1)
        XCTAssertFalse(coordinator.processScanningObservation(hasMesh: false, hasFloor: true))
        XCTAssertEqual(readyCount, 1)
    }

    func test_revealIsReportedOnceOnlyAfterARealBlockingFrame() {
        var revealCount = 0
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            onRevealed: { revealCount += 1 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertEqual(revealCount, 1)
        XCTAssertEqual(visualController.currentPose, .surprised)
        XCTAssertEqual(visualController.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(visualController.surpriseRestoreScale, 1.0, accuracy: 0.0001)
    }

    func test_invalidRevealObservationResetsVisibleStabilityButKeepsTheBlockingPose() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting()
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockingPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 1, pigDistance: 2, cameraPose: blockingPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: false, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
    }

    func test_invalidProjectionDoesNotConsumeVisibleFrameAfterBlock() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting()
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 1, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: false, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
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
            onTargetAccepted: { events.append("accepted") },
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
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertEqual(revealCount, 0)

        let runningLoad = pendingLoads.removeFirst()
        XCTAssertEqual(runningLoad.asset, "Piggy_running")
        runningLoad.completion(.success(Entity()))
        XCTAssertEqual(events, ["accepted"])

        let idleLoad = pendingLoads.removeFirst()
        XCTAssertEqual(idleLoad.asset, "Piggy")
        idleLoad.completion(.success(Entity()))
        XCTAssertEqual(events, ["accepted", "reached"])

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertEqual(revealCount, 0)
        let surprisedLoad = pendingLoads.removeFirst()
        XCTAssertEqual(surprisedLoad.asset, "Piggy_surprised")
        surprisedLoad.completion(.success(Entity()))
        XCTAssertEqual(revealCount, 1)
    }

    func test_initialPlacementUsesFloorAndCameraForwardOnlyWhenDefensible() {
        let nearHit = RealitySurfaceHit(point: SIMD3(0, 1, -0.5), normal: SIMD3(0, 0, 1))
        let position = RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            hit: nearHit,
            destination: SIMD3(0, 0, -0.78),
            floorY: 0
        )

        guard let position else {
            return XCTFail("expected a floor-anchored initial position")
        }
        XCTAssertEqual(position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(position.y, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(position.z, nearHit.point.z)
        XCTAssertEqual(position.z, -0.22, accuracy: 0.0001)

        let farHit = RealitySurfaceHit(point: SIMD3(0, 0.8, -2), normal: SIMD3(0, 0, 1))
        let farPosition = RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            hit: farHit,
            destination: SIMD3(0, 0, -2.28),
            floorY: 0
        )
        XCTAssertEqual(farPosition?.z, -1.72)
        XCTAssertNil(RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            hit: nearHit,
            destination: SIMD3(0, 0, -0.22),
            floorY: 0
        ))
        XCTAssertNil(RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            hit: nearHit,
            destination: SIMD3(0, 1.5, -0.78),
            floorY: 1.5
        ))
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

    func test_surprisedLoadFailureRestoresHiddenStateWithoutReportingReveal() {
        let loader = ControlledRealityEntityLoader()
        let visualController = RealityPigVisualController.makeForTesting(entityLoader: loader.load)
        var errorCount = 0
        var revealCount = 0
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            onRevealed: { revealCount += 1 },
            onError: { errorCount += 1 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -1), initialPosition: SIMD3(0, 0, -0.2))
        loader.succeedNext()
        loader.succeedNext()
        XCTAssertEqual(coordinator.status, .hidden)
        let blockedPose = RealityCameraPose(position: .zero, forward: SIMD3(0, 0, -1))
        let movedPose = RealityCameraPose(position: SIMD3(0.15, 0, 0), forward: SIMD3(0, 0, -1))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertEqual(coordinator.status, .revealing)
        loader.failNext()

        XCTAssertEqual(coordinator.status, .hidden)
        XCTAssertTrue(visualController.outerEntity.isEnabled)
        XCTAssertEqual(revealCount, 0)
        XCTAssertEqual(errorCount, 1)
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2, cameraPose: blockedPose))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2, cameraPose: movedPose))
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
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
        pending.removeFirst()(.success(Entity()))
    }

    func failNext() {
        pending.removeFirst()(.failure(TestRealityEntityLoadError()))
    }
}

private struct TestRealityEntityLoadError: Error {}
