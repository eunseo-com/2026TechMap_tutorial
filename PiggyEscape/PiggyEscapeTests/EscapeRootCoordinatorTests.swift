import XCTest
@testable import PiggyEscape

@MainActor
final class EscapeRootCoordinatorTests: XCTestCase {
    func test_closedWorldDiscoveryWaitsForFadeBeforeRequestingCamera() {
        let authorizer = FakeCameraAuthorizer()
        let coordinator = makeCoordinator(authorizer: authorizer)

        coordinator.closedWorldNarrationDidFinish()
        coordinator.closedWorldDiscoveryDidOccur()

        XCTAssertEqual(coordinator.machine.state, .discoveredByCamera)
        XCTAssertEqual(coordinator.message, EscapeRootMessage.surprised)
        XCTAssertTrue(coordinator.isClosedWorldFading)
        XCTAssertEqual(authorizer.requestCount, 0)

        coordinator.closedWorldFadeDidFinish()

        XCTAssertEqual(coordinator.machine.state, .requestingCameraPermission)
        XCTAssertEqual(authorizer.requestCount, 1)
        XCTAssertFalse(coordinator.showsRealityView)

        coordinator.closedWorldFadeDidFinish()
        XCTAssertEqual(authorizer.requestCount, 1)
    }

    func test_authorizedCameraStartsRealityThenMeshSupportEnablesTargetSelection() {
        let authorizer = FakeCameraAuthorizer()
        let coordinator = makeCoordinator(authorizer: authorizer)
        reachCameraRequest(coordinator)

        authorizer.resolve(.authorized)

        XCTAssertEqual(coordinator.machine.state, .scanningReality)
        XCTAssertTrue(coordinator.showsRealityView)
        XCTAssertEqual(coordinator.message, RealityAvailabilityMessage.scanFirst)

        coordinator.realityScanningDidBecomeReady()
        XCTAssertEqual(coordinator.machine.state, .waitingForRealTarget)
        XCTAssertEqual(coordinator.message, RealityAvailabilityMessage.selectVerticalSide)
    }

    func test_deniedCameraShowsRecoveryAndOpensSettingsOnlyAfterTap() {
        let authorizer = FakeCameraAuthorizer()
        let settings = FakeSettingsOpener()
        let coordinator = makeCoordinator(authorizer: authorizer, settings: settings)
        reachCameraRequest(coordinator)

        authorizer.resolve(.denied)

        XCTAssertEqual(coordinator.machine.state, .cameraDenied)
        XCTAssertFalse(coordinator.showsRealityView)
        XCTAssertTrue(coordinator.showsSettingsRecovery)
        XCTAssertEqual(coordinator.message, EscapeRootMessage.cameraDenied)
        XCTAssertEqual(settings.openCount, 0)

        coordinator.openSettingsForRecovery()
        XCTAssertEqual(settings.openCount, 1)
    }

    func test_restrictedCameraShowsItsOwnBlockedMessageAndWaitsForRecoveryTap() {
        let authorizer = FakeCameraAuthorizer()
        let settings = FakeSettingsOpener()
        let coordinator = makeCoordinator(authorizer: authorizer, settings: settings)
        reachCameraRequest(coordinator)

        authorizer.resolve(.restricted)

        XCTAssertEqual(coordinator.machine.state, .cameraDenied)
        XCTAssertFalse(coordinator.showsRealityView)
        XCTAssertEqual(coordinator.message, EscapeRootMessage.cameraRestricted)
        XCTAssertEqual(settings.openCount, 0)

        coordinator.openSettingsForRecovery()
        XCTAssertEqual(settings.openCount, 1)
    }

