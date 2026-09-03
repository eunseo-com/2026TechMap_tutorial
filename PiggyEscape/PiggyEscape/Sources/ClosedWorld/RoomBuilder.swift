import SceneKit
import UIKit

/// 방을 짓는 빌더. 이 세계에 있는 모든 것 — 벽이든 바닥이든 —은
/// 여기 코드로 써넣은 것만 존재한다. 좌표 원점(0,0,0)도 개발자가 임의로 선언한 것.
enum RoomBuilder {
    static let roomWidth: Float = 4
    static let roomDepth: Float = 4
    static let wallHeight: Float = 2.5
    private static let wallThickness: Float = 0.1
    private static let floorHeight: Float = 0.1

    @MainActor
    static func build() -> SCNNode {
        let room = SCNNode()
        room.name = "Room"
        room.position = SCNVector3(0, 0, 0)   // 좌표 원점을 여기서 임의로 선언한다

        room.addChildNode(makeFloor())

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

    /// `Ground_Color`은 Blender의 Z-up 좌표계로 만들어진 세로 타일이다.
    /// 모델을 먼저 눕히고 실제 크기를 잰 다음, 방의 x/z 면적과 얇은 y 두께에 맞춘다.
    /// 이 순서가 바뀌면 바닥이 세로로 남아 카메라 시야를 가릴 수 있다.
    @MainActor
    private static func makeFloor() -> SCNNode {
        let floor = SCNNode()
        floor.name = "Floor"

        guard let ground = AssetLoader.object(named: "Ground_Color") else {
            let fallback = AssetLoader.voxelBox(width: CGFloat(roomWidth), height: CGFloat(floorHeight),
                                                 length: CGFloat(roomDepth), color: UIColor(white: 0.8, alpha: 1))
            fallback.position = SCNVector3(0, floorHeight / 2, 0)
            floor.addChildNode(fallback)
            return floor
        }

        ground.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        floor.addChildNode(ground)

        let (lo, hi) = SceneKitGeometry.boundingBox(of: floor)
        let width = hi.x - lo.x
        let height = hi.y - lo.y
        let depth = hi.z - lo.z
        guard width > 0.0001, height > 0.0001, depth > 0.0001 else { return floor }

        // `floor`는 회전된 모델을 감싸는 컨테이너다. 여기서 스케일해야 월드의 x/y/z축을
        // 각각 방의 폭/두께/깊이에 맞출 수 있다.
        floor.scale = SCNVector3(roomWidth / width, floorHeight / height, roomDepth / depth)
        floor.position = SCNVector3(
            -(lo.x + hi.x) / 2 * floor.scale.x,
            -lo.y * floor.scale.y,
            -(lo.z + hi.z) / 2 * floor.scale.z
        )
        return floor
    }
}
