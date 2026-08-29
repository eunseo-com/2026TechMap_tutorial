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
    func schedule<Owner: AnyObject>(
        _ deadline: RealityDeadline,
        owner: Owner,
        operation: @escaping @MainActor (Owner) -> Void
    ) -> any RealityDeadlineCancellable
}

@MainActor
final class RealityDeadlineScheduler: RealityDeadlineScheduling {
    @discardableResult
    func schedule<Owner: AnyObject>(
        _ deadline: RealityDeadline,
        owner: Owner,
        operation: @escaping @MainActor (Owner) -> Void
    ) -> any RealityDeadlineCancellable {
        RealityTaskDeadline(owner: owner, delay: deadline.duration) { resolvedOwner in
            guard let typedOwner = resolvedOwner as? Owner else { return }
            operation(typedOwner)
        }
    }
}

@MainActor
private final class RealityTaskDeadline: RealityDeadlineCancellable {
    private weak var owner: AnyObject?
    private var operation: (@MainActor (AnyObject) -> Void)?
    private var task: Task<Void, Never>?
    private var isCancelled = false
    private var didFire = false

    init(owner: AnyObject, delay: TimeInterval, operation: @escaping @MainActor (AnyObject) -> Void) {
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
        operation = nil
    }

    private func fireIfOwned() {
        guard !isCancelled, !didFire, let owner else {
            operation = nil
            task = nil
            return
        }
        didFire = true
        let operation = operation
        self.operation = nil
        task = nil
        operation?(owner)
    }
}
