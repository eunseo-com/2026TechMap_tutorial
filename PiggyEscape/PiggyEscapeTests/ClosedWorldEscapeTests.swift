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

    func test_cameraDiscoveryNeedsYawChangeAndVisiblePig() {
        let world = C3ClosedWorld()
        world.isPigInCameraFrustum = { true }
        world.completeOpeningNarration()
        XCTAssertTrue(world.tapPig())
        world.finishTreeHideForTesting()

        XCTAssertFalse(world.isDiscoveredAfterCameraRotation())
        world.rotateCamera(byYaw: .pi / 2)

        XCTAssertTrue(world.isDiscoveredAfterCameraRotation())
        XCTAssertEqual(world.currentPose, .surprised)
    }

    func test_surpriseCaptionAndScaleReactionStartTogether() {
        let world = C3ClosedWorld()

        world.performSurpriseReaction()

        XCTAssertEqual(world.currentPose, .surprised)
        XCTAssertEqual(world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
        XCTAssertEqual(world.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertNotNil(world.pigContainer.action(forKey: "escapePig.surpriseScale"))
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
