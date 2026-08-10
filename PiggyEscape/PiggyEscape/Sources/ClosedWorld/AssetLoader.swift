import SceneKit
import UIKit

/// 3D 모델 파일(.usdz/.usdc/.usda/.obj)을 불러오는 도우미 모음.
/// 모델을 못 찾으면 단순한 정육면체(복셀) 박스로 대신 채운다("폴백").
enum AssetLoader {
    @MainActor
    static func object(named name: String, fallback: @MainActor () -> SCNNode) -> SCNNode {
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
        if let url = Bundle.main.url(forResource: name, withExtension: "obj"),
           let scene = try? SCNScene(url: url, options: [
               .convertToYUp: true,
               .createNormalsIfAbsent: true
           ]) {
            return wrap(scene)
        }
        return nil
    }

    private static func wrap(_ scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        scene.rootNode.childNodes.forEach { node.addChildNode($0.clone()) }
        return node
    }

    static func voxelBox(width: CGFloat, height: CGFloat, length: CGFloat,
                          color: UIColor) -> SCNNode {
        let box = SCNBox(width: width * 0.96,
                          height: height * 0.96,
                          length: length * 0.96,
                          chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .blinn
        box.materials = [mat]
        return SCNNode(geometry: box)
    }
}
