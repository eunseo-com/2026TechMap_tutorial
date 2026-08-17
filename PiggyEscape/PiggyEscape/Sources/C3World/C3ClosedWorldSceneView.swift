import SceneKit
import SpriteKit
import SwiftUI

struct C3ClosedWorldSceneView: UIViewRepresentable {
    private let onNarrationFinished: () -> Void
    private let onDiscovered: () -> Void

    init(
        onNarrationFinished: @escaping () -> Void = {},
        onDiscovered: @escaping () -> Void = {}
    ) {
        self.onNarrationFinished = onNarrationFinished
        self.onDiscovered = onDiscovered
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let world = context.coordinator.world
        let overlay = context.coordinator.overlay
        view.scene = world.scene
        view.pointOfView = world.cameraNode
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.overlaySKScene = overlay

        context.coordinator.installCallbacks()
        context.coordinator.scnView = view

        view.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        ))
        view.addGestureRecognizer(UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        ))
        view.addGestureRecognizer(UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        ))

        overlay.showOpeningNarration { [weak world] in
            world?.completeOpeningNarration()
            onNarrationFinished()
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.cancelAutomaticDiscovery()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDiscovered: onDiscovered)
    }

    @MainActor
    final class Coordinator: NSObject {
        let world = C3ClosedWorld()
        let overlay = NarrationOverlayScene(size: UIScreen.main.bounds.size)
        weak var scnView: SCNView?

        private let onDiscovered: () -> Void
        private var autoDiscoveryTask: Task<Void, Never>?

        init(onDiscovered: @escaping () -> Void) {
            self.onDiscovered = onDiscovered
        }

        deinit {
            autoDiscoveryTask?.cancel()
        }

        func installCallbacks() {
            world.onTreeHideFinished = { [weak self] in
                self?.scheduleAutomaticDiscovery()
            }
            world.onSurpriseCaption = { [weak self, weak overlay] caption in
                guard caption == "아, 들켰네… 제대로 숨고 싶은데." else { return }
                overlay?.showSurpriseCaption()
                self?.onDiscovered()
            }
        }

        func cancelAutomaticDiscovery() {
            autoDiscoveryTask?.cancel()
            autoDiscoveryTask = nil
        }

        private func scheduleAutomaticDiscovery() {
            cancelAutomaticDiscovery()
            autoDiscoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(C3AutoAdvance.treeArrivalDelay * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                _ = self.world.automaticallyDiscoverAfterTreeHide()
                self.autoDiscoveryTask = nil
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView,
                  let hit = scnView.hitTest(gesture.location(in: scnView), options: nil).first,
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

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.numberOfTouches == 2 else { return }
            world.zoom(by: Float(gesture.scale))
            gesture.scale = 1
        }

        private func isEscapePigDescendant(_ node: SCNNode) -> Bool {
            var current: SCNNode? = node
            while let candidate = current {
                if candidate === world.pigContainer { return true }
                current = candidate.parent
            }
            return false
        }
    }
}
