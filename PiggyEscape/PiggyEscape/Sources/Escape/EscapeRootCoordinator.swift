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
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
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
    static let cameraRestricted = "이 기기에서는 카메라 사용이 제한되어 있어."
    static let scanning = "주변을 천천히 비춰 공간 형태와 바닥을 읽어줘."
    static let realityReady = "공간 준비가 끝났어. 이제 숨바꼭질을 시작해봐."
    static let walkingToRealObject = "피기가 숨으러 가고 있어."
    static let verifyingOcclusion = "실제 물체 뒤에 잘 숨었는지 확인하고 있어."
    static let findPig = "옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐."
    static let selectAnotherTarget = "충분히 가려지지 않았어. 다른 물체의 옆면을 골라줘."
    static let scanTimedOut = "공간 형태와 바닥을 함께 읽지 못했어. 다시 스캔해봐."
    static let sessionFailed = "AR 세션을 이어갈 수 없어. 다시 스캔하거나 차이를 먼저 볼 수 있어."
    static let sessionInterrupted = "카메라 추적이 잠시 멈췄어. 기기를 안정적으로 들어줘."
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
    @Published private(set) var scanProgress = RealityScanProgress.empty
    @Published private(set) var scanCompletionSequence = 0
    @Published private(set) var isSessionInterrupted = false
    @Published private(set) var hideCycleResetSequence = 0

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
        machine.state.chapter == .closedWorld
    }

    var showsSettingsRecovery: Bool {
        machine.state == .cameraDenied
    }

    var realitySurfaceID: Int {
        lifetime.currentToken.realityGeneration
    }

    var realityInteractionMode: RealityHideInteractionMode {
        guard !isSessionInterrupted else { return .preparing }
        switch machine.state {
        case .waitingForRealTarget:
            return .selectingTarget
        case .walkingBehindRealObject, .verifyingOcclusion:
            return .moving
        case .hiddenInReality:
            return .searching
        case .discoveredInReality:
            return .revealed
        default:
            return .preparing
        }
    }

    var showsSceneUnderstanding: Bool {
        machine.state == .scanningReality || machine.state == .realityReady
    }

    var comparisonReason: ComparisonEntryReason? {
        switch machine.state {
        case .comparison(let reason), .completed(let reason):
            reason
        default:
            nil
        }
    }

    var chapterThreeRetryAvailability: ChapterThreeRetryAvailability {
        guard let comparisonReason else {
            return .unavailable(reason: "Chapter 4에서 다시 시도할 수 있어.")
        }
        switch comparisonReason {
        case .cameraDenied:
            return .unavailable(reason: "설정에서 카메라 권한을 허용한 뒤 다시 시도해줘.")
        case .cameraRestricted:
            return .unavailable(reason: "카메라 제한이 없는 기기에서 다시 시도할 수 있어.")
        case .lidarUnavailable:
            return .unavailable(reason: "LiDAR 지원 기기에서 다시 시도할 수 있어.")
        case .completedHide, .sessionFailed, .scanTimedOut, .assetFailed:
            return .available
        }
    }

    private let cameraAuthorizer: any CameraAuthorizing
    private let settingsOpener: any AppSettingsOpening
    private let deadlineScheduler: any RealityDeadlineScheduling
    private var hasRequestedCamera = false
    private var lifetime = EscapeExperienceLifetime()
    private var scanDeadline: (any RealityDeadlineCancellable)?
    private var interruptionDeadline: (any RealityDeadlineCancellable)?

    init() {
        cameraAuthorizer = SystemCameraAuthorizer()
        settingsOpener = SystemAppSettingsOpener()
        deadlineScheduler = RealityDeadlineScheduler()
    }

    init(
        cameraAuthorizer: any CameraAuthorizing,
        settingsOpener: any AppSettingsOpening,
        deadlineScheduler: (any RealityDeadlineScheduling)? = nil
    ) {
        self.cameraAuthorizer = cameraAuthorizer
        self.settingsOpener = settingsOpener
        self.deadlineScheduler = deadlineScheduler ?? RealityDeadlineScheduler()
    }

    func scanPresentation(reduceMotion: Bool) -> RealityScanPresentation {
        RealityScanPresentation(
            showsSceneUnderstanding: showsSceneUnderstanding,
            reduceMotion: reduceMotion
        )
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

    func realityScanDidUpdate(_ update: RealityScanUpdate) {
        guard machine.state == .scanningReality || machine.state == .realityReady else { return }
        scanProgress = update.progress
        if update.becameReady {
            scanCompletionSequence += 1
        }
    }

    func realityScanningDidBecomeReady() {
        guard machine.send(.environmentReady) else { return }
        scanDeadline?.cancel()
        scanDeadline = nil
        message = EscapeRootMessage.realityReady
    }

    func startRealHide() {
        guard !isSessionInterrupted,
              machine.send(.startRealHide) else { return }
        message = RealityAvailabilityMessage.selectVerticalSide
    }

    func realityMeshDidBecomeUnavailable() {
        guard machine.send(.meshUnsupported) else { return }
        cancelRealityDeadlines()
        message = RealityAvailabilityMessage.unavailable
    }

    func realityTargetDidBecomeAccepted() {
        guard machine.send(.realTargetAccepted) else { return }
        lifetime.beginNewHideCycle()
        message = EscapeRootMessage.walkingToRealObject
    }

    func realityMovementDidFinish() {
        guard machine.send(.movementFinished) else { return }
        message = EscapeRootMessage.verifyingOcclusion
    }

    func realityOcclusionRetryDidStart() {
        guard machine.send(.occlusionRetryStarted) else { return }
        message = EscapeRootMessage.walkingToRealObject
    }

    func realityOcclusionDidBecomeVerified() {
        guard machine.send(.occlusionVerified) else { return }
        message = EscapeRootMessage.findPig
    }

    func realityOcclusionDidExhaust() {
        guard machine.send(.occlusionExhausted) else { return }
        message = EscapeRootMessage.selectAnotherTarget
    }

    func realityPigDidBecomeRevealed() {
        guard machine.send(.realityPigDiscovered) else { return }
        message = EscapeRootMessage.surprised
        realitySurpriseSequence += 1
    }

    func realityErrorDidOccur() {
        realityErrorCount += 1
        guard machine.send(.realityAssetLoadFailed) else { return }
        message = RealityAvailabilityMessage.pigAssetLoadFailed
    }

    func realityMessageDidChange(_ message: String) {
        self.message = message
    }

    func realitySessionDidFail() {
        guard machine.send(.sessionDidFail) else { return }
        cancelRealityDeadlines()
        message = EscapeRootMessage.sessionFailed
    }

    func realitySessionWasInterrupted() {
        isSessionInterrupted = true
        _ = machine.send(.sessionInterrupted)
        message = EscapeRootMessage.sessionInterrupted
        if machine.state == .scanningReality {
            scanDeadline?.cancel()
            scanDeadline = nil
        }
        interruptionDeadline?.cancel()
        interruptionDeadline = deadlineScheduler.schedule(
            .interruption,
            owner: self
        ) { owner in
            owner.interruptionDeadlineDidElapse()
        }
    }

    func realitySessionInterruptionEnded() {
        guard isSessionInterrupted else { return }
        isSessionInterrupted = false
        interruptionDeadline?.cancel()
        interruptionDeadline = nil
        switch machine.state {
        case .scanningReality:
            scheduleScanDeadline()
            message = EscapeRootMessage.scanning
        case .realityReady:
            message = EscapeRootMessage.realityReady
        case .waitingForRealTarget:
            message = RealityAvailabilityMessage.selectVerticalSide
        default:
            break
        }
    }

    func replayRealHide() {
        guard machine.send(.replayRealHide) else { return }
        lifetime.beginNewHideCycle()
        hideCycleResetSequence &+= 1
        message = RealityAvailabilityMessage.selectVerticalSide
    }

    func retryReality() {
        guard machine.send(.retryReality) else { return }
        if machine.state == .scanningReality {
            beginNewRealitySession()
        } else {
            lifetime.beginNewHideCycle()
            hideCycleResetSequence &+= 1
            message = RealityAvailabilityMessage.selectVerticalSide
        }
    }

    func skipToComparison() {
        guard machine.send(.skipToComparison) else { return }
        cancelRealityDeadlines()
        message = nil
    }

    func reviewDifferences() {
        guard machine.send(.reviewDifferences) else { return }
        cancelRealityDeadlines()
        message = nil
    }

    func finishTutorial() {
        guard machine.send(.finishTutorial) else { return }
        message = nil
    }

    func retryChapterThree() {
        guard chapterThreeRetryAvailability.isAvailable,
              machine.send(.retryChapter3) else { return }
        beginNewRealitySession()
    }

    func resetExperience() {
        guard machine.send(.reset) else { return }
        cancelRealityDeadlines()
        lifetime.resetExperience()
        hasRequestedCamera = false
        isClosedWorldFading = false
        cameraAuthorizationResult = nil
        realitySurpriseSequence = 0
        realityErrorCount = 0
        scanProgress = .empty
        scanCompletionSequence = 0
        hideCycleResetSequence = 0
        message = nil
    }

    func openSettingsForRecovery() {
        guard machine.send(.openSettings) else { return }
        settingsOpener.openAppSettings()
    }

    func applicationDidBecomeActive() {
        guard machine.state == .cameraDenied,
              machine.isCameraAuthorizationRecheckArmed else { return }
        resolveSettingsAuthorization(cameraAuthorizer.currentVideoAuthorization())
    }

    private func beginNewRealitySession() {
        lifetime.beginNewRealitySession()
        scanProgress = .empty
        isSessionInterrupted = false
        interruptionDeadline?.cancel()
        interruptionDeadline = nil
        scheduleScanDeadline()
        message = EscapeRootMessage.scanning
    }

    private func scheduleScanDeadline() {
        scanDeadline?.cancel()
        scanDeadline = deadlineScheduler.schedule(.scan, owner: self) { owner in
            owner.scanDeadlineDidElapse()
        }
    }

    private func scanDeadlineDidElapse() {
        guard machine.send(.scanDeadlineElapsed) else { return }
        scanDeadline = nil
        message = EscapeRootMessage.scanTimedOut
    }

    private func interruptionDeadlineDidElapse() {
        guard isSessionInterrupted else { return }
        isSessionInterrupted = false
        interruptionDeadline = nil
        guard machine.send(.sessionDidFail) else { return }
        message = EscapeRootMessage.sessionFailed
    }

    private func cancelRealityDeadlines() {
        scanDeadline?.cancel()
        scanDeadline = nil
        interruptionDeadline?.cancel()
        interruptionDeadline = nil
        isSessionInterrupted = false
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
            beginNewRealitySession()
        case .denied:
            guard machine.send(.cameraAuthorizationDenied) else { return }
            message = EscapeRootMessage.cameraDenied
        case .restricted:
            guard machine.send(.cameraAuthorizationRestricted) else { return }
            message = EscapeRootMessage.cameraRestricted
        case .notDetermined:
            break
        }
    }

    private func resolveSettingsAuthorization(_ result: CameraAuthorizationResult) {
        cameraAuthorizationResult = result
        switch result {
        case .authorized:
            guard machine.send(.cameraAuthorized) else { return }
            beginNewRealitySession()
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
}
