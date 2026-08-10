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

    init(state: EscapeExperienceState = .openingNarration) {
        self.state = state
    }

    mutating func send(_ event: EscapeExperienceEvent) -> Bool {
        switch (state, event) {
        case (_, .reset): state = .openingNarration
        case (.openingNarration, .narrationFinished): state = .readyForPigTap
        case (.readyForPigTap, .pigTapped): state = .walkingBehindTree
        case (.walkingBehindTree, .pigReachedTree): state = .hiddenInClosedWorld
        case (.hiddenInClosedWorld, .closedWorldPigDiscovered): state = .discoveredByCamera
        case (.discoveredByCamera, .closedWorldFadeFinished): state = .requestingCameraPermission
        case (.requestingCameraPermission, .cameraAuthorized),
             (.cameraDenied, .cameraAuthorized): state = .scanningReality
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
