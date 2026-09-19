import SceneKit
import UIKit

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
