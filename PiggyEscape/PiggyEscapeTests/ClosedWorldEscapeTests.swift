import XCTest
@testable import PiggyEscape

@MainActor
final class ClosedWorldEscapeTests: XCTestCase {
    func test_tapIsIgnoredBeforeNarrationAndStartsRunningAfterIt() {
        let world = C3ClosedWorld()

        XCTAssertFalse(world.tapPig())
        world.completeOpeningNarration()

        XCTAssertTrue(world.tapPig())
        XCTAssertEqual(world.currentPose, .running)
    }

    func test_treeArrivalNotifiesTheAutomaticProgressBoundaryOnce() {
        let world = C3ClosedWorld()
        var count = 0
        world.onTreeHideFinished = { count += 1 }
        world.completeOpeningNarration()
        XCTAssertTrue(world.tapPig())
        world.finishTreeHideForTesting()
        world.finishTreeHideForTesting()

        XCTAssertEqual(count, 1)
    }

    func test_surpriseCaptionAndScaleReactionStartTogether() {
        let world = C3ClosedWorld()

        world.performSurpriseReaction()

        XCTAssertEqual(world.currentPose, .surprised)
        XCTAssertEqual(world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
        XCTAssertEqual(world.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertNotNil(world.pigContainer.action(forKey: "escapePig.surpriseScale"))
    }

    func test_surpriseScaleActionStartsBeforeCaptionCallback() {
        let world = C3ClosedWorld()
        var scaleActionWasInstalled = false
        world.onSurpriseCaption = { _ in
            scaleActionWasInstalled = world.pigContainer.action(
                forKey: "escapePig.surpriseScale"
            ) != nil
        }

        world.performSurpriseReaction()

        XCTAssertTrue(scaleActionWasInstalled)
    }

    func test_automaticDiscoveryDoesNotRunBeforePigReachesTree() {
        let world = C3ClosedWorld()
        world.completeOpeningNarration()
        XCTAssertTrue(world.tapPig())

        XCTAssertFalse(world.automaticallyDiscoverAfterTreeHide())
        XCTAssertEqual(world.currentPose, .running)
    }

    func test_treeArrivalAutomaticallyDiscoversWithoutCameraRotationOnlyOnce() {
        let world = C3ClosedWorld()
        world.completeOpeningNarration()
        XCTAssertTrue(world.tapPig())
        world.finishTreeHideForTesting()

        XCTAssertTrue(world.automaticallyDiscoverAfterTreeHide())
        XCTAssertEqual(world.currentPose, .surprised)
        XCTAssertEqual(world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
        XCTAssertFalse(world.automaticallyDiscoverAfterTreeHide())
    }

    func test_hidingUsesTheActualInSceneHideTree() {
        let world = C3ClosedWorld()
        let islandTree = world.scene.rootNode.childNode(
            withName: "HideTree",
            recursively: true
        )

        XCTAssertNotNil(islandTree)
        XCTAssertTrue(world.hideTree === islandTree)
    }
}
