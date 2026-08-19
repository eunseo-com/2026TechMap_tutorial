import SceneKit
import UIKit

@objc func handleTap(_ gesture: UITapGestureRecognizer) {
    guard let scnView,
          let hit = scnView.hitTest(
              gesture.location(in: scnView), options: nil
          ).first,
          isEscapePigDescendant(hit.node) else {
        return
    }
    _ = world.tapPig()
}

@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
    guard let scnView, scnView.bounds.width > 0 else { return }
    let translation = gesture.translation(in: scnView)
    let yawDelta = -Float(translation.x / scnView.bounds.width) * .pi
    world.rotateCamera(byYaw: yawDelta)
    gesture.setTranslation(.zero, in: scnView)
}

private func isEscapePigDescendant(_ node: SCNNode) -> Bool {
    var current: SCNNode? = node
    while let candidate = current {
        if candidate === world.pigContainer { return true }
        current = candidate.parent
    }
    return false
}
