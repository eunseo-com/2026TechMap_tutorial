// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift

enum CameraAuthorizationResult {
    case authorized
    case denied
    case restricted
    case notDetermined
}

enum CameraAuthorizationAction {
    case enterRealityScanning
    case requestSystemPermission
    case showDeniedRecovery
    case showRestrictedExplanation
    case waitForSystemDecision
}

struct CameraAuthorizationFlow {
    private(set) var currentResult: CameraAuthorizationResult = .notDetermined
    private(set) var hasRequestedSystemPermission = false
    private(set) var isSettingsRecheckArmed = false

    var showsSettingsCTA: Bool {
        currentResult == .denied
    }

    mutating func begin(with result: CameraAuthorizationResult) -> CameraAuthorizationAction {
        currentResult = result
        switch result {
        case .authorized:
            return .enterRealityScanning
        case .denied:
            return .showDeniedRecovery
        case .restricted:
            return .showRestrictedExplanation
        case .notDetermined where !hasRequestedSystemPermission:
            hasRequestedSystemPermission = true
            return .requestSystemPermission
        case .notDetermined:
            return .waitForSystemDecision
        }
    }

    @discardableResult
    mutating func didOpenSettings() -> Bool {
        guard currentResult == .denied, !isSettingsRecheckArmed else { return false }
        isSettingsRecheckArmed = true
        return true
    }

    mutating func applicationDidBecomeActive(
        current result: CameraAuthorizationResult
    ) -> CameraAuthorizationAction? {
        guard isSettingsRecheckArmed else { return nil }
        isSettingsRecheckArmed = false
        return begin(with: result)
    }
}
