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

enum RealityHideARStatus: Equatable {
    case waitingForTarget
    case walking
    case hidden
    case revealing
    case revealed
}

enum RealityHideInteractionMode: Equatable {
    case preparing
    case selectingTarget
    case moving
    case searching
    case revealed
}

struct RealityARSessionStartGate {
    private var hasStarted = false

    mutating func consumeIfReady(
        hasWindow: Bool,
        containerBounds: CGRect,
        arViewBounds: CGRect
    ) -> Bool {
        guard !hasStarted,
              hasWindow,
              !containerBounds.isEmpty,
              !arViewBounds.isEmpty else {
            return false
        }
        hasStarted = true
        return true
    }
}

struct RealityPigSceneAttachmentGate {
    private var hasAttached = false

    mutating func consumeIfReady(hasAcceptedTarget: Bool) -> Bool {
        guard hasAcceptedTarget, !hasAttached else { return false }
        hasAttached = true
        return true
    }
}

final class RealityARSessionContainer: UIView {
    let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
    var onReadyForSession: ((ARView) -> Void)?

    private var startGate = RealityARSessionStartGate()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(arView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        arView.frame = bounds
        startSessionIfReady()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    private func startSessionIfReady() {
        guard startGate.consumeIfReady(
            hasWindow: window != nil,
            containerBounds: bounds,
            arViewBounds: arView.bounds
        ) else { return }
        onReadyForSession?(arView)
    }
}

struct RealityHideARView: UIViewRepresentable {
    let interactionMode: RealityHideInteractionMode
    let onScanningReady: () -> Void
    let onTargetAccepted: () -> Void
    let onPigReachedTarget: () -> Void
    let onRevealed: () -> Void
    let onError: () -> Void
    let onUnavailable: () -> Void
    let onMessage: (String) -> Void

    init(
        interactionMode: RealityHideInteractionMode = .preparing,
        onScanningReady: @escaping () -> Void,
        onTargetAccepted: @escaping () -> Void,
        onPigReachedTarget: @escaping () -> Void,
        onRevealed: @escaping () -> Void,
        onError: @escaping () -> Void,
        onUnavailable: @escaping () -> Void,
        onMessage: @escaping (String) -> Void
    ) {
        self.interactionMode = interactionMode
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
            interactionMode: interactionMode,
            onScanningReady: onScanningReady,
            onTargetAccepted: onTargetAccepted,
            onPigReachedTarget: onPigReachedTarget,
            onRevealed: onRevealed,
            onError: onError,
            onUnavailable: onUnavailable,
            onMessage: onMessage
        )
    }

    func makeUIView(context: Context) -> RealityARSessionContainer {
        let container = RealityARSessionContainer(frame: .zero)
        container.onReadyForSession = { [weak coordinator = context.coordinator] arView in
            coordinator?.attach(to: arView)
        }
        return container
    }

    func updateUIView(_ uiView: RealityARSessionContainer, context: Context) {
        context.coordinator.interactionMode = interactionMode
    }

