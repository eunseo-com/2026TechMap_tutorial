import AVFoundation
import SwiftUI
import UIKit

enum CameraAuthorizationResult: Equatable {
    case authorized
    case denied
    case restricted
    case notDetermined
}

@MainActor
protocol CameraAuthorizing {
    func currentVideoAuthorization() -> CameraAuthorizationResult
    func requestVideoAccess(
        _ completion: @escaping @MainActor (CameraAuthorizationResult) -> Void
    )
}

struct SystemCameraAuthorizer: CameraAuthorizing {
    func currentVideoAuthorization() -> CameraAuthorizationResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .restricted
        }
    }

    func requestVideoAccess(
        _ completion: @escaping @MainActor (CameraAuthorizationResult) -> Void
    ) {
        let authorization = currentVideoAuthorization()
        switch authorization {
        case .authorized, .denied, .restricted:
            completion(authorization)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                let result: CameraAuthorizationResult
                if granted {
                    result = .authorized
                } else if AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                    result = .restricted
                } else {
                    result = .denied
                }
                Task { @MainActor in completion(result) }
            }
        }
    }
}

@MainActor
protocol MainActorCallbackDeferring {
    @discardableResult
    func enqueue(_ operation: @escaping @MainActor () -> Void) -> Task<Void, Never>
}

struct TaskMainActorCallbackDeferrer: MainActorCallbackDeferring {
    @discardableResult
    func enqueue(_ operation: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            operation()
        }
    }
}

@MainActor
final class RealityCallbackRelay: ObservableObject {
    private let deferrer: any MainActorCallbackDeferring
    private var generation = 0
    private var isActive = true
    private var pendingTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        deferrer = TaskMainActorCallbackDeferrer()
    }

    init(deferrer: any MainActorCallbackDeferring) {
        self.deferrer = deferrer
    }

    func activate() {
        guard !isActive else { return }
        generation &+= 1
        isActive = true
    }

    func invalidate() {
        generation &+= 1
        isActive = false
        pendingTasks.values.forEach { $0.cancel() }
        pendingTasks.removeAll()
    }

    func schedule(_ operation: @escaping @MainActor () -> Void) {
        guard isActive else { return }
        let callbackGeneration = generation
        let identifier = UUID()
        let task = deferrer.enqueue { [weak self] in
            guard let self else { return }
            self.pendingTasks[identifier] = nil
            guard self.isActive, self.generation == callbackGeneration else { return }
            operation()
        }
        pendingTasks[identifier] = task
    }
}

@MainActor
protocol AppSettingsOpening {
    func openAppSettings()
}

struct SystemAppSettingsOpener: AppSettingsOpening {
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

enum EscapeRootMessage {
    static let surprised = "아, 들켰네… 제대로 숨고 싶은데."
    static let cameraDenied = "카메라 권한이 필요해. 설정에서 카메라를 허용해줘."
    static let cameraRestricted = "이 기기에서는 카메라 사용이 제한되어 있어. 설정을 확인해줘."
    static let walkingToRealObject = "피기가 숨으러 가고 있어."
    static let findPig = "직접 움직여서 피기를 찾아봐."
}

enum EscapeRootMotion {
    static let closedWorldFadeDuration: TimeInterval = 0.70
    static let surpriseGrowDuration: TimeInterval = 0.16
    static let surpriseRestoreDuration: TimeInterval = 0.34
    static func realityPeakScale(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : 1.12
    }
}

@MainActor
final class EscapeRootCoordinator: ObservableObject {
    @Published private(set) var machine = EscapeExperienceMachine()
    @Published private(set) var message: String?
    @Published private(set) var isClosedWorldFading = false
    @Published private(set) var cameraAuthorizationResult: CameraAuthorizationResult?
    @Published private(set) var realitySurpriseSequence = 0
    @Published private(set) var realityErrorCount = 0

    var showsRealityView: Bool {
        switch machine.state {
        case .scanningReality, .realityReady, .waitingForRealTarget,
             .walkingBehindRealObject, .verifyingOcclusion, .hiddenInReality,
             .discoveredInReality, .realityAssetFailed:
            true
        default:
            false
        }
    }

    var showsClosedWorldView: Bool {
        !showsRealityView
    }

    var showsSettingsRecovery: Bool {
        machine.state == .cameraDenied
    }

    private let cameraAuthorizer: any CameraAuthorizing
    private let settingsOpener: any AppSettingsOpening
    private var hasRequestedCamera = false

    init() {
        cameraAuthorizer = SystemCameraAuthorizer()
        settingsOpener = SystemAppSettingsOpener()
    }

