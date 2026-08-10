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
        // No windowScene is attached here (this is an offscreen test window, not
        // part of the app's real scene-based lifecycle), which triggers a soft
        // makeKeyAndVisible() deprecation warning in the console. That warning is
        // expected/harmless for this isolated rendering-driver setup and can be
        // ignored.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        window.addSubview(view)
        window.makeKeyAndVisible()
        // Ensure the window/view never outlive this test, even if an assertion
        // above throws: resign key status and stop the display link driving the
        // scene so no state leaks into later tests in the same process.
        defer {
            view.isPlaying = false
            window.isHidden = true
            window.resignKey()
        }

        let expectation = expectation(description: "pig reaches fake sofa position")

        pig.runAction(HideAction.makeMoveAction()) {
            expectation.fulfill()
        }

        // This test relies on the real system display link (via SCNView.isPlaying)
        // to tick the SCNAction forward, so it depends on real wall-clock time
        // rather than a fully deterministic clock. The action itself only takes
        // 0.5s; a 2.0s timeout gives a 4x margin, which is generous enough that
        // this is not expected to flake under normal CI/simulator load. A fully
        // deterministic alternative (manually pumping SCNRenderer.render(atTime:))
        // was tried first and crashed on this iOS 26.5 simulator runtime (see
        // task-6-report.md), so the real-display-link + generous-timeout approach
        // is an accepted, deliberate tradeoff rather than an oversight.
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(pig.position.x, FakeSofa.hardcodedPosition.x, accuracy: 0.01)
        XCTAssertEqual(pig.position.y, FakeSofa.hardcodedPosition.y, accuracy: 0.01)
        XCTAssertEqual(pig.position.z, FakeSofa.hardcodedPosition.z, accuracy: 0.01)
    }
}
