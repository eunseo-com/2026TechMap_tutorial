import SceneKit
import SwiftUI

struct C3ClosedWorldSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let world = context.coordinator.world

        view.scene = world.scene
        view.pointOfView = world.cameraNode
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        return view
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        let world = C3ClosedWorld()
    }
}

@MainActor
final class C3ClosedWorld {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var cameraYaw: Float = .pi / 4

    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 6
        cameraNode.camera = camera

        let target = SCNNode()
        scene.rootNode.addChildNode(target)
        cameraNode.constraints = [SCNLookAtConstraint(target: target)]
        scene.rootNode.addChildNode(cameraNode)
        updateOrbitPosition()
    }

    private func updateOrbitPosition() {
        cameraNode.position = SCNVector3(
            17 * sin(cameraYaw), 12, 17 * cos(cameraYaw)
        )
    }
}
