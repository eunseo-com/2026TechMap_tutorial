import SceneKit
import UIKit

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
