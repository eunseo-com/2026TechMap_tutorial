import SceneKit
import UIKit

@MainActor
final class C3ClosedWorld {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pigContainer: SCNNode
    let hideTree: SCNNode
    private(set) var cameraYaw: Float = .pi / 4

    private let orbitRadius: Float = 17
    private let orbitHeight: Float = 12
    private var orthographicScale: CGFloat = 6
    private let directionalLightNode = SCNNode()

    init() {
        let island = C3IslandBuilder.build()
        hideTree = island.childNode(withName: "HideTree", recursively: true) ?? SCNNode()
        pigContainer = C3PigModelFactory.makeContainer(pose: .idle)
        pigContainer.position = island.childNode(withName: "BigPigSpawn", recursively: false)?.position
            ?? SCNVector3(0, 0, 0)

        setupCamera()
        setupLighting()
        scene.rootNode.addChildNode(island)
        scene.rootNode.addChildNode(pigContainer)
    }

    func rotateCamera(byYaw delta: Float) {
        cameraYaw += delta
        updateOrbitPosition()
        directionalLightNode.eulerAngles = lightEulerAngles(for: cameraYaw)
    }

    func zoom(by factor: Float) {
        guard factor > 0 else { return }
        orthographicScale = min(12, max(3, orthographicScale / CGFloat(factor)))
        cameraNode.camera?.orthographicScale = orthographicScale
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = orthographicScale
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera

        let target = SCNNode()
        target.name = "C3OrbitTarget"
        scene.rootNode.addChildNode(target)
        let lookAt = SCNLookAtConstraint(target: target)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        updateOrbitPosition()
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        scene.background.contents = gradientBackground()

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 800
        ambient.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.name = "C3AmbientLight"
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let directional = SCNLight()
        directional.type = .directional
        directional.intensity = 520
        directional.color = UIColor.white
        directional.castsShadow = true
        directional.shadowMode = .deferred
        directional.shadowColor = UIColor(white: 0, alpha: 0.22)
        directional.shadowSampleCount = 12
        directional.shadowRadius = 6
        directionalLightNode.name = "C3DirectionalLight"
        directionalLightNode.light = directional
        directionalLightNode.eulerAngles = lightEulerAngles(for: cameraYaw)
        scene.rootNode.addChildNode(directionalLightNode)
    }

    private func updateOrbitPosition() {
        cameraNode.position = SCNVector3(
            orbitRadius * sin(cameraYaw),
            orbitHeight,
            orbitRadius * cos(cameraYaw)
        )
    }

    private func lightEulerAngles(for yaw: Float) -> SCNVector3 {
        SCNVector3(-.pi / 3, yaw - .pi / 4, 0)
    }

    private func gradientBackground() -> UIImage {
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 4, height: 256)
        layer.colors = [
            UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.639, green: 0.929, blue: 0.992, alpha: 1).cgColor,
            UIColor(red: 0.412, green: 0.804, blue: 0.918, alpha: 1).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 256)).image {
            layer.render(in: $0.cgContext)
        }
    }
}
