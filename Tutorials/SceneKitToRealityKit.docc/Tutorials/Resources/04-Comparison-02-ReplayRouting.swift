// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceLifetime.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeExperienceLifetimeTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift
// Implementation status: integrated
// Verification: standalone type-check와 generic build 완료; XCTest 실행 검증 대기; LiDAR 실기기 대기

enum ComparisonEntryReason {
    case completedHide
    case cameraDenied
    case cameraRestricted
    case lidarUnavailable
    case sessionFailed
    case scanTimedOut
    case assetFailed
}

enum ReplayState {
    case comparison(ComparisonEntryReason)
    case completed(ComparisonEntryReason)
    case scanningReality
    case openingNarration
}

struct RealityCallbackToken: Equatable {
    let experienceGeneration: Int
    let realityGeneration: Int
    let hideCycleGeneration: Int
}

struct ExperienceLifetime {
    private(set) var token = RealityCallbackToken(
        experienceGeneration: 0,
        realityGeneration: 0,
        hideCycleGeneration: 0
    )

    func accepts(_ candidate: RealityCallbackToken) -> Bool {
        candidate == token
    }

    mutating func beginNewRealitySession() {
        token = RealityCallbackToken(
            experienceGeneration: token.experienceGeneration,
            realityGeneration: token.realityGeneration + 1,
            hideCycleGeneration: token.hideCycleGeneration + 1
        )
    }

    mutating func resetExperience() {
        token = RealityCallbackToken(
            experienceGeneration: token.experienceGeneration + 1,
            realityGeneration: token.realityGeneration + 1,
            hideCycleGeneration: token.hideCycleGeneration + 1
        )
    }
}

protocol ARLifecycleControlling: AnyObject {
    func tearDownAR()
}

enum ReplayAction {
    case finishTutorial
    case retryChapterThree
    case resetFromBeginning
}

struct ReplayCTA {
    static let finish = "튜토리얼 완료"
    static let retryChapterThree = "Chapter 3 다시 하기"
    static let reset = "처음부터 다시 보기"
}

final class ReplayRouter {
    private let arLifecycle: any ARLifecycleControlling
    private(set) var state: ReplayState
    private(set) var lifetime = ExperienceLifetime()

    init(state: ReplayState, arLifecycle: any ARLifecycleControlling) {
        self.state = state
        self.arLifecycle = arLifecycle
    }

    var canRetryChapterThree: Bool {
        let reason: ComparisonEntryReason
        switch state {
        case let .comparison(value), let .completed(value):
            reason = value
        default:
            return false
        }
        switch reason {
        case .completedHide, .sessionFailed, .scanTimedOut, .assetFailed:
            return true
        case .cameraDenied, .cameraRestricted, .lidarUnavailable:
            return false
        }
    }

    @discardableResult
    func send(_ action: ReplayAction) -> Bool {
        switch (state, action) {
        case let (.comparison(reason), .finishTutorial):
            state = .completed(reason)
        case (.comparison, .retryChapterThree),
             (.completed, .retryChapterThree):
            guard canRetryChapterThree else { return false }
            arLifecycle.tearDownAR()
            lifetime.beginNewRealitySession()
            state = .scanningReality
        case (_, .resetFromBeginning):
            arLifecycle.tearDownAR()
            lifetime.resetExperience()
            state = .openingNarration
        default:
            return false
        }
        return true
    }

    func acceptsCallback(_ token: RealityCallbackToken) -> Bool {
        lifetime.accepts(token)
    }
}
