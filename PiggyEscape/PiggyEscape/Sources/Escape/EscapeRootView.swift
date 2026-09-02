import SwiftUI
import UIKit

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
            background

            if coordinator.showsClosedWorldView {
                C3ClosedWorldSceneView(
                    reduceMotionEnabled: accessibilityReduceMotion,
                    onNarrationFinished: coordinator.closedWorldNarrationDidFinish,
                    onDiscovered: beginClosedWorldFade
                )
                .ignoresSafeArea()
                .opacity(coordinator.isClosedWorldFading ? 0 : 1)
                .allowsHitTesting(!coordinator.isClosedWorldFading)
                .animation(
                    .easeInOut(duration: EscapeRootMotion.closedWorldFadeDuration),
                    value: coordinator.isClosedWorldFading
                )
            }

            if coordinator.showsRealityView {
                realityView
                    .ignoresSafeArea()
            }

            chapterFourView

            VStack(spacing: 12) {
                ChapterProgressView(chapter: coordinator.machine.state.chapter)

                if coordinator.showsSceneUnderstanding {
                    RealityScanFeedbackView(
                        progress: coordinator.scanProgress,
                        presentation: coordinator.scanPresentation(
                            reduceMotion: accessibilityReduceMotion
                        )
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .allowsHitTesting(false)

            messageOverlay
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.showsRealityView)
        .onChange(of: coordinator.realitySurpriseSequence) { _, sequence in
            guard sequence > 0 else { return }
            performRealitySurprise()
        }
        .onChange(of: coordinator.message) { _, message in
            guard let message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
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

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.64, green: 0.93, blue: 0.99),
                Color(red: 0.41, green: 0.80, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var realityView: some View {
        let surfaceID = coordinator.realitySurfaceID
        return RealityHideARView(
            interactionMode: coordinator.realityInteractionMode,
            hideCycleResetSequence: coordinator.hideCycleResetSequence,
            scanPresentation: coordinator.scanPresentation(
                reduceMotion: accessibilityReduceMotion
            ),
            onScanUpdate: { update in
                scheduleRealityCallback(for: surfaceID) { $0.realityScanDidUpdate(update) }
            },
            onScanningReady: {
                scheduleRealityCallback(for: surfaceID) { $0.realityScanningDidBecomeReady() }
            },
            onTargetAccepted: {
                scheduleRealityCallback(for: surfaceID) { $0.realityTargetDidBecomeAccepted() }
            },
            onMovementFinished: {
                scheduleRealityCallback(for: surfaceID) { $0.realityMovementDidFinish() }
            },
            onOcclusionRetryStarted: {
                scheduleRealityCallback(for: surfaceID) { $0.realityOcclusionRetryDidStart() }
            },
            onOcclusionExhausted: {
                scheduleRealityCallback(for: surfaceID) { $0.realityOcclusionDidExhaust() }
            },
            onPigReachedTarget: {
                scheduleRealityCallback(for: surfaceID) { $0.realityOcclusionDidBecomeVerified() }
            },
            onRevealed: {
                scheduleRealityCallback(for: surfaceID) { $0.realityPigDidBecomeRevealed() }
            },
            onError: {
                scheduleRealityCallback(for: surfaceID) { $0.realityErrorDidOccur() }
            },
            onUnavailable: {
                scheduleRealityCallback(for: surfaceID) { $0.realityMeshDidBecomeUnavailable() }
            },
            onSessionFailed: {
                scheduleRealityCallback(for: surfaceID) { $0.realitySessionDidFail() }
            },
            onSessionInterrupted: {
                scheduleRealityCallback(for: surfaceID) { $0.realitySessionWasInterrupted() }
            },
            onSessionInterruptionEnded: {
                scheduleRealityCallback(for: surfaceID) { $0.realitySessionInterruptionEnded() }
            },
            onMessage: { message in
                scheduleRealityCallback(for: surfaceID) { $0.realityMessageDidChange(message) }
            }
        )
        .id(surfaceID)
        .scaleEffect(realityScreenScale)
        .clipped()
        .transition(.opacity)
    }

    @ViewBuilder
    private var chapterFourView: some View {
        switch coordinator.machine.state {
        case .comparison(let reason):
            ComparisonView(
                reason: reason,
                retryAvailability: coordinator.chapterThreeRetryAvailability,
                onFinish: coordinator.finishTutorial,
                onRetryChapterThree: coordinator.retryChapterThree,
                onReset: coordinator.resetExperience
            )

        case .completed(let reason):
            TutorialCompletionView(
                reason: reason,
                retryAvailability: coordinator.chapterThreeRetryAvailability,
                onRetryChapterThree: coordinator.retryChapterThree,
                onReset: coordinator.resetExperience
            )

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var messageOverlay: some View {
        if let message = coordinator.message,
           coordinator.machine.state != .discoveredByCamera,
           coordinator.machine.state != .requestingCameraPermission {
            VStack {
                Spacer()
                Text(message)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
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
                    .padding(.bottom, 18)
            }
            .allowsHitTesting(false)
            .transition(
                accessibilityReduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.96))
            )
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        switch coordinator.machine.state {
        case .realityReady:
            RootCTAButton(
                title: "숨바꼭질 시작",
                accessibilityHint: "실제 물체를 선택하는 단계로 이동합니다",
                isDisabled: coordinator.isSessionInterrupted,
                action: coordinator.startRealHide
            )
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

        case .cameraDenied:
            RootActionBar {
                RootCTAButton(
                    title: "설정 열기",
                    accessibilityHint: "앱의 카메라 권한 설정을 엽니다",
                    action: coordinator.openSettingsForRecovery
                )
                RootSecondaryButton(
                    title: "차이 먼저 보기",
                    accessibilityHint: "현실 체험을 건너뛰고 두 세계 비교를 엽니다",
                    action: coordinator.skipToComparison
                )
            }

        case .cameraRestricted, .lidarUnavailable:
            RootActionBar {
                RootCTAButton(
                    title: "차이 먼저 보기",
                    accessibilityHint: "현실 체험을 건너뛰고 두 세계 비교를 엽니다",
                    action: coordinator.skipToComparison
                )
            }

        case .sessionFailed, .scanTimedOut:
            RootActionBar {
                RootCTAButton(
                    title: "다시 스캔",
                    accessibilityHint: "새 AR 세션으로 공간 스캔을 다시 시작합니다",
                    action: coordinator.retryReality
                )
                RootSecondaryButton(
                    title: "차이 먼저 보기",
                    accessibilityHint: "스캔을 건너뛰고 두 세계 비교를 엽니다",
                    action: coordinator.skipToComparison
                )
            }

        case .realityAssetFailed:
            RootActionBar {
                RootCTAButton(
                    title: "피기 다시 불러오기",
                    accessibilityHint: "같은 AR 세션에서 새 숨기 cycle을 준비합니다",
                    action: coordinator.retryReality
                )
                RootSecondaryButton(
                    title: "차이 먼저 보기",
                    accessibilityHint: "피기 불러오기를 건너뛰고 두 세계 비교를 엽니다",
                    action: coordinator.skipToComparison
                )
            }

        case .discoveredInReality:
            RootActionBar {
                RootSecondaryButton(
                    title: "한 번 더 숨기",
                    accessibilityHint: "같은 공간에서 새 숨기 cycle을 시작합니다",
                    action: coordinator.replayRealHide
                )
                RootCTAButton(
                    title: "두 세계 비교",
                    accessibilityHint: "SceneKit과 RealityKit 비교 화면을 엽니다",
                    action: coordinator.reviewDifferences
                )
            }

        default:
            EmptyView()
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
        for surfaceID: Int,
        _ operation: @escaping @MainActor (EscapeRootCoordinator) -> Void
    ) {
        realityCallbacks.schedule { [weak coordinator] in
            guard let coordinator,
                  coordinator.showsRealityView,
                  coordinator.realitySurfaceID == surfaceID else { return }
            operation(coordinator)
        }
    }
}

private struct RootActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                content
            }
            VStack(spacing: 10) {
                content
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct RootCTAButton: View {
    let title: String
    var accessibilityHint: String?
    var isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        accessibilityHint: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .background(Color.yellow, in: Capsule())
            .accessibilityHint(accessibilityHint ?? "")
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.52 : 1)
    }
}

private struct RootSecondaryButton: View {
    let title: String
    var accessibilityHint: String?
    let action: () -> Void

    init(
        title: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .background(.black.opacity(0.44), in: Capsule())
            .accessibilityHint(accessibilityHint ?? "")
    }
}
