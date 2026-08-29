enum TutorialChapter: Equatable {
    case closedWorld, openingReality, realHideAndSeek, comparison
}

extension EscapeExperienceState {
    var chapter: TutorialChapter {
        switch self {
        case .openingNarration, .readyForPigTap, .walkingBehindTree,
             .hiddenInClosedWorld, .discoveredByCamera:
            .closedWorld
        case .requestingCameraPermission, .cameraDenied, .cameraRestricted,
             .scanningReality, .realityReady, .lidarUnavailable, .sessionFailed,
             .scanTimedOut:
            .openingReality
        case .waitingForRealTarget, .walkingBehindRealObject, .verifyingOcclusion,
             .hiddenInReality, .discoveredInReality, .realityAssetFailed:
            .realHideAndSeek
        case .comparison, .completed:
            .comparison
        }
    }
}
