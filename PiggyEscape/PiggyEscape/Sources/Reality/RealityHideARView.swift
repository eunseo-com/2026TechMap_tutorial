import ARKit
import Combine
import RealityKit
import SwiftUI

enum RealityProjectionGate {
    static func canObserve(
        projectedPoint: CGPoint?,
        viewportBounds: CGRect,
        pigPosition: SIMD3<Float>,
        cameraTransform: simd_float4x4
    ) -> Bool {
        guard let projectedPoint,
              !viewportBounds.isEmpty,
              viewportBounds.contains(projectedPoint) else {
            return false
        }

        let cameraPosition = SIMD3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -SIMD3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        return simd_dot(cameraForward, pigPosition - cameraPosition) > 0
    }
}

enum RealityInitialPigPlacement {
    static func position(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        floorY: Float
    ) -> SIMD3<Float>? {
        guard cameraPosition.x.isFinite,
              cameraPosition.y.isFinite,
              cameraPosition.z.isFinite,
              cameraForward.x.isFinite,
              cameraForward.y.isFinite,
              cameraForward.z.isFinite,
              floorY.isFinite,
              floorY < cameraPosition.y - 0.2 else {
            return nil
        }

        let horizontalForward = SIMD3(cameraForward.x, 0, cameraForward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return nil }
        let direction = horizontalForward / length
        return SIMD3(
            cameraPosition.x + direction.x * 0.8,
            floorY,
            cameraPosition.z + direction.z * 0.8
        )
    }
}

struct RealityHideARView: UIViewRepresentable {
    let onScanningReady: () -> Void
    let onTargetAccepted: () -> Void
    let onPigReachedTarget: () -> Void
    let onRevealed: () -> Void
    let onUnavailable: () -> Void
    let onMessage: (String) -> Void