    init(
        cameraAuthorizer: any CameraAuthorizing,
        settingsOpener: any AppSettingsOpening
    ) {
        self.cameraAuthorizer = cameraAuthorizer
        self.settingsOpener = settingsOpener
    }

    func closedWorldNarrationDidFinish() {
        _ = machine.send(.narrationFinished)
    }

    @discardableResult
    func closedWorldDiscoveryDidOccur() -> Bool {
        synchronizeClosedWorldProgress()
        guard machine.send(.closedWorldPigDiscovered) else { return false }
        message = EscapeRootMessage.surprised
        isClosedWorldFading = true
        return true
    }

    func closedWorldFadeDidFinish() {
        guard !hasRequestedCamera,
              machine.send(.closedWorldFadeFinished) else { return }
        hasRequestedCamera = true
        cameraAuthorizer.requestVideoAccess { [weak self] result in
            self?.cameraAuthorizationDidResolve(result)
        }
    }

    func realityScanningDidBecomeReady() {
        guard machine.send(.environmentReady),
              machine.send(.startRealHide) else { return }
        message = RealityAvailabilityMessage.selectVerticalSide
    }

    func realityMeshDidBecomeUnavailable() {
        guard machine.send(.meshUnsupported) else { return }
        message = RealityAvailabilityMessage.unavailable
    }

    func realityTargetDidBecomeAccepted() {
        guard machine.send(.realTargetAccepted) else { return }
        message = EscapeRootMessage.walkingToRealObject
    }

    func realityPigDidReachTarget() {
        guard machine.send(.movementFinished),
              machine.send(.occlusionVerified) else { return }
        message = EscapeRootMessage.findPig
    }

    func realityPigDidBecomeRevealed() {
        guard machine.send(.realityPigDiscovered) else { return }
        message = EscapeRootMessage.surprised
        realitySurpriseSequence += 1
    }

    func realityErrorDidOccur() {
        realityErrorCount += 1
    }

    func realityMessageDidChange(_ message: String) {
        if message == RealityAvailabilityMessage.pigAssetLoadFailed {
            _ = machine.send(.realityAssetLoadFailed)
        }
        self.message = message
    }

    func openSettingsForRecovery() {
        guard machine.send(.openSettings) else { return }
        settingsOpener.openAppSettings()
    }

    func applicationDidBecomeActive() {
        guard machine.state == .cameraDenied,
              machine.isCameraAuthorizationRecheckArmed else { return }
        let result = cameraAuthorizer.currentVideoAuthorization()
        cameraAuthorizationResult = result
        switch result {
        case .authorized:
            guard machine.send(.cameraAuthorized) else { return }
            message = RealityAvailabilityMessage.scanFirst
        case .denied:
            guard machine.send(.cameraAuthorizationDenied) else { return }
            message = EscapeRootMessage.cameraDenied
        case .restricted:
            guard machine.send(.cameraAuthorizationRestricted) else { return }
            message = EscapeRootMessage.cameraRestricted
        case .notDetermined:
            message = EscapeRootMessage.cameraDenied
        }
    }

    private func synchronizeClosedWorldProgress() {
        if machine.state == .openingNarration {
            _ = machine.send(.narrationFinished)
        }
        if machine.state == .readyForPigTap {
            _ = machine.send(.pigTapped)
        }
        if machine.state == .walkingBehindTree {
            _ = machine.send(.pigReachedTree)
        }
    }

    private func cameraAuthorizationDidResolve(_ result: CameraAuthorizationResult) {
        guard machine.state == .requestingCameraPermission else { return }
        cameraAuthorizationResult = result
        switch result {
        case .authorized:
            guard machine.send(.cameraAuthorized) else { return }
            message = RealityAvailabilityMessage.scanFirst
        case .denied:
            guard machine.send(.cameraAuthorizationDenied) else { return }
            message = EscapeRootMessage.cameraDenied
        case .restricted:
            guard machine.send(.cameraAuthorizationRestricted) else { return }
            message = EscapeRootMessage.cameraRestricted
        case .notDetermined:
            return
        }
    }
}

struct EscapeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: EscapeRootCoordinator
    @StateObject private var realityCallbacks: RealityCallbackRelay
    @State private var fadeTask: Task<Void, Never>?
    @State private var realityScaleTask: Task<Void, Never>?
    @State private var realityScreenScale: CGFloat = 1

