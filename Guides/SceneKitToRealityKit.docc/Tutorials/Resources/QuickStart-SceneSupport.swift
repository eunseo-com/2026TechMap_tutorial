import SceneKit
import SwiftUI
import UIKit

// 기본 실습에서 읽거나 수정할 필요 없는 준비 코드입니다.
// 자세한 설명은 “선택 학습: 방을 만드는 코드 읽기”를 참고하세요.

// SwiftUI 안에 SceneKit 화면을 놓는 연결부입니다.
@MainActor
struct ClosedWorldSceneView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        // 모델 파일에 들어 있는 카메라 대신 실습용 카메라를 선택합니다.
        view.pointOfView = scene.rootNode.childNode(withName: "Camera", recursively: false)
        view.backgroundColor = .black
        view.allowsCameraControl = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// 모델 파일을 찾고, 없으면 지정한 대체 물체를 만듭니다.
enum AssetLoader {
    @MainActor
    static func object(
        named name: String,
        fallback: @MainActor () -> SCNNode
    ) -> SCNNode {
        object(named: name) ?? fallback()
    }

    @MainActor
    static func object(named name: String) -> SCNNode? {
        for ext in ["usdz", "usdc", "usda"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let scene = try? SCNScene(url: url, options: nil) {
                return wrap(scene)
            }
        }
        return nil
    }

    static func voxelBox(
        width: CGFloat,
        height: CGFloat,
        length: CGFloat,
        color: UIColor
    ) -> SCNNode {
        let box = SCNBox(
            width: width * 0.96,
            height: height * 0.96,
            length: length * 0.96,
            chamferRadius: 0.02
        )
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .blinn
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    // 모델의 원래 크기에 관계없이 지정한 크기로 맞춥니다.
    static func fit(_ node: SCNNode, width: Float, height: Float, length: Float) {
        let (low, high) = node.boundingBox
        let size = SCNVector3(high.x - low.x, high.y - low.y, high.z - low.z)
        guard size.x > 0, size.y > 0, size.z > 0 else { return }
        node.pivot = SCNMatrix4MakeTranslation(
            (low.x + high.x) / 2, (low.y + high.y) / 2, (low.z + high.z) / 2
        )
        node.scale = SCNVector3(width / size.x, height / size.y, length / size.z)
    }

    private static func wrap(_ scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        scene.rootNode.childNodes.forEach { node.addChildNode($0.clone()) }
        return node
    }
}

@MainActor
enum RoomBuilder {
    static func build() -> SCNNode {
        let room = SCNNode()
        room.name = "Room"

        let floor = AssetLoader.object(named: "Ground_Color") {
            AssetLoader.voxelBox(width: 8, height: 0.2, length: 8, color: .darkGray)
        }
        AssetLoader.fit(floor, width: 8, height: 0.2, length: 8)
        floor.name = "Floor"
        floor.position = SCNVector3(0, -0.1, 0)
        room.addChildNode(floor)

        let wallSize = (width: CGFloat(8), height: CGFloat(3), length: CGFloat(0.2))
        let walls: [(name: String, position: SCNVector3, yaw: Float)] = [
            ("Wall_North", SCNVector3(0, 1.5, -4), 0),
            ("Wall_South", SCNVector3(0, 1.5, 4), 0),
            ("Wall_West", SCNVector3(-4, 1.5, 0), .pi / 2),
            ("Wall_East", SCNVector3(4, 1.5, 0), .pi / 2)
        ]

        for wall in walls {
            let node = AssetLoader.voxelBox(
                width: wallSize.width,
                height: wallSize.height,
                length: wallSize.length,
                color: .systemIndigo
            )
            node.name = wall.name
            node.position = wall.position
            node.eulerAngles.y = wall.yaw
            room.addChildNode(node)
        }
        return room
    }
}

@MainActor
final class ClosedWorld {
    let scene = SCNScene()
    let pigNode = PigPlacement.makePigNode()
    init() {
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode(RoomBuilder.build())
        scene.rootNode.addChildNode(pigNode)
        scene.rootNode.addChildNode(FakeSofa.makeSofaNode())
        addCamera()
        addLight()
    }

