import XCTest
import SceneKit
@testable import PiggyEscape

final class SceneKitGeometryTests: XCTestCase {
    /// 정확히 2 x 4 x 1 (x/y/z)인 합성 SCNBox 노드 — 실제 에셋과 무관하게
    /// 정규화 계산 자체를 결정론적으로 검증하기 위한 픽스처.
    private func makeBoxNode(width: CGFloat = 2, height: CGFloat = 4, length: CGFloat = 1) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0)
        return SCNNode(geometry: box)
    }

    func test_boundingBox_matchesGeometryExtent() {
        let node = makeBoxNode(width: 2, height: 4, length: 1)
        let (lo, hi) = SceneKitGeometry.boundingBox(of: node)
        XCTAssertEqual(hi.x - lo.x, 2, accuracy: 0.001)
        XCTAssertEqual(hi.y - lo.y, 4, accuracy: 0.001)
        XCTAssertEqual(hi.z - lo.z, 1, accuracy: 0.001)
    }

    @MainActor
    func test_normalizeToHeight_scalesUniformlyToHitTargetHeight() {
        let node = makeBoxNode(width: 2, height: 4, length: 1)
        SceneKitGeometry.normalize(node, toHeight: 1)

        // height(4) -> 1 means scale factor 0.25, applied uniformly to x/y/z
        XCTAssertEqual(node.scale.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(node.scale.y, 0.25, accuracy: 0.0001)
        XCTAssertEqual(node.scale.z, 0.25, accuracy: 0.0001)

        let (lo, hi) = SceneKitGeometry.boundingBox(of: node)
        let scaledHeight = (hi.y - lo.y) * node.scale.y
        XCTAssertEqual(scaledHeight, 1, accuracy: 0.001)
    }

    @MainActor
    func test_normalizeToFootprintWidth_scalesUniformlyUsingLargerOfXOrZ() {
        // x=2, z=1 -> footprint is max(2,1) = 2
        let node = makeBoxNode(width: 2, height: 4, length: 1)
        SceneKitGeometry.normalize(node, toFootprintWidth: 4)

        // footprint(2) -> 4 means scale factor 2.0
        XCTAssertEqual(node.scale.x, 2.0, accuracy: 0.0001)
        XCTAssertEqual(node.scale.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(node.scale.z, 2.0, accuracy: 0.0001)
    }

    @MainActor
    func test_normalize_doesNothingForDegenerateNode() {
        // geometry-less node: bounding box collapses to a single point, height 0
        let node = SCNNode()
        SceneKitGeometry.normalize(node, toHeight: 1)
        XCTAssertEqual(node.scale.x, 1, accuracy: 0.0001)
        XCTAssertEqual(node.scale.y, 1, accuracy: 0.0001)
        XCTAssertEqual(node.scale.z, 1, accuracy: 0.0001)
    }
}
