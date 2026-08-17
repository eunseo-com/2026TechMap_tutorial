import SceneKit
import UIKit

enum C3AutoAdvance {
    static let treeArrivalDelay: TimeInterval = 0.40
}

@MainActor
final class C3ClosedWorld {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pigContainer: SCNNode
    let hideTree: SCNNode
    private(set) var cameraYaw: Float = .pi / 4
    private(set) var currentPose: C3PigPose = .idle
    private(set) var lastCaption = ""
    private(set) var surprisePeakScale: CGFloat = 1

    var onSurpriseCaption: ((String) -> Void)?
    var onTreeHideFinished: (() -> Void)?

    private let orbitRadius: Float = 17
    private let orbitHeight: Float = 12
    private var orthographicScale: CGFloat = 6
    private let directionalLightNode = SCNNode()
    private var experience = EscapeExperienceMachine()
    private var treeHideDestination: SCNVector3?
    private var hasDiscovered = false

    init() {
        let island = C3IslandBuilder.build()
        guard let inSceneHideTree = island.childNode(withName: "HideTree", recursively: true) else {
            preconditionFailure("C3 closed world requires the in-scene HideTree")
        }
        hideTree = inSceneHideTree
        pigContainer = C3PigModelFactory.makeContainer(pose: .idle)
        pigContainer.position = island.childNode(withName: "BigPigSpawn", recursively: false)?.position
            ?? SCNVector3(0, 0, 0)

        scene.rootNode.addChildNode(island)
        scene.rootNode.addChildNode(pigContainer)
        setupCamera()
        setupLighting()
    }

    func rotateCamera(byYaw delta: Float) {
        cameraYaw += delta
        updateOrbitPosition()
        directionalLightNode.eulerAngles = lightEulerAngles(for: cameraYaw)
    }

    func completeOpeningNarration() {
        _ = experience.send(.narrationFinished)
    }

    func tapPig() -> Bool {
        guard experience.send(.pigTapped) else { return false }

        setPose(.running)
        let destination = hideDestination()
        treeHideDestination = destination
        facePig(toward: destination)
        let duration = TimeInterval(lengthBetween(pigContainer.position, destination) / 1.1)
        let move = SCNAction.move(to: destination, duration: duration)
        let reachedTree = SCNAction.run { [weak self] _ in
            Task { @MainActor in self?.finishTreeHide() }
        }
        pigContainer.runAction(.sequence([move, reachedTree]), forKey: "escapePig.hide")
        return true
    }

    func finishTreeHideForTesting() {
        pigContainer.removeAction(forKey: "escapePig.hide")
        finishTreeHide()
    }

    @discardableResult
    func automaticallyDiscoverAfterTreeHide() -> Bool {
        guard experience.state == .hiddenInClosedWorld,
              !hasDiscovered,
              experience.send(.closedWorldPigDiscovered) else {
            return false
        }
        hasDiscovered = true
        performSurpriseReaction()
        return true
    }

    func performSurpriseReaction() {
        setPose(.surprised)
        lastCaption = "아, 들켰네… 제대로 숨고 싶은데."
        surprisePeakScale = 1.5

        let grow = SCNAction.scale(to: 1.5, duration: 0.16)
        grow.timingMode = .easeOut
        let restore = SCNAction.scale(to: 1.0, duration: 0.34)
        restore.timingMode = .easeInEaseOut
        pigContainer.runAction(.sequence([grow, restore]), forKey: "escapePig.surpriseScale")
        onSurpriseCaption?(lastCaption)
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

    private func setPose(_ pose: C3PigPose) {
        C3PigModelFactory.setPose(pose, on: pigContainer)
        currentPose = pose
    }

    private func finishTreeHide() {
        guard experience.send(.pigReachedTree) else { return }
        if let treeHideDestination {
            pigContainer.position = treeHideDestination
        }
        setPose(.idle)
        onTreeHideFinished?()
    }

    private func hideDestination() -> SCNVector3 {
        let bounds = geometryBounds(of: hideTree, in: scene.rootNode)
        let center = SIMD3<Float>(
            (bounds.min.x + bounds.max.x) / 2,
            (bounds.min.y + bounds.max.y) / 2,
            (bounds.min.z + bounds.max.z) / 2
        )
        let treeRadius = max(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z) / 2
        let destination = TreeHidePlanner.destination(
            treeCenter: center,
            treeRadius: treeRadius,
            cameraPosition: SIMD3<Float>(cameraNode.position.x, cameraNode.position.y, cameraNode.position.z),
            pigRadius: max(0.25, footprintRadius(of: pigContainer)),
            floorY: pigContainer.position.y
        )
        return SCNVector3(destination.x, destination.y, destination.z)
    }

    private func facePig(toward destination: SCNVector3) {
        let deltaX = destination.x - pigContainer.position.x
        let deltaZ = destination.z - pigContainer.position.z
        guard abs(deltaX) > 0.0001 || abs(deltaZ) > 0.0001 else { return }
        pigContainer.eulerAngles.y = atan2(deltaX, deltaZ)
    }

    private func footprintRadius(of node: SCNNode) -> Float {
        let bounds = geometryBounds(of: node, in: scene.rootNode)
        return max(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z) / 2
    }

    private func geometryBounds(
        of root: SCNNode,
        in coordinateSpace: SCNNode
    ) -> (min: SCNVector3, max: SCNVector3) {
        var minimum = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var maximum = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
        var foundGeometry = false
        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let (lower, upper) = geometry.boundingBox
            for x in [lower.x, upper.x] {
                for y in [lower.y, upper.y] {
                    for z in [lower.z, upper.z] {
                        let point = node.convertPosition(SCNVector3(x, y, z), to: coordinateSpace)
                        minimum = SCNVector3(min(minimum.x, point.x), min(minimum.y, point.y), min(minimum.z, point.z))
                        maximum = SCNVector3(max(maximum.x, point.x), max(maximum.y, point.y), max(maximum.z, point.z))
                        foundGeometry = true
                    }
                }
            }
        }
        precondition(foundGeometry, "C3 closed world requires renderable geometry for HideTree and EscapePig")
        return (minimum, maximum)
    }

    private func lengthBetween(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        let dz = lhs.z - rhs.z
        return sqrt(dx * dx + dy * dy + dz * dz)
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
