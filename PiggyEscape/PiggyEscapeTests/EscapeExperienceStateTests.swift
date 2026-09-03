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

    func test_realityReadyStartsRealHideOnlyWhenRequested() {
        var machine = EscapeExperienceMachine(state: .realityReady)

        XCTAssertTrue(machine.send(.startRealHide))
        XCTAssertEqual(machine.state, .waitingForRealTarget)
        XCTAssertFalse(machine.send(.startRealHide))
    }

    func test_realHideMovementCanRetryVerifyOrReturnToTargetSelection() {
        var machine = EscapeExperienceMachine(state: .waitingForRealTarget)

        XCTAssertTrue(machine.send(.realTargetAccepted))
        XCTAssertTrue(machine.send(.movementFinished))
        XCTAssertEqual(machine.state, .verifyingOcclusion)

        XCTAssertTrue(machine.send(.occlusionRetryStarted))
        XCTAssertEqual(machine.state, .walkingBehindRealObject)
        XCTAssertTrue(machine.send(.movementFinished))
        XCTAssertTrue(machine.send(.occlusionVerified))
        XCTAssertEqual(machine.state, .hiddenInReality)

        machine = EscapeExperienceMachine(state: .verifyingOcclusion)
        XCTAssertTrue(machine.send(.occlusionExhausted))
        XCTAssertEqual(machine.state, .waitingForRealTarget)
    }

    func test_discoveryCanReplayOrEnterComparisonWithCompletedHideReason() {
        var replayMachine = EscapeExperienceMachine(state: .discoveredInReality)
        XCTAssertTrue(replayMachine.send(.replayRealHide))
        XCTAssertEqual(replayMachine.state, .waitingForRealTarget)

        var comparisonMachine = EscapeExperienceMachine(state: .discoveredInReality)
        XCTAssertTrue(comparisonMachine.send(.reviewDifferences))
        XCTAssertEqual(comparisonMachine.state, .comparison(.completedHide))
    }

    func test_errorsOfferTheirSpecifiedRecoveryOrComparisonRoutes() {
        assertSkipRoute(from: .cameraDenied, reason: .cameraDenied)
        assertSkipRoute(from: .cameraRestricted, reason: .cameraRestricted)
        assertSkipRoute(from: .lidarUnavailable, reason: .lidarUnavailable)
        assertSkipRoute(from: .sessionFailed, reason: .sessionFailed)
        assertSkipRoute(from: .scanTimedOut, reason: .scanTimedOut)
        assertSkipRoute(from: .realityAssetFailed, reason: .assetFailed)

        var sessionMachine = EscapeExperienceMachine(state: .sessionFailed)
        XCTAssertTrue(sessionMachine.send(.retryReality))
        XCTAssertEqual(sessionMachine.state, .scanningReality)

        var timeoutMachine = EscapeExperienceMachine(state: .scanTimedOut)
        XCTAssertTrue(timeoutMachine.send(.retryReality))
        XCTAssertEqual(timeoutMachine.state, .scanningReality)

        var assetMachine = EscapeExperienceMachine(state: .realityAssetFailed)
        XCTAssertTrue(assetMachine.send(.retryReality))
        XCTAssertEqual(assetMachine.state, .waitingForRealTarget)
    }

    func test_comparisonPreservesItsEntryReasonWhenCompleted() {
        var machine = EscapeExperienceMachine(state: .comparison(.scanTimedOut))

        XCTAssertTrue(machine.send(.finishTutorial))
        XCTAssertEqual(machine.state, .completed(.scanTimedOut))
    }

    func test_everyStateResetsAndWrongOrderOrDuplicateEventsAreRejected() {
        let states: [EscapeExperienceState] = [
            .openingNarration, .readyForPigTap, .walkingBehindTree, .hiddenInClosedWorld,
            .discoveredByCamera, .requestingCameraPermission, .cameraDenied,
            .cameraRestricted, .scanningReality, .realityReady, .lidarUnavailable,
            .sessionFailed, .scanTimedOut, .waitingForRealTarget, .walkingBehindRealObject,
            .verifyingOcclusion, .hiddenInReality, .discoveredInReality,
            .realityAssetFailed, .comparison(.assetFailed), .completed(.completedHide)
        ]

        for state in states {
            var machine = EscapeExperienceMachine(state: state)
            XCTAssertTrue(machine.send(.reset), "reset should be accepted from \(state)")
            XCTAssertEqual(machine.state, .openingNarration)
        }

        var machine = EscapeExperienceMachine()
        XCTAssertFalse(machine.send(.startRealHide))
        XCTAssertEqual(machine.state, .openingNarration)
        XCTAssertTrue(machine.send(.narrationFinished))
        XCTAssertFalse(machine.send(.narrationFinished))
        XCTAssertEqual(machine.state, .readyForPigTap)
    }

    func test_cameraAuthorizationRoutesAndSettingsRecheckContractAreDistinct() {
        var denied = EscapeExperienceMachine(state: .requestingCameraPermission)
        XCTAssertTrue(denied.send(.cameraAuthorizationDenied))
        XCTAssertEqual(denied.state, .cameraDenied)
        XCTAssertFalse(denied.send(.cameraAuthorized))
        XCTAssertFalse(denied.send(.cameraAuthorizationDenied))
        XCTAssertFalse(denied.send(.cameraAuthorizationRestricted))
        XCTAssertTrue(denied.send(.openSettings))
        XCTAssertEqual(denied.state, .cameraDenied)
        XCTAssertTrue(denied.isCameraAuthorizationRecheckArmed)
        XCTAssertFalse(denied.send(.openSettings))
        XCTAssertTrue(denied.send(.cameraAuthorizationDenied))
        XCTAssertEqual(denied.state, .cameraDenied)
        XCTAssertFalse(denied.isCameraAuthorizationRecheckArmed)
        XCTAssertFalse(denied.send(.cameraAuthorized))

        XCTAssertTrue(denied.send(.openSettings))
        XCTAssertTrue(denied.send(.cameraAuthorizationRestricted))
        XCTAssertEqual(denied.state, .cameraRestricted)
        XCTAssertFalse(denied.isCameraAuthorizationRecheckArmed)

        var restricted = EscapeExperienceMachine(state: .requestingCameraPermission)
        XCTAssertTrue(restricted.send(.cameraAuthorizationRestricted))
        XCTAssertEqual(restricted.state, .cameraRestricted)
        XCTAssertFalse(restricted.send(.openSettings))
    }

    func test_sessionFailuresAndInterruptionsUseTheirChapterSpecificRecoveryStates() {
        var scanning = EscapeExperienceMachine(state: .scanningReality)
        XCTAssertTrue(scanning.send(.sessionDidFail))
        XCTAssertEqual(scanning.state, .sessionFailed)

        var hiding = EscapeExperienceMachine(state: .walkingBehindRealObject)
        XCTAssertTrue(hiding.send(.sessionInterrupted))
        XCTAssertEqual(hiding.state, .waitingForRealTarget)

        var selectingTarget = EscapeExperienceMachine(state: .waitingForRealTarget)
        XCTAssertFalse(selectingTarget.send(.sessionInterrupted))
        XCTAssertEqual(selectingTarget.state, .waitingForRealTarget)

        var assetLoading = EscapeExperienceMachine(state: .verifyingOcclusion)
        XCTAssertTrue(assetLoading.send(.realityAssetLoadFailed))
        XCTAssertEqual(assetLoading.state, .realityAssetFailed)
        XCTAssertTrue(assetLoading.send(.sessionDidFail))
        XCTAssertEqual(assetLoading.state, .sessionFailed)

        var hidden = EscapeExperienceMachine(state: .hiddenInReality)
        XCTAssertTrue(hidden.send(.realityAssetLoadFailed))
        XCTAssertEqual(hidden.state, .realityAssetFailed)
    }

    private func assertSkipRoute(
        from state: EscapeExperienceState,
        reason: ComparisonEntryReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var machine = EscapeExperienceMachine(state: state)
        XCTAssertTrue(machine.send(.skipToComparison), file: file, line: line)
        XCTAssertEqual(machine.state, .comparison(reason), file: file, line: line)
    }
}
