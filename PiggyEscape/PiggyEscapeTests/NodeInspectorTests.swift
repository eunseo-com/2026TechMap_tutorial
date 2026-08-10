import XCTest
import SceneKit
@testable import PiggyEscape

final class NodeInspectorTests: XCTestCase {
    @MainActor
    func test_describe_reportsGeometryPhysicsAndActionOnSameNode() {
        // 의도적으로 geometry·physicsBody·action을 전부 SCNNode 하나에 붙인다 —
        // SceneKit이 이 셋을 분리하지 않는다는 걸 테스트로 증명하기 위해.
        let node = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.runAction(.moveBy(x: 1, y: 0, z: 0, duration: 1), forKey: "demo.move")

        let lines = NodeInspector.describe(node)

        XCTAssertTrue(lines.contains { $0.contains("geometry") })
        XCTAssertTrue(lines.contains { $0.contains("physicsBody") })
        XCTAssertTrue(lines.contains { $0.contains("demo.move") })
    }

    @MainActor
    func test_describe_omitsAspectsNotPresent() {
        let node = SCNNode()
        let lines = NodeInspector.describe(node)
        XCTAssertFalse(lines.contains { $0.contains("geometry") })
        XCTAssertFalse(lines.contains { $0.contains("physicsBody") })
    }
}
