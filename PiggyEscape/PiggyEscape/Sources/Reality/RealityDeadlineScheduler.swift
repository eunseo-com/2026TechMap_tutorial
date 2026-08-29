import Foundation

enum RealityDeadline {
    case scan
    case interruption
    case occlusionObservation

    var duration: TimeInterval {
        switch self {
        case .scan:
            20.0
        case .interruption:
            10.0
        case .occlusionObservation:
            1.5
        }
    }
}

@MainActor
protocol RealityDeadlineCancellable: AnyObject {
    func cancel()
}

@MainActor
protocol RealityDeadlineScheduling: AnyObject {
    @discardableResult
    func schedule(
        _ deadline: RealityDeadline,
        owner: AnyObject,
        operation: @escaping @MainActor () -> Void
    ) -> any RealityDeadlineCancellable
}

@MainActor
final class RealityDeadlineScheduler: RealityDeadlineScheduling {
    @discardableResult
    func schedule(
        _ deadline: RealityDeadline,
        owner: AnyObject,
        operation: @escaping @MainActor () -> Void
    ) -> any RealityDeadlineCancellable {
        RealityTaskDeadline(owner: owner, delay: deadline.duration, operation: operation)
    }
}

@MainActor
private final class RealityTaskDeadline: RealityDeadlineCancellable {
    private weak var owner: AnyObject?
    private let operation: @MainActor () -> Void
    private var task: Task<Void, Never>?
    private var isCancelled = false
    private var didFire = false

    init(owner: AnyObject, delay: TimeInterval, operation: @escaping @MainActor () -> Void) {
        self.owner = owner
        self.operation = operation
        task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            self?.fireIfOwned()
        }
    }

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }

    private func fireIfOwned() {
        guard !isCancelled, !didFire, owner != nil else { return }
        didFire = true
        task = nil
        operation()
    }
}