    init(
        onScanningReady: @escaping () -> Void,
        onTargetAccepted: @escaping () -> Void,
        onPigReachedTarget: @escaping () -> Void,
        onRevealed: @escaping () -> Void,
        onUnavailable: @escaping () -> Void,
        onMessage: @escaping (String) -> Void
    ) {
        self.onScanningReady = onScanningReady
        self.onTargetAccepted = onTargetAccepted
        self.onPigReachedTarget = onPigReachedTarget
        self.onRevealed = onRevealed
        self.onUnavailable = onUnavailable
        self.onMessage = onMessage
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            meshSupport: SystemRealityMeshSupport(),
            onScanningReady: onScanningReady,
            onTargetAccepted: onTargetAccepted,
            onPigReachedTarget: onPigReachedTarget,
            onRevealed: onRevealed,
            onUnavailable: onUnavailable,
            onMessage: onMessage
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        private enum HideState {
            case waitingForTarget
            case walking
            case hidden
            case revealing
            case revealed
        }

        private let meshSupport: any RealityMeshSupporting
        private let visualController: RealityPigVisualController
        private let onScanningReady: () -> Void
        private let onTargetAccepted: () -> Void
        private let onPigReachedTarget: () -> Void
        private let onRevealed: () -> Void
        private let onUnavailable: () -> Void
        private let onMessage: (String) -> Void

        private weak var arView: ARView?
        private var revealMonitor = RealityRevealMonitor()
        private var revealSubscription: (any Cancellable)?
        private var hideState = HideState.waitingForTarget
        private var pigAnchor: AnchorEntity?

        private(set) var didStartMeshSession = false

        var canStartMeshSession: Bool {
            meshSupport.supportsMeshWithClassification
        }

        init(
            meshSupport: any RealityMeshSupporting,
            visualController: RealityPigVisualController? = nil,
            onScanningReady: @escaping () -> Void = {},
            onTargetAccepted: @escaping () -> Void = {},
            onPigReachedTarget: @escaping () -> Void = {},
            onRevealed: @escaping () -> Void = {},
            onUnavailable: @escaping () -> Void = {},
            onMessage: @escaping (String) -> Void = { _ in }
        ) {
            self.meshSupport = meshSupport
            self.visualController = visualController ?? RealityPigVisualController()
            self.onScanningReady = onScanningReady
            self.onTargetAccepted = onTargetAccepted
            self.onPigReachedTarget = onPigReachedTarget
            self.onRevealed = onRevealed
            self.onUnavailable = onUnavailable
            self.onMessage = onMessage
        }

        func attach(to arView: ARView) {
            self.arView = arView
            guard startMeshSessionIfSupported(in: arView) else { return }

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(visualController.outerEntity)
            arView.scene.addAnchor(anchor)
            pigAnchor = anchor
            visualController.loadIdlePig()

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTouchesRequired = 1
            arView.addGestureRecognizer(tap)
            onScanningReady()
        }

        @discardableResult
        func startMeshSessionIfSupported() -> Bool {
            guard canStartMeshSession else {
                reportUnavailable()
                return false
            }
            guard let arView else { return false }
            return startMeshSessionIfSupported(in: arView)
        }

        func message(for rejection: RealityHideRejection) -> String {
            switch rejection {
            case .selectVerticalSide:
                RealityAvailabilityMessage.selectVerticalSide
            case .moveFartherAway:
                RealityAvailabilityMessage.moveFartherAway
            case .findFloor:
                RealityAvailabilityMessage.scanFirst
            }
        }

        @discardableResult
        func processRevealFrame(
            isObservationValid: Bool,
            meshDistance: Float?,
            pigDistance: Float
        ) -> Bool {
            guard isObservationValid,
                  hideState == .hidden,
                  revealMonitor.update(meshDistance: meshDistance, pigDistance: pigDistance) else {
                return false
            }

            hideState = .revealing
            revealSubscription?.cancel()
            revealSubscription = nil
            visualController.showSurprised { [weak self] in
                guard let self, self.hideState == .revealing else { return }
                self.visualController.playSurpriseScale()
                self.hideState = .revealed
                self.onRevealed()
            }
            return true
        }

        func acceptHideTarget(destination: SIMD3<Float>, initialPosition: SIMD3<Float>) {
            guard hideState == .waitingForTarget else { return }
            hideState = .walking
            visualController.outerEntity.setPosition(initialPosition, relativeTo: nil)
            visualController.outerEntity.isEnabled = true
            onTargetAccepted()
            visualController.walk(to: destination) { [weak self] in
                guard let self else { return }
                self.hideState = .hidden
                self.onPigReachedTarget()
                if let arView = self.arView {
                    self.beginRevealMonitoring(in: arView)
                }
            }
        }

        func stop() {
            revealSubscription?.cancel()
            revealSubscription = nil
            arView?.session.pause()
            didStartMeshSession = false
        }

        private func startMeshSessionIfSupported(in arView: ARView) -> Bool {
            guard canStartMeshSession else {
                reportUnavailable()
                return false
            }
            guard !didStartMeshSession else { return true }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.sceneReconstruction = .meshWithClassification
            arView.environment.sceneUnderstanding.options = [
                .occlusion,
                .collision,
                .physics,
                .receivesLighting
            ]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            didStartMeshSession = true
            return true
        }

        private func reportUnavailable() {
            onUnavailable()
            onMessage(RealityAvailabilityMessage.unavailable)
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  hideState == .waitingForTarget,
                  let arView,
                  let frame = arView.session.currentFrame else { return }

            let screenPoint = recognizer.location(in: arView)
            guard let hit = arView.hitTest(
                screenPoint,
                query: .nearest,
                mask: .sceneUnderstanding
            ).first else {
                onMessage(RealityAvailabilityMessage.scanFirst)
                return
            }

            let cameraPosition = Self.position(from: frame.camera.transform)
            let floor = nearestFloor(in: frame, to: hit.position)
            let result = RealityHidePlanner.plan(
                hit: RealitySurfaceHit(point: hit.position, normal: hit.normal),
                cameraPosition: cameraPosition,
                floor: floor
            )

            switch result {
            case let .rejected(rejection):
                onMessage(message(for: rejection))
            case let .accepted(destination):
                let cameraForward = -SIMD3(
                    frame.camera.transform.columns.2.x,
                    frame.camera.transform.columns.2.y,
                    frame.camera.transform.columns.2.z
                )
                guard let initialPosition = RealityInitialPigPlacement.position(
                    cameraPosition: cameraPosition,
                    cameraForward: cameraForward,
                    floorY: destination.y
                ) else {
                    onMessage(RealityAvailabilityMessage.scanFirst)
                    return
                }
                acceptHideTarget(destination: destination, initialPosition: initialPosition)
            }
        }

        private func nearestFloor(in frame: ARFrame, to surfacePoint: SIMD3<Float>) -> RealityFloor? {
            frame.anchors
                .compactMap { $0 as? ARPlaneAnchor }
                .filter { $0.alignment == .horizontal && $0.classification == .floor }
                .map { anchor in
                    let center = SIMD4<Float>(anchor.center.x, anchor.center.y, anchor.center.z, 1)
                    let world = anchor.transform * center
                    return RealityFloor(point: SIMD3(world.x, world.y, world.z))
                }
                .min { lhs, rhs in
                    let lhsOffset = SIMD2(lhs.point.x - surfacePoint.x, lhs.point.z - surfacePoint.z)
                    let rhsOffset = SIMD2(rhs.point.x - surfacePoint.x, rhs.point.z - surfacePoint.z)
                    return simd_length_squared(lhsOffset) < simd_length_squared(rhsOffset)
                }
        }

        private func beginRevealMonitoring(in arView: ARView) {
            revealMonitor = RealityRevealMonitor()
            revealSubscription?.cancel()
            revealSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self, let arView else { return }
                self.evaluateReveal(in: arView)
            }
        }

        private func evaluateReveal(in arView: ARView) {
            let pigPosition = visualController.worldPosition
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            let screenPoint = arView.project(pigPosition)
            guard RealityProjectionGate.canObserve(
                projectedPoint: screenPoint,
                viewportBounds: arView.bounds,
                pigPosition: pigPosition,
                cameraTransform: cameraTransform
            ), let screenPoint else { return }

            let cameraPosition = Self.position(from: cameraTransform)
            let meshDistance = arView.hitTest(
                screenPoint,
                query: .nearest,
                mask: .sceneUnderstanding
            ).first.map { simd_distance(cameraPosition, $0.position) }
            let pigDistance = simd_distance(cameraPosition, pigPosition)
            processRevealFrame(
                isObservationValid: true,
                meshDistance: meshDistance,
                pigDistance: pigDistance
            )
        }

        private static func position(from transform: simd_float4x4) -> SIMD3<Float> {
            SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
    }
}
