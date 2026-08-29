enum ComparisonEntryReason: Equatable {
    case completedHide, cameraDenied, cameraRestricted, lidarUnavailable
    case sessionFailed, scanTimedOut, assetFailed
}

enum EscapeExperienceState: Equatable {
    case openingNarration, readyForPigTap, walkingBehindTree, hiddenInClosedWorld
    case discoveredByCamera
    case requestingCameraPermission, cameraDenied, cameraRestricted, scanningReality
    case realityReady, lidarUnavailable, sessionFailed, scanTimedOut
    case waitingForRealTarget, walkingBehindRealObject, verifyingOcclusion
    case hiddenInReality, discoveredInReality, realityAssetFailed
    case comparison(ComparisonEntryReason), completed(ComparisonEntryReason)
}

enum EscapeExperienceEvent {
    case narrationFinished, pigTapped, pigReachedTree, closedWorldPigDiscovered
    case closedWorldFadeFinished
    case cameraAuthorized, cameraAuthorizationDenied, cameraAuthorizationRestricted, openSettings
    case meshUnsupported, environmentReady, scanDeadlineElapsed, sessionDidFail
    case startRealHide, realTargetAccepted, movementFinished, occlusionRetryStarted
    case occlusionVerified, occlusionExhausted, realityPigDiscovered, sessionInterrupted
    case realityAssetLoadFailed, replayRealHide, reviewDifferences
    case retryReality, skipToComparison, finishTutorial, retryChapter3, reset

    // These retain the pre-four-chapter coordinator contract until Task 7 replaces it.
    case cameraDenied, meshSupported, pigReachedRealObject
}

struct EscapeExperienceMachine {
    private(set) var state: EscapeExperienceState
    private(set) var isCameraAuthorizationRecheckArmed = false
    private var requiresSettingsAuthorizationRecheck = false

    init(state: EscapeExperienceState = .openingNarration) {
        self.state = state
    }

    mutating func send(_ event: EscapeExperienceEvent) -> Bool {
        switch (state, event) {
        case (_, .reset):
            state = .openingNarration
            isCameraAuthorizationRecheckArmed = false
            requiresSettingsAuthorizationRecheck = false

        case (.openingNarration, .narrationFinished): state = .readyForPigTap
        case (.readyForPigTap, .pigTapped): state = .walkingBehindTree
        case (.walkingBehindTree, .pigReachedTree): state = .hiddenInClosedWorld
        case (.hiddenInClosedWorld, .closedWorldPigDiscovered): state = .discoveredByCamera
        case (.discoveredByCamera, .closedWorldFadeFinished): state = .requestingCameraPermission

        case (.requestingCameraPermission, .cameraAuthorized): state = .scanningReality
        case (.requestingCameraPermission, .cameraAuthorizationDenied):
            state = .cameraDenied
            requiresSettingsAuthorizationRecheck = true
        case (.requestingCameraPermission, .cameraAuthorizationRestricted): state = .cameraRestricted
        case (.requestingCameraPermission, .cameraDenied):
            state = .cameraDenied
            requiresSettingsAuthorizationRecheck = false
        case (.cameraDenied, .openSettings)
            where requiresSettingsAuthorizationRecheck && !isCameraAuthorizationRecheckArmed:
            isCameraAuthorizationRecheckArmed = true
        case (.cameraDenied, .cameraAuthorized)
            where !requiresSettingsAuthorizationRecheck || isCameraAuthorizationRecheckArmed:
            state = .scanningReality
            isCameraAuthorizationRecheckArmed = false
            requiresSettingsAuthorizationRecheck = false

        case (.scanningReality, .meshUnsupported): state = .lidarUnavailable
        case (.scanningReality, .environmentReady): state = .realityReady
        case (.scanningReality, .scanDeadlineElapsed): state = .scanTimedOut
        case (.scanningReality, .meshSupported): state = .waitingForRealTarget

        case (.realityReady, .startRealHide): state = .waitingForRealTarget
        case (.waitingForRealTarget, .realTargetAccepted): state = .walkingBehindRealObject
        case (.walkingBehindRealObject, .movementFinished): state = .verifyingOcclusion
        case (.verifyingOcclusion, .occlusionRetryStarted): state = .walkingBehindRealObject
        case (.verifyingOcclusion, .occlusionVerified): state = .hiddenInReality
        case (.verifyingOcclusion, .occlusionExhausted): state = .waitingForRealTarget
        case (.walkingBehindRealObject, .pigReachedRealObject): state = .hiddenInReality
        case (.hiddenInReality, .realityPigDiscovered): state = .discoveredInReality
        case (.discoveredInReality, .replayRealHide): state = .waitingForRealTarget
        case (.discoveredInReality, .reviewDifferences): state = .comparison(.completedHide)

        case (.walkingBehindRealObject, .sessionInterrupted),
             (.verifyingOcclusion, .sessionInterrupted),
             (.hiddenInReality, .sessionInterrupted): state = .waitingForRealTarget
        case (.waitingForRealTarget, .realityAssetLoadFailed),
             (.walkingBehindRealObject, .realityAssetLoadFailed),
             (.verifyingOcclusion, .realityAssetLoadFailed): state = .realityAssetFailed

        case (.scanningReality, .sessionDidFail), (.realityReady, .sessionDidFail),
             (.waitingForRealTarget, .sessionDidFail), (.walkingBehindRealObject, .sessionDidFail),
             (.verifyingOcclusion, .sessionDidFail), (.hiddenInReality, .sessionDidFail),
             (.discoveredInReality, .sessionDidFail), (.realityAssetFailed, .sessionDidFail): state = .sessionFailed

        case (.sessionFailed, .retryReality), (.scanTimedOut, .retryReality): state = .scanningReality
        case (.realityAssetFailed, .retryReality): state = .waitingForRealTarget

        case (.cameraDenied, .skipToComparison): state = .comparison(.cameraDenied)
        case (.cameraRestricted, .skipToComparison): state = .comparison(.cameraRestricted)
        case (.lidarUnavailable, .skipToComparison): state = .comparison(.lidarUnavailable)
        case (.sessionFailed, .skipToComparison): state = .comparison(.sessionFailed)
        case (.scanTimedOut, .skipToComparison): state = .comparison(.scanTimedOut)
        case (.realityAssetFailed, .skipToComparison): state = .comparison(.assetFailed)
        case (.comparison(let reason), .finishTutorial): state = .completed(reason)
        case (.comparison, .retryChapter3), (.completed, .retryChapter3): state = .scanningReality

        default: return false
        }
        return true
    }
}
