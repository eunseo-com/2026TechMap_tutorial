import SceneKit
import XCTest
@testable import PiggyEscape

final class C3IslandBuilderTests: XCTestCase {
    @MainActor
    func test_buildCreatesNamedExistingTreeAndBigPigSpawn() {
        let island = C3IslandBuilder.build()

        XCTAssertEqual(island.name, "C3Island")
        XCTAssertNotNil(island.childNode(withName: "HideTree", recursively: true))
        XCTAssertNotNil(island.childNode(withName: "BigPigSpawn", recursively: true))
    }

    @MainActor
    func test_buildKeepsC3GroundTilesAndDecorationAssets() {
        let island = C3IslandBuilder.build()

        let center = island.childNode(withName: "FlatGround_Center", recursively: false)
        XCTAssertNotNil(center)
        XCTAssertEqual(center?.eulerAngles.x ?? 0, -.pi / 2, accuracy: 0.0001)
        XCTAssertEqual(center?.scale.x ?? 0, sqrt(2), accuracy: 0.0001)
        XCTAssertEqual(island.childNodes.filter { $0.name?.hasPrefix("FlatGround_") == true }.count, 7)
        XCTAssertNotNil(island.childNode(withName: "Decoration_Manger_Color", recursively: true))
        XCTAssertNotNil(island.childNode(withName: "Decoration_Warehouse_Color", recursively: true))
        XCTAssertNotNil(island.childNode(withName: "Decoration_Wood_Color", recursively: true))
    }
}
