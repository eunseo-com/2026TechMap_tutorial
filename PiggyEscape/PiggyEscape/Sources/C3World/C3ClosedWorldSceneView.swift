import SceneKit
import SpriteKit
import SwiftUI

protocol C3AutoDiscoveryCancellable: AnyObject, Sendable {
    func cancel()
}

@MainActor
protocol C3AutoDiscoveryScheduling {
    @discardableResult
    func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> C3AutoDiscoveryCancellable
}

final class C3TaskAutoDiscoveryScheduler: C3AutoDiscoveryScheduling {
    func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> C3AutoDiscoveryCancellable {
        C3TaskAutoDiscoveryCancellable(
            task: Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                operation()
            }
        )
    }
}

private final class C3TaskAutoDiscoveryCancellable: C3AutoDiscoveryCancellable {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }
}

struct C3ClosedWorldSceneView: UIViewRepresentable {
    private let reduceMotionEnabled: Bool
    private let onNarrationFinished: () -> Void
    private let onDiscovered: () -> Void

    init(
        reduceMotionEnabled: Bool = false,
        onNarrationFinished: @escaping () -> Void = {},
        onDiscovered: @escaping () -> Void = {}
    ) {
        self.reduceMotionEnabled = reduceMotionEnabled
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

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.world.updateReduceMotionEnabled(reduceMotionEnabled)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.cancelAutomaticDiscovery()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDiscovered: onDiscovered,
            reduceMotionEnabled: reduceMotionEnabled
        )
    }

    @MainActor
    final class Coordinator: NSObject {
        let world: C3ClosedWorld
        let overlay = NarrationOverlayScene(size: UIScreen.main.bounds.size)
        weak var scnView: SCNView?

        private let onDiscovered: () -> Void
        private let autoDiscoveryScheduler: C3AutoDiscoveryScheduling
        private var autoDiscoveryTask: C3AutoDiscoveryCancellable?

        init(
            onDiscovered: @escaping () -> Void,
            reduceMotionEnabled: Bool = false,
            autoDiscoveryScheduler: C3AutoDiscoveryScheduling? = nil
        ) {
            self.world = C3ClosedWorld(reduceMotionEnabled: reduceMotionEnabled)
            self.onDiscovered = onDiscovered
            self.autoDiscoveryScheduler = autoDiscoveryScheduler ?? C3TaskAutoDiscoveryScheduler()
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
            autoDiscoveryTask = autoDiscoveryScheduler.schedule(
                after: C3AutoAdvance.treeArrivalDelay
            ) { [weak self] in
                guard let self else { return }
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
