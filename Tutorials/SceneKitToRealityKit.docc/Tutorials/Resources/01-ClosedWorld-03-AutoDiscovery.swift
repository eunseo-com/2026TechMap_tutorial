// Production: PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorld.swift
// Production: PiggyEscape/PiggyEscape/Sources/C3World/C3ClosedWorldSceneView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootView.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/C3ClosedWorldSceneViewOwnershipTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/EscapeRootCoordinatorTests.swift

import Foundation

@MainActor
protocol AutoDiscoveryCancellable: AnyObject {
    func cancel()
}

@MainActor
protocol AutoDiscoveryScheduling {
    func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> any AutoDiscoveryCancellable
}

@MainActor
final class ClosedWorldAutoDiscovery {
    static let treeArrivalDelay: TimeInterval = 0.40
    static let surprisePeakScale = 1.5
    static let surpriseRestoreScale = 1.0

    private let scheduler: any AutoDiscoveryScheduling
    private var scheduledWork: (any AutoDiscoveryCancellable)?
    private var hasReachedTree = false
    private var hasDiscovered = false

    var onSurprise: (_ peakScale: Double, _ restoreScale: Double) -> Void = { _, _ in }

    init(scheduler: any AutoDiscoveryScheduling) {
        self.scheduler = scheduler
    }

    func pigReachedHideTree() {
        hasReachedTree = true
        scheduledWork?.cancel()
        scheduledWork = scheduler.schedule(after: Self.treeArrivalDelay) { [weak self] in
            self?.discoverOnce()
        }
    }

    func cancelForViewRemoval() {
        scheduledWork?.cancel()
        scheduledWork = nil
    }

    private func discoverOnce() {
        scheduledWork = nil
        guard hasReachedTree, !hasDiscovered else { return }
        hasDiscovered = true
        onSurprise(Self.surprisePeakScale, Self.surpriseRestoreScale)
    }
}

@MainActor
final class ClosedWorldRootFade {
    static let duration: TimeInterval = 0.70

    private var task: Task<Void, Never>?

    func begin(onFinished: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    func cancelForViewRemoval() {
        task?.cancel()
        task = nil
    }
}
