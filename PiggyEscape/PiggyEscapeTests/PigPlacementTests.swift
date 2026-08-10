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
    func test_makePigNode_hasGeometryOrChildGeometry() {
        let pig = PigPlacement.makePigNode()
        let hasGeometry = pig.geometry != nil || pig.childNodes.contains { $0.geometry != nil }
        XCTAssertTrue(hasGeometry)
    }
}
