import XCTest
import SceneKit
@testable import PiggyEscape

final class RoomBuilderTests: XCTestCase {
    @MainActor
    func test_build_returnsRoomWithFloorAndFourWalls() {
        let room = RoomBuilder.build()
        XCTAssertEqual(room.name, "Room")

        let floor = room.childNode(withName: "Floor", recursively: false)
        XCTAssertNotNil(floor)

        let walls = (0..<4).compactMap { room.childNode(withName: "Wall_\($0)", recursively: false) }
        XCTAssertEqual(walls.count, 4)
    }

    @MainActor
    func test_build_wallsAreDeclaredBoxGeometry() {
        let room = RoomBuilder.build()
        for i in 0..<4 {
            let wall = room.childNode(withName: "Wall_\(i)", recursively: false)
            XCTAssertTrue(wall?.geometry is SCNBox, "Wall_\(i) should be a plain SCNBox — C3_Piggy has no wall asset")
        }
    }

    @MainActor
    func test_build_originIsDeclaredAtRoomCenter() {
        let room = RoomBuilder.build()
        XCTAssertEqual(room.position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(room.position.y, 0, accuracy: 0.0001)
        XCTAssertEqual(room.position.z, 0, accuracy: 0.0001)
    }
}
