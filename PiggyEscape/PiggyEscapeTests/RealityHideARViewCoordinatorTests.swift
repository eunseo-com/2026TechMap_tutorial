import XCTest
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

        XCTAssertFalse(coordinator.processRevealFrame(meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(meshDistance: 1, pigDistance: 2))
        XCTAssertTrue(coordinator.processRevealFrame(meshDistance: nil, pigDistance: 2))
        XCTAssertFalse(coordinator.processRevealFrame(meshDistance: nil, pigDistance: 2))
        XCTAssertEqual(revealCount, 1)
        XCTAssertEqual(visualController.currentPose, .surprised)
        XCTAssertEqual(visualController.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(visualController.surpriseRestoreScale, 1.0, accuracy: 0.0001)
    }
}

private struct FakeRealityMeshSupport: RealityMeshSupporting {
    let supportsMeshWithClassification: Bool
}