    private func addCamera() {
        let camera = SCNNode()
        camera.name = "Camera"
        camera.camera = SCNCamera()
        // 앞쪽 벽 너머로 방 안을 내려다봅니다.
        camera.position = SCNVector3(0, 24, 18)
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
    }

    private func addLight() {
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 1_100
        light.position = SCNVector3(0, 8, 3)
        scene.rootNode.addChildNode(light)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)
    }
}

@MainActor
enum PigPlacement {
    static let hardcodedPosition = SCNVector3(0, 0, 1.5)

    static func makePigNode() -> SCNNode {
        let pig = SCNNode()
        if let model = AssetLoader.object(named: "Piggy") {
            // 제공된 모델의 Z-up 축을 SceneKit의 Y-up에 맞춥니다.
            model.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi)
            pig.addChildNode(model)
        } else {
            pig.addChildNode(AssetLoader.voxelBox(
                width: 1, height: 0.8, length: 0.7, color: .systemPink
            ))
        }
        pig.name = "Piggy"
        let groundedY = normalize(pig, toHeight: 1.5)
        pig.position = SCNVector3(
            hardcodedPosition.x,
            hardcodedPosition.y + groundedY,
            hardcodedPosition.z
        )
        return pig
    }

    /// 자식 노드의 모양을 모두 재서 모델 크기를 맞춥니다.
    private static func normalize(_ node: SCNNode, toHeight targetHeight: Float) -> Float {
        guard let (low, high) = unionBoundingBox(in: node) else { return 0 }
        let height = high.y - low.y
        guard height > 0.0001 else { return 0 }

        let scale = targetHeight / height
        node.scale = SCNVector3(scale, scale, scale)
        return -low.y * scale
    }

    private static func unionBoundingBox(in root: SCNNode) -> (SCNVector3, SCNVector3)? {
        var low = SCNVector3(
            Float.greatestFiniteMagnitude,
            Float.greatestFiniteMagnitude,
            Float.greatestFiniteMagnitude
        )
        var high = SCNVector3(
            -Float.greatestFiniteMagnitude,
            -Float.greatestFiniteMagnitude,
            -Float.greatestFiniteMagnitude
        )
        var foundGeometry = false

        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let (minimum, maximum) = geometry.boundingBox
            for x in [minimum.x, maximum.x] {
                for y in [minimum.y, maximum.y] {
                    for z in [minimum.z, maximum.z] {
                        let point = node.convertPosition(SCNVector3(x, y, z), to: root)
                        low = SCNVector3(min(low.x, point.x), min(low.y, point.y), min(low.z, point.z))
                        high = SCNVector3(max(high.x, point.x), max(high.y, point.y), max(high.z, point.z))
                        foundGeometry = true
                    }
                }
            }
        }
        return foundGeometry ? (low, high) : nil
    }
}

@MainActor
enum FakeSofa {
    static let hardcodedPosition = SCNVector3(1.5, 0, -2.0)

    static func makeSofaNode() -> SCNNode {
        let sofa = AssetLoader.object(named: "Wood_Color") {
            AssetLoader.voxelBox(width: 2, height: 0.8, length: 0.8, color: .brown)
        }
        AssetLoader.fit(sofa, width: 2, height: 0.8, length: 0.8)
        sofa.name = "FakeSofa"
        sofa.position = SCNVector3(hardcodedPosition.x, 0.4, hardcodedPosition.z)
        return sofa
    }
}

@MainActor
final class LessonWorld {
    private let world = ClosedWorld()
    var scene: SCNScene { world.scene }
    var pigNode: SCNNode { world.pigNode }

    init(pigX: Float) {
        pigNode.position.x = pigX
    }
}
