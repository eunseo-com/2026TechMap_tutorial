import SceneKit
import UIKit

/// 방을 짓는 빌더. 이 세계에 있는 모든 것 — 벽이든 바닥이든 —은
/// 여기 코드로 써넣은 것만 존재한다. 좌표 원점(0,0,0)도 개발자가 임의로 선언한 것.
enum RoomBuilder {
    static let roomWidth: Float = 4
    static let roomDepth: Float = 4
    static let wallHeight: Float = 2.5
    private static let wallThickness: Float = 0.1

    @MainActor
    static func build() -> SCNNode {
        let room = SCNNode()
        room.name = "Room"
        room.position = SCNVector3(0, 0, 0)   // 좌표 원점을 여기서 임의로 선언한다

        let floor = AssetLoader.object(named: "Ground_Color") {
            AssetLoader.voxelBox(width: CGFloat(roomWidth), height: 0.1, length: CGFloat(roomDepth),
                                  color: UIColor(white: 0.8, alpha: 1))
        }
        floor.name = "Floor"
        floor.position = SCNVector3(0, 0, 0)
        room.addChildNode(floor)

        let wallSpecs: [(name: String, position: SCNVector3, eulerY: Float, width: Float)] = [
            ("Wall_0", SCNVector3(0, wallHeight / 2, -roomDepth / 2), 0, roomWidth),
            ("Wall_1", SCNVector3(0, wallHeight / 2, roomDepth / 2), 0, roomWidth),
            ("Wall_2", SCNVector3(-roomWidth / 2, wallHeight / 2, 0), .pi / 2, roomDepth),
            ("Wall_3", SCNVector3(roomWidth / 2, wallHeight / 2, 0), .pi / 2, roomDepth)
        ]
        for spec in wallSpecs {
            let wall = AssetLoader.voxelBox(width: CGFloat(spec.width), height: CGFloat(wallHeight),
                                             length: CGFloat(wallThickness), color: UIColor(white: 0.95, alpha: 1))
            wall.name = spec.name
            wall.position = spec.position
            wall.eulerAngles = SCNVector3(0, spec.eulerY, 0)
            room.addChildNode(wall)
        }

        return room
    }
}
