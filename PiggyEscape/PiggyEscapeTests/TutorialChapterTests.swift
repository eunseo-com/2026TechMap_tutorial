import XCTest
@testable import PiggyEscape

final class TutorialChapterTests: XCTestCase {
    func test_everyExperienceStateDerivesTheCorrectTutorialChapter() {
        let chapters: [(EscapeExperienceState, TutorialChapter)] = [
            (.openingNarration, .closedWorld),
            (.readyForPigTap, .closedWorld),
            (.walkingBehindTree, .closedWorld),
            (.hiddenInClosedWorld, .closedWorld),
            (.discoveredByCamera, .closedWorld),
            (.requestingCameraPermission, .openingReality),
            (.cameraDenied, .openingReality),
            (.cameraRestricted, .openingReality),
            (.scanningReality, .openingReality),
            (.realityReady, .openingReality),
            (.lidarUnavailable, .openingReality),
            (.sessionFailed, .openingReality),
            (.scanTimedOut, .openingReality),
            (.waitingForRealTarget, .realHideAndSeek),
            (.walkingBehindRealObject, .realHideAndSeek),
            (.verifyingOcclusion, .realHideAndSeek),
            (.hiddenInReality, .realHideAndSeek),
            (.discoveredInReality, .realHideAndSeek),
            (.realityAssetFailed, .realHideAndSeek),
            (.comparison(.completedHide), .comparison),
            (.completed(.cameraDenied), .comparison)
        ]

        for (state, expectedChapter) in chapters {
            XCTAssertEqual(state.chapter, expectedChapter, "\(state) should route to \(expectedChapter)")
        }
    }
}