    @MainActor
    init() {
        _coordinator = StateObject(wrappedValue: EscapeRootCoordinator())
        _realityCallbacks = StateObject(wrappedValue: RealityCallbackRelay())
    }

    @MainActor
    init(
        cameraAuthorizer: any CameraAuthorizing,
        settingsOpener: any AppSettingsOpening
    ) {
        _coordinator = StateObject(wrappedValue: EscapeRootCoordinator(
            cameraAuthorizer: cameraAuthorizer,
            settingsOpener: settingsOpener
        ))
        _realityCallbacks = StateObject(wrappedValue: RealityCallbackRelay())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.64, green: 0.93, blue: 0.99),
                    Color(red: 0.41, green: 0.80, blue: 0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if coordinator.showsClosedWorldView {
                C3ClosedWorldSceneView(
                    onNarrationFinished: coordinator.closedWorldNarrationDidFinish,
                    onDiscovered: beginClosedWorldFade
                )
                .opacity(coordinator.isClosedWorldFading ? 0 : 1)
                .allowsHitTesting(!coordinator.isClosedWorldFading)
                .animation(
                    .easeInOut(duration: EscapeRootMotion.closedWorldFadeDuration),
                    value: coordinator.isClosedWorldFading
                )
            }

            if coordinator.showsRealityView {
                RealityHideARView(
                    onScanningReady: {
                        scheduleRealityCallback { $0.realityScanningDidBecomeReady() }
                    },
                    onTargetAccepted: {
                        scheduleRealityCallback { $0.realityTargetDidBecomeAccepted() }
                    },
                    onPigReachedTarget: {
                        scheduleRealityCallback { $0.realityPigDidReachTarget() }
                    },
                    onRevealed: {
                        scheduleRealityCallback { $0.realityPigDidBecomeRevealed() }
                    },
                    onError: {
                        scheduleRealityCallback { $0.realityErrorDidOccur() }
                    },
                    onUnavailable: {
                        scheduleRealityCallback { $0.realityMeshDidBecomeUnavailable() }
                    },
                    onMessage: { message in
                        scheduleRealityCallback { $0.realityMessageDidChange(message) }
                    }
                )
                .scaleEffect(realityScreenScale)
                .clipped()
                .transition(.opacity)
            }

            messageOverlay
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.showsRealityView)
        .onChange(of: coordinator.realitySurpriseSequence) { _, sequence in
            guard sequence > 0 else { return }
            performRealitySurprise()
        }
        .onChange(of: coordinator.showsRealityView) { _, showsRealityView in
            if showsRealityView {
                realityCallbacks.activate()
            } else {
                realityCallbacks.invalidate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.applicationDidBecomeActive()
        }
        .onAppear {
            realityCallbacks.activate()
        }
        .onDisappear {
            fadeTask?.cancel()
            realityScaleTask?.cancel()
            realityCallbacks.invalidate()
        }
    }

    @ViewBuilder
    private var messageOverlay: some View {
        if let message = coordinator.message,
           coordinator.machine.state != .discoveredByCamera,
           coordinator.machine.state != .requestingCameraPermission {
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text(message)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)

                    if coordinator.showsSettingsRecovery {
                        Button("설정 열기", action: coordinator.openSettingsForRecovery)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 44)
                            .background(Color.yellow, in: Capsule())
                            .accessibilityHint("앱의 카메라 권한 설정을 엽니다")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 520)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.black.opacity(0.34))
                        }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
            .transition(
                accessibilityReduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.96))
            )
        }
    }

    private func beginClosedWorldFade() {
        guard coordinator.closedWorldDiscoveryDidOccur() else { return }
        fadeTask?.cancel()
        fadeTask = Task { @MainActor [weak coordinator] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            coordinator?.closedWorldFadeDidFinish()
        }
    }

    private func performRealitySurprise() {
        realityScaleTask?.cancel()
        realityScreenScale = 1
        let peakScale = EscapeRootMotion.realityPeakScale(
            reduceMotion: accessibilityReduceMotion
        )
        guard peakScale > 1 else { return }
        realityScaleTask = Task { @MainActor in
            withAnimation(.easeOut(duration: EscapeRootMotion.surpriseGrowDuration)) {
                realityScreenScale = peakScale
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: EscapeRootMotion.surpriseRestoreDuration)) {
                realityScreenScale = 1
            }
        }
    }

    private func scheduleRealityCallback(
        _ operation: @escaping @MainActor (EscapeRootCoordinator) -> Void
    ) {
        realityCallbacks.schedule { [weak coordinator] in
            guard let coordinator else { return }
            operation(coordinator)
        }
    }
}
