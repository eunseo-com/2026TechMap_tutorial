import XCTest
import SceneKit
@testable import PiggyEscape

final class HideActionTests: XCTestCase {
    // Note: SCNAction completion handlers only fire while something is actually
    // rendering/ticking the scene (an SCNView or SCNRenderer). A bare
    // `pig.runAction(...) { }` + `wait(for:)` with no renderer never fires the
    // handler and times out (verified: it did, in this environment). Instead,
    // the pig is attached to a live SCNView added to a window with
    // `isPlaying = true`, so the system's real display link ticks the action
    // and the completion handler fires normally, matching the plan's original
    // test shape as closely as possible.
    @MainActor
    func test_makeMoveAction_movesNodeToFakeSofaPosition() {
        let pig = PigPlacement.makePigNode()
        let scene = SCNScene()
        scene.rootNode.addChildNode(pig)

        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        view.scene = scene
        view.isPlaying = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        window.addSubview(view)
        window.makeKeyAndVisible()

        let expectation = expectation(description: "pig reaches fake sofa position")

        pig.runAction(HideAction.makeMoveAction()) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(pig.position.x, FakeSofa.hardcodedPosition.x, accuracy: 0.01)
        XCTAssertEqual(pig.position.y, FakeSofa.hardcodedPosition.y, accuracy: 0.01)
        XCTAssertEqual(pig.position.z, FakeSofa.hardcodedPosition.z, accuracy: 0.01)
    }
}
