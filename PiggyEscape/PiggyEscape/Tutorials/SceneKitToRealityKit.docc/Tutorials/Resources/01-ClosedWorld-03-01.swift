import SceneKit

@MainActor
final class C3DiscoveryReactionLesson {
    private var hideStartYaw: Float?
    private var hasDiscovered = false

    func startHiding(at cameraYaw: Float) {
        hideStartYaw = cameraYaw
        hasDiscovered = false
    }

    func discoverIfNeeded(
        cameraYaw: Float,
        pigIsInsideCameraFrustum: Bool,
        pigContainer: SCNNode,
        installSurprisedModel: () -> Void,
        showCaption: (String) -> Void
    ) {
        guard let hideStartYaw,
              !hasDiscovered,
              abs(wrappedYawDelta(cameraYaw - hideStartYaw)) >= 0.70,
              pigIsInsideCameraFrustum else {
            return
        }

        hasDiscovered = true
        installSurprisedModel()
        let grow = SCNAction.scale(to: 1.5, duration: 0.16)
        grow.timingMode = .easeOut
        let restore = SCNAction.scale(to: 1.0, duration: 0.34)
        restore.timingMode = .easeInEaseOut
        pigContainer.runAction(.sequence([grow, restore]), forKey: "escapePig.surpriseScale")
        showCaption("아, 들켰네… 제대로 숨고 싶은데.")
    }

    private func wrappedYawDelta(_ angle: Float) -> Float {
        var result = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if result > .pi { result -= 2 * .pi }
        if result < -.pi { result += 2 * .pi }
        return result
    }
}
