import XCTest
import SceneKit
@testable import PiggyEscape

final class AssetLoaderTests: XCTestCase {
    @MainActor
    func test_object_named_loadsBundledPiggyModel() {
        let node = AssetLoader.object(named: "Piggy")
        XCTAssertNotNil(node)
        XCTAssertFalse(node?.childNodes.isEmpty ?? true)
    }

    @MainActor
    func test_c3EscapeAssets_loadFromTheAppBundle() {
        let names = [
            "Ground_Color", "Piggy", "Piggy_running", "Piggy_surprised",
            "Cylinder_Tree1_Color", "Cylinder_Tree2_Color", "Manger_Color",
            "Stone_Color", "Coin_Color", "Warehouse_Color", "Wood_Color"
        ]

        for name in names {
            let node = AssetLoader.object(named: name)
            XCTAssertNotNil(node, "expected bundled C3 asset \(name)")
            XCTAssertFalse(node?.childNodes.isEmpty ?? true, "expected geometry hierarchy for \(name)")
        }
    }

    @MainActor
    func test_object_named_returnsNilForMissingAsset() {
        let node = AssetLoader.object(named: "DoesNotExist")
        XCTAssertNil(node)
    }

    @MainActor
    func test_object_named_fallback_usesFallbackWhenMissing() {
        let node = AssetLoader.object(named: "DoesNotExist") {
            AssetLoader.voxelBox(width: 1, height: 1, length: 1, color: .red)
        }
        XCTAssertNotNil(node.geometry as? SCNBox)
    }

    func test_voxelBox_producesBoxGeometryWithGivenColor() {
        let node = AssetLoader.voxelBox(width: 2, height: 1, length: 3, color: .blue)
        guard let box = node.geometry as? SCNBox else {
            XCTFail("expected SCNBox geometry")
            return
        }
        XCTAssertEqual(box.width, 2 * 0.96, accuracy: 0.0001)
        XCTAssertEqual(box.height, 1 * 0.96, accuracy: 0.0001)
        XCTAssertEqual(box.length, 3 * 0.96, accuracy: 0.0001)
    }
}
