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

    func test_revealIsReportedOnceOnlyAfterARealBlockingFrame() {
        var revealCount = 0
        let visualController = RealityPigVisualController.makeForTesting()
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: visualController,
            onRevealed: { revealCount += 1 }
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 1, pigDistance: 2))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
        XCTAssertEqual(revealCount, 1)
        XCTAssertEqual(visualController.currentPose, .surprised)
        XCTAssertEqual(visualController.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(visualController.surpriseRestoreScale, 1.0, accuracy: 0.0001)
    }

    func test_invalidProjectionDoesNotConsumeVisibleFrameAfterBlock() {
        let coordinator = RealityHideARView.Coordinator(
            meshSupport: FakeRealityMeshSupport(supportsMeshWithClassification: true),
            visualController: RealityPigVisualController.makeForTesting()
        )
        coordinator.acceptHideTarget(destination: SIMD3(0, 0, -2), initialPosition: SIMD3(0, 0, -0.8))

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 1, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: false, meshDistance: nil, pigDistance: 2))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
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
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
        XCTAssertEqual(revealCount, 0)

        let runningLoad = pendingLoads.removeFirst()
        XCTAssertEqual(runningLoad.asset, "Piggy_running")
        runningLoad.completion(.success(Entity()))
        XCTAssertEqual(events, ["accepted"])

        let idleLoad = pendingLoads.removeFirst()
        XCTAssertEqual(idleLoad.asset, "Piggy")
        idleLoad.completion(.success(Entity()))
        XCTAssertEqual(events, ["accepted", "reached"])

        XCTAssertFalse(coordinator.processRevealFrame(isObservationValid: true, meshDistance: 0.5, pigDistance: 2))
        XCTAssertTrue(coordinator.processRevealFrame(isObservationValid: true, meshDistance: nil, pigDistance: 2))
        XCTAssertEqual(revealCount, 0)
        let surprisedLoad = pendingLoads.removeFirst()
        XCTAssertEqual(surprisedLoad.asset, "Piggy_surprised")
        surprisedLoad.completion(.success(Entity()))
        XCTAssertEqual(revealCount, 1)
    }

    func test_initialPlacementUsesFloorAndCameraForwardOnlyWhenDefensible() {
        let position = RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            cameraForward: SIMD3(0, 0, -1),
            floorY: 0
        )

        guard let position else {
            return XCTFail("expected a floor-anchored initial position")
        }
        XCTAssertEqual(position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(position.y, 0, accuracy: 0.0001)
        XCTAssertEqual(position.z, -0.8, accuracy: 0.0001)
        XCTAssertNil(RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            cameraForward: SIMD3(0, 1, 0),
            floorY: 0
        ))
        XCTAssertNil(RealityInitialPigPlacement.position(
            cameraPosition: SIMD3(0, 1.5, 0),
            cameraForward: SIMD3(0, 0, -1),
            floorY: 1.5
        ))
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}
