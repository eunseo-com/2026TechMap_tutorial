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
        hit: RealitySurfaceHit,
        destination: SIMD3<Float>,
        floorY: Float
    ) -> SIMD3<Float>? {
        guard cameraPosition.x.isFinite,
              cameraPosition.y.isFinite,
              cameraPosition.z.isFinite,
              hit.point.x.isFinite,
              hit.point.y.isFinite,
              hit.point.z.isFinite,
              hit.normal.x.isFinite,
              hit.normal.y.isFinite,
              hit.normal.z.isFinite,
              destination.x.isFinite,
              destination.y.isFinite,
              destination.z.isFinite,
              floorY.isFinite,
              floorY < cameraPosition.y - 0.2 else {
            return nil
        }

        let horizontalNormal = SIMD3(hit.normal.x, 0, hit.normal.z)
        guard simd_length_squared(horizontalNormal) > 0.0001 else { return nil }
        let normal = simd_normalize(horizontalNormal)
        let cameraOffset = cameraPosition - hit.point
        let towardCamera = simd_dot(normal, cameraOffset) >= 0 ? normal : -normal
        let destinationOffset = destination - hit.point
        guard simd_dot(towardCamera, cameraOffset) > 0,
              simd_dot(towardCamera, destinationOffset) < 0 else {
            return nil
        }

        return SIMD3(
            hit.point.x + towardCamera.x * RealityHidePlanner.objectClearance,
            floorY,
            hit.point.z + towardCamera.z * RealityHidePlanner.objectClearance
        )
    }
}

enum RealityHideARStatus: Equatable {
    case waitingForTarget
    case walking
    case hidden
    case revealing
    case revealed
}

struct RealityHideARView: UIViewRepresentable {
    let onScanningReady: () -> Void
    let onTargetAccepted: () -> Void
    let onPigReachedTarget: () -> Void
    let onRevealed: () -> Void
    let onError: () -> Void
    let onUnavailable: () -> Void
    let onMessage: (String) -> Void

    init(
        onScanningReady: @escaping () -> Void,
        onTargetAccepted: @escaping () -> Void,
        onPigReachedTarget: @escaping () -> Void,
        onRevealed: @escaping () -> Void,
        onError: @escaping () -> Void,
        onUnavailable: @escaping () -> Void,
        onMessage: @escaping (String) -> Void
    ) {
        self.onScanningReady = onScanningReady
        self.onTargetAccepted = onTargetAccepted
        self.onPigReachedTarget = onPigReachedTarget
        self.onRevealed = onRevealed
        self.onError = onError
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
            onError: onError,
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
        private let meshSupport: any RealityMeshSupporting
        private let visualController: RealityPigVisualController
        private let onScanningReady: () -> Void
        private let onTargetAccepted: () -> Void
        private let onPigReachedTarget: () -> Void
        private let onRevealed: () -> Void
        private let onError: () -> Void
        private let onUnavailable: () -> Void
        private let onMessage: (String) -> Void

        private weak var arView: ARView?
        private var revealMonitor = RealityRevealMonitor()
        private var revealSubscription: (any Cancellable)?
        private var pigAnchor: AnchorEntity?

        private(set) var didStartMeshSession = false
        private(set) var status = RealityHideARStatus.waitingForTarget

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
            onError: @escaping () -> Void = {},
            onUnavailable: @escaping () -> Void = {},
            onMessage: @escaping (String) -> Void = { _ in }
        ) {
            self.meshSupport = meshSupport
            self.visualController = visualController ?? RealityPigVisualController()
            self.onScanningReady = onScanningReady
            self.onTargetAccepted = onTargetAccepted
            self.onPigReachedTarget = onPigReachedTarget
            self.onRevealed = onRevealed
            self.onError = onError
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
            visualController.loadIdlePig { [weak self] result in
                guard case .failure = result else { return }
                self?.reportVisualFailure(recoveringTo: .waitingForTarget)
            }

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
                  status == .hidden,
                  revealMonitor.update(meshDistance: meshDistance, pigDistance: pigDistance) else {
                return false
            }

            status = .revealing
            revealSubscription?.cancel()
            revealSubscription = nil
            visualController.showSurprised { [weak self] result in
                guard let self, self.status == .revealing else { return }
                switch result {
                case .success:
                    self.visualController.playSurpriseScale()
                    self.status = .revealed
                    self.onRevealed()
                case .failure:
                    self.reportVisualFailure(recoveringTo: .hidden)
                }
            }
            return true
        }

        func acceptHideTarget(destination: SIMD3<Float>, initialPosition: SIMD3<Float>) {
            guard status == .waitingForTarget else { return }
            status = .walking
            visualController.outerEntity.setPosition(initialPosition, relativeTo: nil)
            visualController.outerEntity.isEnabled = true
            onTargetAccepted()
            visualController.walk(to: destination) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.status = .hidden
                    self.onPigReachedTarget()
                    if let arView = self.arView {
                        self.beginRevealMonitoring(in: arView)
                    }
                case .failure:
                    self.reportVisualFailure(recoveringTo: .waitingForTarget)
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
                  status == .waitingForTarget,
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
            let surfaceHit = RealitySurfaceHit(point: hit.position, normal: hit.normal)
            let result = RealityHidePlanner.plan(
                hit: surfaceHit,
                cameraPosition: cameraPosition,
                floor: floor
            )

            switch result {
            case let .rejected(rejection):
                onMessage(message(for: rejection))
            case let .accepted(destination):
                guard let initialPosition = RealityInitialPigPlacement.position(
                    cameraPosition: cameraPosition,
                    hit: surfaceHit,
                    destination: destination,
                    floorY: destination.y
                ) else {
                    onMessage(RealityAvailabilityMessage.scanFirst)
                    return
                }
                acceptHideTarget(destination: destination, initialPosition: initialPosition)
            }
        }

        private func reportVisualFailure(recoveringTo recoveryStatus: RealityHideARStatus) {
            status = recoveryStatus
            revealMonitor = RealityRevealMonitor()
            if recoveryStatus == .waitingForTarget {
                visualController.outerEntity.isEnabled = false
            } else if recoveryStatus == .hidden {
                visualController.outerEntity.isEnabled = true
                if let arView {
                    beginRevealMonitoring(in: arView)
                }
            }
            onError()
            onMessage(RealityAvailabilityMessage.pigAssetLoadFailed)
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
