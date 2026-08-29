struct RealityEnvironmentReadiness {
    private var hasObservedMesh = false
    private var hasObservedClassifiedFloor = false
    private var hasReportedReady = false

    var isReady: Bool {
        hasObservedMesh && hasObservedClassifiedFloor
    }

    @discardableResult
    mutating func observeMesh() -> Bool {
        hasObservedMesh = true
        return reportReadinessIfNeeded()
    }

    @discardableResult
    mutating func observeClassifiedFloor() -> Bool {
        hasObservedClassifiedFloor = true
        return reportReadinessIfNeeded()
    }

    private mutating func reportReadinessIfNeeded() -> Bool {
        guard isReady, !hasReportedReady else { return false }
        hasReportedReady = true
        return true
    }
}