    func test_realityCallbacksAdvanceInPhysicalActionOrderAndRevealOnce() {
        let authorizer = FakeCameraAuthorizer()
        let coordinator = makeCoordinator(authorizer: authorizer)
        reachCameraRequest(coordinator)
        authorizer.resolve(.authorized)
        coordinator.realityScanningDidBecomeReady()

        coordinator.realityTargetDidBecomeAccepted()
        XCTAssertEqual(coordinator.machine.state, .walkingBehindRealObject)

        coordinator.realityPigDidReachTarget()
        XCTAssertEqual(coordinator.machine.state, .hiddenInReality)
        XCTAssertEqual(coordinator.message, EscapeRootMessage.findPig)

        coordinator.realityPigDidBecomeRevealed()
        XCTAssertEqual(coordinator.machine.state, .discoveredInReality)
        XCTAssertEqual(coordinator.message, EscapeRootMessage.surprised)
        XCTAssertEqual(coordinator.realitySurpriseSequence, 1)
        XCTAssertEqual(EscapeRootMotion.realityPeakScale(reduceMotion: false), 1.12, accuracy: 0.0001)

        coordinator.realityPigDidBecomeRevealed()
        XCTAssertEqual(coordinator.realitySurpriseSequence, 1)
    }

    func test_outOfOrderRealityCallbacksDoNotSkipStates() {
        let coordinator = makeCoordinator(authorizer: FakeCameraAuthorizer())

        coordinator.realityPigDidReachTarget()
        coordinator.realityPigDidBecomeRevealed()

        XCTAssertEqual(coordinator.machine.state, .openingNarration)
        XCTAssertEqual(coordinator.realitySurpriseSequence, 0)
    }

    func test_unavailableAndTaskSixErrorMessagesRemainVisible() {
        let authorizer = FakeCameraAuthorizer()
        let coordinator = makeCoordinator(authorizer: authorizer)
        reachCameraRequest(coordinator)
        authorizer.resolve(.authorized)

        coordinator.realityMeshDidBecomeUnavailable()
        XCTAssertEqual(coordinator.machine.state, .lidarUnavailable)
        XCTAssertFalse(coordinator.showsRealityView)
        XCTAssertEqual(coordinator.message, RealityAvailabilityMessage.unavailable)

        coordinator.realityErrorDidOccur()
        coordinator.realityMessageDidChange(RealityAvailabilityMessage.pigAssetLoadFailed)
        XCTAssertEqual(coordinator.realityErrorCount, 1)
        XCTAssertEqual(coordinator.message, RealityAvailabilityMessage.pigAssetLoadFailed)
    }

    func test_reducedMotionDoesNotDigitallyScaleTheRealityCameraSurface() {
        XCTAssertEqual(EscapeRootMotion.realityPeakScale(reduceMotion: false), 1.12, accuracy: 0.0001)
        XCTAssertEqual(EscapeRootMotion.realityPeakScale(reduceMotion: true), 1.0, accuracy: 0.0001)
    }

    private func makeCoordinator(
        authorizer: FakeCameraAuthorizer,
        settings: FakeSettingsOpener? = nil
    ) -> EscapeRootCoordinator {
        EscapeRootCoordinator(
            cameraAuthorizer: authorizer,
            settingsOpener: settings ?? FakeSettingsOpener()
        )
    }

    private func reachCameraRequest(_ coordinator: EscapeRootCoordinator) {
        coordinator.closedWorldNarrationDidFinish()
        coordinator.closedWorldDiscoveryDidOccur()
        coordinator.closedWorldFadeDidFinish()
    }
}

@MainActor
private final class FakeCameraAuthorizer: CameraAuthorizing {
    private(set) var requestCount = 0
    private var completion: ((CameraAuthorizationResult) -> Void)?

    func requestVideoAccess(
        _ completion: @escaping @MainActor (CameraAuthorizationResult) -> Void
    ) {
        requestCount += 1
        self.completion = completion
    }

    func resolve(_ result: CameraAuthorizationResult) {
        completion?(result)
        completion = nil
    }
}

@MainActor
private final class FakeSettingsOpener: AppSettingsOpening {
    private(set) var openCount = 0

    func openAppSettings() {
        openCount += 1
    }
}
