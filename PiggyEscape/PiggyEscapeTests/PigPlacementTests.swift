import XCTest
import SceneKit
@testable import PiggyEscape

final class PigPlacementTests: XCTestCase {
    @MainActor
    func test_makePigNode_isNamedPiggy() {
        let pig = PigPlacement.makePigNode()
        XCTAssertEqual(pig.name, "Piggy")
    }

    @MainActor
    func test_makePigNode_isPlacedAtHardcodedPosition() {
        let pig = PigPlacement.makePigNode()
        XCTAssertEqual(pig.position.x, PigPlacement.hardcodedPosition.x, accuracy: 0.0001)
        XCTAssertEqual(pig.position.y, PigPlacement.hardcodedPosition.y, accuracy: 0.0001)
        XCTAssertEqual(pig.position.z, PigPlacement.hardcodedPosition.z, accuracy: 0.0001)
    }

    @MainActor
    func test_makePigNode_standsOnTheRoomFloor() {
        let pig = PigPlacement.makePigNode()
        let sceneRoot = SCNNode()
        sceneRoot.addChildNode(pig)
        let (lo, hi) = SceneKitGeometry.boundingBox(of: sceneRoot)

        XCTAssertEqual(lo.y, 0, accuracy: 0.001, "the pig's feet should meet the room floor")
        XCTAssertEqual(hi.y - lo.y, 0.6, accuracy: 0.01)
    }

    @MainActor
    func test_makePigNode_hasGeometryOrChildGeometry() {
        let pig = PigPlacement.makePigNode()
        XCTAssertTrue(hasGeometryDeep(pig))
    }

    /// The bundled "Piggy" asset nests its geometry several levels below the
    /// wrapper node AssetLoader.object(named:) returns (wrapper -> root ->
    /// body/eyes/tail meshes). This test walks the full hierarchy to confirm
    /// makePigNode() is actually placing the real model and not silently
    /// falling back to the placeholder voxel box.
    @MainActor
    func test_makePigNode_placesRealModel_notVoxelFallback() {
        let pig = PigPlacement.makePigNode()
        XCTAssertTrue(hasGeometryDeep(pig), "expected geometry somewhere in the node's subtree")

        var geometryNodeCount = 0
        pig.enumerateHierarchy { node, _ in
            if node.geometry != nil { geometryNodeCount += 1 }
        }
        // The real Piggy.usdc model is made of multiple meshes (body/eyes/tail),
        // while the voxel fallback is a single SCNBox node. More than one
        // geometry-bearing node means the real model was placed, not the fallback.
        XCTAssertGreaterThan(geometryNodeCount, 1, "expected multiple meshes from the real Piggy model, not the single-box fallback")
    }

    /// Deep traversal of the node hierarchy, mirroring
    /// SceneKitGeometry.boundingBox(of:), instead of a shallow one-level check.
    @MainActor
    private func hasGeometryDeep(_ node: SCNNode) -> Bool {
        var found = false
        node.enumerateHierarchy { child, stop in
            if child.geometry != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
