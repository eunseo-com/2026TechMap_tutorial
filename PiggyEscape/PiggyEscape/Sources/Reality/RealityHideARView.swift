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
    case verifyingOcclusion
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
    let onMovementFinished: () -> Void
    let onOcclusionRetryStarted: () -> Void
    let onOcclusionExhausted: () -> Void
    let onPigReachedTarget: () -> Void
    let onRevealed: () -> Void
    let onError: () -> Void
    let onUnavailable: () -> Void
    let onMessage: (String) -> Void

    init(
        interactionMode: RealityHideInteractionMode = .preparing,
        onScanningReady: @escaping () -> Void,
        onTargetAccepted: @escaping () -> Void,
        onMovementFinished: @escaping () -> Void = {},
        onOcclusionRetryStarted: @escaping () -> Void = {},
        onOcclusionExhausted: @escaping () -> Void = {},
        onPigReachedTarget: @escaping () -> Void,
        onRevealed: @escaping () -> Void,
        onError: @escaping () -> Void,
        onUnavailable: @escaping () -> Void,
        onMessage: @escaping (String) -> Void
    ) {
        self.interactionMode = interactionMode
        self.onScanningReady = onScanningReady
        self.onTargetAccepted = onTargetAccepted
        self.onMovementFinished = onMovementFinished
        self.onOcclusionRetryStarted = onOcclusionRetryStarted
        self.onOcclusionExhausted = onOcclusionExhausted
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
            onMovementFinished: onMovementFinished,
            onOcclusionRetryStarted: onOcclusionRetryStarted,
            onOcclusionExhausted: onOcclusionExhausted,
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
        @MainActor
        private final class HideCycle {
            let generation: Int
            let anchor: AnchorEntity
            let visualController: RealityPigVisualController
            var attachmentGate = RealityPigSceneAttachmentGate()
            var attempt: RealityHideAttempt
            var hideMonitor: StableHideMonitor?
            var revealMonitor: RealityRevealMonitor?
            var revealReferencePose: RealityCameraPose?
            var observationSubscription: (any Cancellable)?
            var deadline: (any RealityDeadlineCancellable)?

            init(
                generation: Int,
                plan: RealityHidePlan,
                visualController: RealityPigVisualController
            ) {
                self.generation = generation
                self.attempt = RealityHideAttempt(plan: plan)
                self.visualController = visualController
                anchor = AnchorEntity(world: .zero)
                anchor.addChild(visualController.outerEntity)
            }
        }

        private let meshSupport: any RealityMeshSupporting
        private let observationProvider: any RealityOcclusionObservationProviding
        private let deadlineScheduler: any RealityDeadlineScheduling
        private let monotonicNow: @MainActor () -> TimeInterval
        private let visualControllerFactory: @MainActor () -> RealityPigVisualController
        private var seededVisualController: RealityPigVisualController?
        private let onScanningReady: () -> Void
        private let onTargetAccepted: () -> Void
        private let onMovementFinished: () -> Void
        private let onOcclusionRetryStarted: () -> Void
        private let onOcclusionExhausted: () -> Void
        private let onPigReachedTarget: () -> Void
        private let onRevealed: () -> Void
        private let onError: () -> Void
        private let onUnavailable: () -> Void
        private let onMessage: (String) -> Void

        private weak var arView: ARView?
        private var environmentReadiness = RealityEnvironmentReadiness()
        private var scanningSubscription: (any Cancellable)?
        private var cycle: HideCycle?
        private weak var tapRecognizer: UITapGestureRecognizer?
        private var hasAttachedToARView = false
        private var didReceiveCameraFrame = false

        private(set) var didStartMeshSession = false
        private(set) var status = RealityHideARStatus.waitingForTarget
        private(set) var cycleGeneration = 0
        private(set) var cycleCreationCount = 0
        var interactionMode: RealityHideInteractionMode

        var hasActiveHideCycle: Bool { cycle != nil }
        var currentPigAnchorIdentifier: ObjectIdentifier? {
            cycle.map { ObjectIdentifier($0.anchor) }
        }
        var currentHideAttempt: RealityHideAttempt? { cycle?.attempt }

        var canStartMeshSession: Bool {
            meshSupport.supportsMeshWithClassification
        }

        init(
            meshSupport: any RealityMeshSupporting,
            visualController: RealityPigVisualController? = nil,
            visualControllerFactory: (@MainActor () -> RealityPigVisualController)? = nil,
            observationProvider: (any RealityOcclusionObservationProviding)? = nil,
            deadlineScheduler: (any RealityDeadlineScheduling)? = nil,
            monotonicNow: (@MainActor () -> TimeInterval)? = nil,
            interactionMode: RealityHideInteractionMode = .preparing,
            onScanningReady: @escaping () -> Void = {},
            onTargetAccepted: @escaping () -> Void = {},
            onMovementFinished: @escaping () -> Void = {},
            onOcclusionRetryStarted: @escaping () -> Void = {},
            onOcclusionExhausted: @escaping () -> Void = {},
            onPigReachedTarget: @escaping () -> Void = {},
            onRevealed: @escaping () -> Void = {},
            onError: @escaping () -> Void = {},
            onUnavailable: @escaping () -> Void = {},
            onMessage: @escaping (String) -> Void = { _ in }
        ) {
            self.meshSupport = meshSupport
            self.seededVisualController = visualController
            self.visualControllerFactory = visualControllerFactory ?? { RealityPigVisualController() }
            self.observationProvider = observationProvider ?? RealityOcclusionObservationProvider()
            self.deadlineScheduler = deadlineScheduler ?? RealityDeadlineScheduler()
            self.monotonicNow = monotonicNow ?? { ProcessInfo.processInfo.systemUptime }
            self.interactionMode = interactionMode
            self.onScanningReady = onScanningReady
            self.onTargetAccepted = onTargetAccepted
            self.onMovementFinished = onMovementFinished
            self.onOcclusionRetryStarted = onOcclusionRetryStarted
            self.onOcclusionExhausted = onOcclusionExhausted
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

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTouchesRequired = 1
            arView.addGestureRecognizer(tap)
            tapRecognizer = tap
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
        func processRevealObservation(_ observation: RealityOcclusionObservation) -> Bool {
            guard status == .hidden,
                  let cycle,
                  var revealMonitor = cycle.revealMonitor else {
                return false
            }

            let didReveal = revealMonitor.update(observation)
            cycle.revealMonitor = revealMonitor
            guard didReveal else { return false }

            status = .revealing
            cycle.observationSubscription?.cancel()
            cycle.observationSubscription = nil
            let generation = cycle.generation
            cycle.visualController.showSurprised { [weak self] result in
                guard let self,
                      self.isCurrentCycle(generation),
                      self.status == .revealing,
                      let cycle = self.cycle else { return }
                switch result {
                case .success:
                    cycle.visualController.playSurpriseScale()
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
            let cycle = makeCycle(plan: plan)
            self.cycle = cycle
            if let arView,
               cycle.attachmentGate.consumeIfReady(hasAcceptedTarget: true) {
                arView.scene.addAnchor(cycle.anchor)
            }
            status = .walking
            cycle.visualController.outerEntity.setPosition(plan.start, relativeTo: nil)
            cycle.visualController.outerEntity.isEnabled = true
            onTargetAccepted()
            walkPiggy(to: plan.destination, generation: cycle.generation)
            return true
        }

        @discardableResult
        func processHideObservation(
            _ observation: RealityOcclusionObservation,
            now: TimeInterval
        ) -> StableHideMonitorUpdate {
            guard status == .verifyingOcclusion,
                  let cycle,
                  var monitor = cycle.hideMonitor else {
                return .waiting
            }

            let update = monitor.update(observation, now: now)
            cycle.hideMonitor = monitor
            switch update {
            case .waiting:
                break
            case let .hidden(referencePose):
                completeStableHide(referencePose: referencePose, generation: cycle.generation)
            case .exhausted:
                handleHideExhaustion(generation: cycle.generation)
            }
            return update
        }

        @discardableResult
        func processOcclusionDeadline(now: TimeInterval) -> Bool {
            guard status == .verifyingOcclusion,
                  let cycle,
                  var monitor = cycle.hideMonitor else { return false }
            let update = monitor.deadlineElapsed(at: now)
            cycle.hideMonitor = monitor
            guard update == .exhausted else { return false }
            handleHideExhaustion(generation: cycle.generation)
            return true
        }

        func restartHideCycle() {
            teardownCurrentCycle()
            status = .waitingForTarget
        }

        private func makeCycle(plan: RealityHidePlan) -> HideCycle {
            cycleGeneration += 1
            cycleCreationCount += 1
            let visualController: RealityPigVisualController
            if let seededVisualController {
                visualController = seededVisualController
                self.seededVisualController = nil
            } else {
                visualController = visualControllerFactory()
            }
            return HideCycle(
                generation: cycleGeneration,
                plan: plan,
                visualController: visualController
            )
        }

        private func walkPiggy(to destination: SIMD3<Float>, generation: Int) {
            guard isCurrentCycle(generation), let cycle else { return }
            cycle.visualController.walk(to: destination) { [weak self] result in
                guard let self, self.isCurrentCycle(generation) else { return }
                switch result {
                case .success:
                    self.onMovementFinished()
                    self.beginHideVerification(generation: generation)
                case .failure:
                    self.reportVisualFailure(recoveringTo: .waitingForTarget)
                }
            }
        }

        private func beginHideVerification(generation: Int) {
            guard status == .walking,
                  isCurrentCycle(generation),
                  let cycle else { return }
            status = .verifyingOcclusion
            let startTime = monotonicNow()
            cycle.hideMonitor = StableHideMonitor(startTime: startTime)
            cycle.deadline?.cancel()
            cycle.deadline = deadlineScheduler.schedule(
                .occlusionObservation,
                owner: self
            ) { owner in
                guard owner.isCurrentCycle(generation) else { return }
                _ = owner.processOcclusionDeadline(now: owner.monotonicNow())
            }
            if let arView {
                beginOcclusionMonitoring(in: arView, generation: generation, phase: .hide)
            }
        }

        private func completeStableHide(
            referencePose: RealityCameraPose,
            generation: Int
        ) {
            guard isCurrentCycle(generation), let cycle else { return }
            cycle.deadline?.cancel()
            cycle.deadline = nil
            cycle.observationSubscription?.cancel()
            cycle.observationSubscription = nil
            cycle.hideMonitor = nil
            cycle.revealReferencePose = referencePose
            cycle.revealMonitor = RealityRevealMonitor(referencePose: referencePose)
            status = .hidden
            onPigReachedTarget()
            if let arView {
                beginOcclusionMonitoring(in: arView, generation: generation, phase: .reveal)
            }
        }

        private func handleHideExhaustion(generation: Int) {
            guard isCurrentCycle(generation), let cycle else { return }
            cycle.deadline?.cancel()
            cycle.deadline = nil
            cycle.observationSubscription?.cancel()
            cycle.observationSubscription = nil
            cycle.hideMonitor = nil

            guard let nextAttempt = RealityHideVerificationPolicy.nextAttempt(after: cycle.attempt) else {
                onOcclusionExhausted()
                recoverFromUnverifiedHide()
                return
            }
            cycle.attempt = nextAttempt
            status = .walking
            onOcclusionRetryStarted()
            walkPiggy(to: nextAttempt.destination, generation: generation)
        }

        private func recoverFromUnverifiedHide() {
            teardownCurrentCycle()
            status = .waitingForTarget
            onMessage(RealityAvailabilityMessage.scanFirst)
        }

        private func teardownCurrentCycle() {
            cycleGeneration += 1
            guard let cycle else { return }
            cycle.deadline?.cancel()
            cycle.deadline = nil
            cycle.observationSubscription?.cancel()
            cycle.observationSubscription = nil
            cycle.visualController.cancelPendingWork()
            cycle.visualController.outerEntity.isEnabled = false
            cycle.anchor.removeFromParent()
            self.cycle = nil
        }

        private func isCurrentCycle(_ generation: Int) -> Bool {
            cycleGeneration == generation && cycle?.generation == generation
        }

        func stop() {
            scanningSubscription?.cancel()
            scanningSubscription = nil
            if let tapRecognizer {
                arView?.removeGestureRecognizer(tapRecognizer)
            }
            teardownCurrentCycle()
            arView?.session.delegate = nil
            arView?.session.pause()
            arView = nil
            didStartMeshSession = false
            hasAttachedToARView = false
        }

        private enum OcclusionMonitoringPhase {
            case hide
            case reveal
        }

        private func beginOcclusionMonitoring(
            in arView: ARView,
            generation: Int,
            phase: OcclusionMonitoringPhase
        ) {
            guard isCurrentCycle(generation), let cycle else { return }
            cycle.observationSubscription?.cancel()
            cycle.observationSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self,
                      let arView,
                      self.isCurrentCycle(generation),
                      let cycle = self.cycle,
                      let observation = self.observationProvider.makeObservation(
                        in: arView,
                        pigEntity: cycle.visualController.outerEntity
                      ) else { return }
                switch phase {
                case .hide:
                    _ = self.processHideObservation(observation, now: self.monotonicNow())
                case .reveal:
                    _ = self.processRevealObservation(observation)
                }
            }
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
            if recoveryStatus == .waitingForTarget {
                teardownCurrentCycle()
                status = .waitingForTarget
            } else if recoveryStatus == .hidden,
                      let cycle,
                      let referencePose = cycle.revealReferencePose {
                status = .hidden
                cycle.visualController.outerEntity.isEnabled = true
                cycle.revealMonitor = RealityRevealMonitor(referencePose: referencePose)
                if let arView {
                    beginOcclusionMonitoring(
                        in: arView,
                        generation: cycle.generation,
                        phase: .reveal
                    )
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
