// Production: PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift
// Production: PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/C3ClosedWorldSceneViewOwnershipTests.swift

import SceneKit
import UIKit

@MainActor
final class C3SceneAndInput {
    let scene = SCNScene()
    let sceneView = SCNView()
    let island = SCNNode()
    let hideTree = SCNNode()
    let escapePig = SCNNode()
    let cameraNode = SCNNode()
    let directionalLightNode = SCNNode()

    private(set) var cameraYaw: Float = .pi / 4
    private let orbitRadius: Float = 17
    private let orbitHeight: Float = 12

    init() {
        island.name = "C3Island"
        hideTree.name = "HideTree"
        escapePig.name = "EscapePig"
        cameraNode.camera = SCNCamera()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional

        let orbitTarget = SCNNode()
        orbitTarget.name = "C3OrbitTarget"
        let lookAt = SCNLookAtConstraint(target: orbitTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        island.addChildNode(hideTree)
        scene.rootNode.addChildNode(island)
        scene.rootNode.addChildNode(escapePig)
        scene.rootNode.addChildNode(orbitTarget)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(directionalLightNode)
        updateOrbit()

        sceneView.scene = scene
        sceneView.pointOfView = cameraNode
        sceneView.allowsCameraControl = false
    }

    func acceptsPigTap(at point: CGPoint) -> Bool {
        guard let hit = sceneView.hitTest(point, options: nil).first else {
            return false
        }
        return isDescendant(hit.node, of: escapePig)
    }

    func panVirtualCamera(horizontalTranslation: CGFloat, viewportWidth: CGFloat) {
        guard viewportWidth > 0 else { return }
        cameraYaw -= Float(horizontalTranslation / viewportWidth) * .pi
        updateOrbit()
    }

    private func updateOrbit() {
        cameraNode.position = SCNVector3(
            orbitRadius * sin(cameraYaw),
            orbitHeight,
            orbitRadius * cos(cameraYaw)
        )
        directionalLightNode.eulerAngles = SCNVector3(-.pi / 3, cameraYaw - .pi / 4, 0)
    }

    private func isDescendant(_ node: SCNNode, of ancestor: SCNNode) -> Bool {
        var candidate: SCNNode? = node
        while let current = candidate {
            if current === ancestor { return true }
            candidate = current.parent
        }
        return false
    }
}
