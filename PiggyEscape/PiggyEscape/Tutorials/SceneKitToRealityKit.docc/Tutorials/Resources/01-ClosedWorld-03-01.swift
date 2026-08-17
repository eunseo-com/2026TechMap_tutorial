import SceneKit

@MainActor
final class C3DiscoveryReactionLesson {
    private var hasDiscovered = false

    func discoverAfterTreeArrival(
        pigContainer: SCNNode,
        installSurprisedModel: () -> Void,
        showCaption: (String) -> Void
    ) {
        guard !hasDiscovered else { return }

        hasDiscovered = true
        let waitForTreeArrival = SCNAction.wait(duration: 0.40)
        let showDiscovery = SCNAction.run { _ in
            installSurprisedModel()
            showCaption("아, 들켰네… 제대로 숨고 싶은데.")
        }
        let grow = SCNAction.scale(to: 1.5, duration: 0.16)
        grow.timingMode = .easeOut
        let restore = SCNAction.scale(to: 1.0, duration: 0.34)
        restore.timingMode = .easeInEaseOut
        pigContainer.runAction(
            .sequence([waitForTreeArrival, showDiscovery, grow, restore]),
            forKey: "escapePig.automaticDiscovery"
        )
    }
}