    static func dismantleUIView(_ uiView: RealityARSessionContainer, coordinator: Coordinator) {
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
        private var environmentReadiness = RealityEnvironmentReadiness()
        private var scanningSubscription: (any Cancellable)?
        private var pigAnchor: AnchorEntity?
        private var pigSceneAttachment = RealityPigSceneAttachmentGate()
        private var hideAttempt: RealityHideAttempt?
        private var hasAttachedToARView = false
        private var didReceiveCameraFrame = false

        private(set) var didStartMeshSession = false
        private(set) var status = RealityHideARStatus.waitingForTarget
        var interactionMode: RealityHideInteractionMode

        var canStartMeshSession: Bool {
            meshSupport.supportsMeshWithClassification
        }

        init(
            meshSupport: any RealityMeshSupporting,
            visualController: RealityPigVisualController? = nil,
            interactionMode: RealityHideInteractionMode = .preparing,
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
            self.interactionMode = interactionMode
            self.onScanningReady = onScanningReady
            self.onTargetAccepted = onTargetAccepted
            self.onPigReachedTarget = onPigReachedTarget
            self.onRevealed = onRevealed
            self.onError = onError
            self.onUnavailable = onUnavailable
            self.onMessage = onMessage
        }

        func attach(to arView: ARView) {
            guard !hasAttachedToARView else { return }
            hasAttachedToARView = true
            self.arView = arView
            guard startMeshSessionIfSupported(in: arView) else { return }

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(visualController.outerEntity)
            pigAnchor = anchor
            visualController.loadIdlePig { [weak self] result in
                guard case .failure = result else { return }
                self?.reportVisualFailure(recoveringTo: .waitingForTarget)
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTouchesRequired = 1
            arView.addGestureRecognizer(tap)
            beginScanningReadiness(in: arView)
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
            pigDistance: Float,
            cameraPose: RealityCameraPose
        ) -> Bool {
            guard status == .hidden else {
                return false
            }
            guard isObservationValid else {
                processInvalidRevealObservation()
                return false
            }
            guard
                  revealMonitor.update(
                    meshDistance: meshDistance,
                    pigDistance: pigDistance,
                    cameraPose: cameraPose
                  ) else {
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

        @discardableResult
        func processScanningObservation(hasMesh: Bool, hasFloor: Bool) -> Bool {
            var becameReady = false
            if hasMesh {
                becameReady = environmentReadiness.observeMesh()
            }
            if hasFloor {
                becameReady = environmentReadiness.observeClassifiedFloor() || becameReady
            }
            guard becameReady else {
                return false
            }
            scanningSubscription?.cancel()
            scanningSubscription = nil
            onScanningReady()
            return true
        }

        @discardableResult
        func processTargetSelection(plan: RealityHidePlan) -> Bool {
            guard interactionMode == .selectingTarget else { return false }
            return acceptHideTarget(plan: plan)
        }

        @discardableResult
        func acceptHideTarget(plan: RealityHidePlan) -> Bool {
            guard status == .waitingForTarget else { return false }
            if let arView, let pigAnchor,
               pigSceneAttachment.consumeIfReady(hasAcceptedTarget: true) {
                arView.scene.addAnchor(pigAnchor)
            }
            status = .walking
            hideAttempt = RealityHideAttempt(plan: plan)
            visualController.outerEntity.setPosition(plan.start, relativeTo: nil)
            visualController.outerEntity.isEnabled = true
            onTargetAccepted()
            walkPiggy(to: plan.destination)
            return true
        }

        func processHideArrival(meshDistance: Float?, pigDistance: Float) {
            guard status == .walking, let hideAttempt else { return }
            switch RealityHideVerificationPolicy.decide(
                meshDistance: meshDistance,
                pigDistance: pigDistance,
                attempt: hideAttempt
            ) {
            case .hidden:
                self.hideAttempt = nil
                status = .hidden
                onPigReachedTarget()
                if let arView {
                    beginRevealMonitoring(in: arView)
                }
            case let .retry(nextAttempt):
                self.hideAttempt = nextAttempt
                walkPiggy(to: nextAttempt.destination)
            case .selectAnotherTarget:
                recoverFromUnverifiedHide()
            }
        }

        private func walkPiggy(to destination: SIMD3<Float>) {
            visualController.walk(to: destination) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.verifyHideAfterWalking()
                case .failure:
                    self.reportVisualFailure(recoveringTo: .waitingForTarget)
                }
            }
        }

        private func verifyHideAfterWalking() {
            guard status == .walking else {
                return
            }
            // Unit tests exercise the verification decision directly without an ARView.
            // A live AR session without a current frame cannot verify occlusion, so it
            // returns to target selection instead of leaving the pig in `.walking`.
            guard let arView else { return }
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                recoverFromUnverifiedHide()
                return
            }
            let pigPosition = visualController.worldPosition
            let screenPoint = arView.project(pigPosition)
            guard RealityProjectionGate.canObserve(
                projectedPoint: screenPoint,
                viewportBounds: arView.bounds,
                pigPosition: pigPosition,
                cameraTransform: cameraTransform
            ), let screenPoint else {
                recoverFromUnverifiedHide()
                return
            }
            let cameraPosition = Self.position(from: cameraTransform)
            let meshDistance = arView.hitTest(
                screenPoint,
                query: .nearest,
                mask: .sceneUnderstanding
            ).first.map { simd_distance(cameraPosition, $0.position) }
            processHideArrival(
                meshDistance: meshDistance,
                pigDistance: simd_distance(cameraPosition, pigPosition)
            )
        }

        private func recoverFromUnverifiedHide() {
            hideAttempt = nil
            revealMonitor = RealityRevealMonitor()
            status = .waitingForTarget
            visualController.outerEntity.isEnabled = false
            onMessage(RealityAvailabilityMessage.scanFirst)
        }

        func stop() {
            revealSubscription?.cancel()
            revealSubscription = nil
            scanningSubscription?.cancel()
            scanningSubscription = nil
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
            arView.session.delegate = self
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            didStartMeshSession = true
            onMessage(RealitySessionDiagnostic.starting.message)
            return true
        }

        private func recordCameraFrame() {
            guard !didReceiveCameraFrame else { return }
            didReceiveCameraFrame = true
            onMessage(RealitySessionDiagnostic.cameraFrameReceived.message)
        }

        private func recordSessionFailure(_ error: Error) {
            onMessage(RealitySessionDiagnostic.failed(error.localizedDescription).message)
        }

        private func reportUnavailable() {
            onUnavailable()
            onMessage(RealityAvailabilityMessage.unavailable)
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  interactionMode == .selectingTarget,
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
            let floorRegion = nearestFloorRegion(in: frame, to: hit.position)
            let surfaceHit = RealitySurfaceHit(point: hit.position, normal: hit.normal)
            let result = RealityHidePlanner.plan(
                hit: surfaceHit,
                cameraPosition: cameraPosition,
                floorRegion: floorRegion
            )

            switch result {
            case let .rejected(rejection):
                onMessage(message(for: rejection))
            case let .accepted(plan):
                _ = processTargetSelection(plan: plan)
            }
        }

        private func reportVisualFailure(recoveringTo recoveryStatus: RealityHideARStatus) {
            status = recoveryStatus
            revealMonitor = RealityRevealMonitor()
            if recoveryStatus == .waitingForTarget {
                hideAttempt = nil
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

        private func nearestFloorRegion(in frame: ARFrame, to surfacePoint: SIMD3<Float>) -> RealityFloorRegion? {
            let planeAnchors = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
            let containingFloors = planeAnchors.compactMap { anchor -> RealityFloorRegion? in
                guard anchor.alignment == .horizontal,
                      anchor.classification == .floor else {
                    return nil
                }

                let region = RealityFloorRegion(
                    anchorIdentifier: anchor.identifier,
                    transform: anchor.transform,
                    center: anchor.center,
                    extent: SIMD2(anchor.planeExtent.width, anchor.planeExtent.height),
                    rotationOnYAxis: anchor.planeExtent.rotationOnYAxis
                )
                return region.containsSurfaceXZ(surfacePoint) ? region : nil
            }

            return containingFloors.min { lhs, rhs in
                let lhsY = lhs.pointOnFloor(projecting: surfacePoint)?.y ?? .infinity
                let rhsY = rhs.pointOnFloor(projecting: surfacePoint)?.y ?? .infinity
                return abs(lhsY - surfacePoint.y) < abs(rhsY - surfacePoint.y)
            }
        }

        private func beginScanningReadiness(in arView: ARView) {
            scanningSubscription?.cancel()
            scanningSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self,
                      let frame = arView?.session.currentFrame else { return }
                let hasMesh = frame.anchors.contains { $0 is ARMeshAnchor }
                let hasFloor = frame.anchors.contains { anchor in
                    guard let plane = anchor as? ARPlaneAnchor else { return false }
                    return plane.alignment == .horizontal && plane.classification == .floor
                }
                self.processScanningObservation(hasMesh: hasMesh, hasFloor: hasFloor)
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
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                processInvalidRevealObservation()
                return
            }
            let screenPoint = arView.project(pigPosition)
            guard RealityProjectionGate.canObserve(
                projectedPoint: screenPoint,
                viewportBounds: arView.bounds,
                pigPosition: pigPosition,
                cameraTransform: cameraTransform
            ), let screenPoint else {
                processInvalidRevealObservation()
                return
            }

            let cameraPosition = Self.position(from: cameraTransform)
            let cameraForward = -SIMD3(
                cameraTransform.columns.2.x,
                cameraTransform.columns.2.y,
                cameraTransform.columns.2.z
            )
            let meshDistance = arView.hitTest(
                screenPoint,
                query: .nearest,
                mask: .sceneUnderstanding
            ).first.map { simd_distance(cameraPosition, $0.position) }
            let pigDistance = simd_distance(cameraPosition, pigPosition)
            processRevealFrame(
                isObservationValid: true,
                meshDistance: meshDistance,
                pigDistance: pigDistance,
                cameraPose: RealityCameraPose(
                    position: cameraPosition,
                    forward: cameraForward
                )
            )
        }

        private func processInvalidRevealObservation() {
            guard status == .hidden else { return }
            revealMonitor.recordInvalidObservation()
        }

        private static func position(from transform: simd_float4x4) -> SIMD3<Float> {
            SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
    }
}

extension RealityHideARView.Coordinator: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor [weak self] in
            self?.recordCameraFrame()
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.recordSessionFailure(error)
        }
    }
}
