import XCTest
import SceneKit
@testable import PiggyEscape

final class RoomBuilderTests: XCTestCase {
    private func bounds(of node: SCNNode, in referenceNode: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minPoint = SCNVector3(Float.greatestFiniteMagnitude,
                                  Float.greatestFiniteMagnitude,
                                  Float.greatestFiniteMagnitude)
        var maxPoint = SCNVector3(-Float.greatestFiniteMagnitude,
                                  -Float.greatestFiniteMagnitude,
                                  -Float.greatestFiniteMagnitude)

        node.enumerateHierarchy { child, _ in
            guard let geometry = child.geometry else { return }
            let (minBounds, maxBounds) = geometry.boundingBox
            for x in [minBounds.x, maxBounds.x] {
                for y in [minBounds.y, maxBounds.y] {
                    for z in [minBounds.z, maxBounds.z] {
                        let point = child.convertPosition(SCNVector3(x, y, z), to: referenceNode)
                        minPoint = SCNVector3(min(minPoint.x, point.x),
                                              min(minPoint.y, point.y),
                                              min(minPoint.z, point.z))
                        maxPoint = SCNVector3(max(maxPoint.x, point.x),
                                              max(maxPoint.y, point.y),
                                              max(maxPoint.z, point.z))
                    }
                }
            }
        }

        return (minPoint, maxPoint)
    }

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

    @MainActor
    func test_build_orientsAndFitsBundledFloorInsideRoom() {
        let room = RoomBuilder.build()
        guard let floor = room.childNode(withName: "Floor", recursively: false) else {
            XCTFail("expected Floor node")
            return
        }

        let (minPoint, maxPoint) = bounds(of: floor, in: room)
        XCTAssertEqual(maxPoint.x - minPoint.x, RoomBuilder.roomWidth, accuracy: 0.1)
        XCTAssertEqual(maxPoint.z - minPoint.z, RoomBuilder.roomDepth, accuracy: 0.1)
        XCTAssertLessThan(maxPoint.y - minPoint.y, 0.2, "floor must stay flat instead of filling the room vertically")
        XCTAssertEqual(minPoint.y, 0, accuracy: 0.001, "floor must meet the room origin")
        XCTAssertLessThanOrEqual(maxPoint.y, 0.2, "floor must not rise into the camera view")
    }
}
