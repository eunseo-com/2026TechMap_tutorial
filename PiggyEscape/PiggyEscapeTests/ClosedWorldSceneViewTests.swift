import XCTest
import SceneKit
@testable import PiggyEscape

final class ClosedWorldSceneViewTests: XCTestCase {
    @MainActor
    func test_tapCoordinator_startsHideActionOnPig() {
        let coordinator = ClosedWorldSceneView.Coordinator()
        let pig = SCNNode()
        coordinator.pigNode = pig

        coordinator.handleTap()

        XCTAssertTrue(pig.hasActions, "a tap should start the pig's hide action")
    }
}
