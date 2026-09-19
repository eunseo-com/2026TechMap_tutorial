import SceneKit
import UIKit

@MainActor
final class ClosedWorld {
    let scene = SCNScene()

    init() {
        scene.background.contents = UIColor.black

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
