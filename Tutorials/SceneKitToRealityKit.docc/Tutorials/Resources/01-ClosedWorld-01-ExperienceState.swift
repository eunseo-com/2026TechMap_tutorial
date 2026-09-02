// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/TutorialChapter.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/TutorialChapterTests.swift

enum TutorialChapter {
    case closedWorld
    case openingReality
}
enum ClosedWorldState {
    case openingNarration
    case readyForPigTap
    case walkingBehindTree
    case hiddenInClosedWorld
    case discoveredByCamera
    case requestingCameraPermission

    var chapter: TutorialChapter {
        self == .requestingCameraPermission ? .openingReality : .closedWorld
    }
}

enum ClosedWorldEvent {
    case narrationFinished
    case pigTapped
    case pigReachedTree
    case closedWorldPigDiscovered
    case closedWorldFadeFinished
    case reset
}

struct ClosedWorldExperience {
    private(set) var state: ClosedWorldState = .openingNarration

    @discardableResult
    mutating func send(_ event: ClosedWorldEvent) -> Bool {
        switch (state, event) {
        case (_, .reset):
            state = .openingNarration
        case (.openingNarration, .narrationFinished):
            state = .readyForPigTap
        case (.readyForPigTap, .pigTapped):
            state = .walkingBehindTree
        case (.walkingBehindTree, .pigReachedTree):
            state = .hiddenInClosedWorld
        case (.hiddenInClosedWorld, .closedWorldPigDiscovered):
            state = .discoveredByCamera
        case (.discoveredByCamera, .closedWorldFadeFinished):
            state = .requestingCameraPermission
        default:
            return false
        }
        return true
    }
}
