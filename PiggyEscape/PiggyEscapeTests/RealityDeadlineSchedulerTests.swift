import XCTest
@testable import PiggyEscape

@MainActor
final class RealityDeadlineSchedulerTests: XCTestCase {
    func test_eachDeadlineSchedulesItsSpecifiedDuration() {
        let scheduler = ManualRealityDeadlineScheduler()
        let owner = DeadlineOwner()

        scheduler.schedule(.scan, owner: owner) { _ in }
        scheduler.schedule(.interruption, owner: owner) { _ in }
        scheduler.schedule(.occlusionObservation, owner: owner) { _ in }

        XCTAssertEqual(scheduler.scheduledDelays, [20.0, 10.0, 1.5])
    }

    func test_cancelledDeadlineNeverFires() {
        let scheduler = ManualRealityDeadlineScheduler()
        let owner = DeadlineOwner()
        var fired = 0
        let task = scheduler.schedule(.scan, owner: owner) { _ in fired += 1 }

        task.cancel()
        scheduler.advance(by: 20.0)

        XCTAssertEqual(fired, 0)
    }

    func test_deadlineFiresOnceAfterItsMonotonicDeadline() {
        let scheduler = ManualRealityDeadlineScheduler()
        let owner = DeadlineOwner()
        var fired = 0
        scheduler.schedule(.occlusionObservation, owner: owner) { _ in fired += 1 }

        scheduler.advance(by: 1.49)
        XCTAssertEqual(fired, 0)
        scheduler.advance(by: 0.01)
        scheduler.advance(by: 10.0)

        XCTAssertEqual(fired, 1)
    }

    func test_deadlineDoesNotDeliverAfterItsOwnerIsReleased() {
        let scheduler = ManualRealityDeadlineScheduler()
        var fired = 0
        var owner: DeadlineOwner? = DeadlineOwner()
        scheduler.schedule(.interruption, owner: owner!) { _ in fired += 1 }
        owner = nil

        scheduler.advance(by: 10.0)

        XCTAssertEqual(fired, 0)
    }

    func test_productionDeadlineDoesNotRetainAnOwnerThatStoresItsHandle() {
        let scheduler = RealityDeadlineScheduler()
        weak var releasedOwner: RetainingDeadlineOwner?

        do {
            let owner = RetainingDeadlineOwner()
            releasedOwner = owner
            owner.deadline = scheduler.schedule(.scan, owner: owner) { retainedOwner in
                retainedOwner.didReceiveDeadline += 1
            }
        }

        XCTAssertNil(releasedOwner)
    }
}

private final class DeadlineOwner {}

@MainActor
private final class RetainingDeadlineOwner {
    var deadline: (any RealityDeadlineCancellable)?
    var didReceiveDeadline = 0
}

@MainActor
private final class ManualRealityDeadlineScheduler: RealityDeadlineScheduling {
    private(set) var scheduledDelays: [TimeInterval] = []
    private var now: TimeInterval = 0
    private var tasks: [ManualRealityDeadlineTask] = []

    @discardableResult
    func schedule<Owner: AnyObject>(
        _ deadline: RealityDeadline,
        owner: Owner,
        operation: @escaping @MainActor (Owner) -> Void
    ) -> any RealityDeadlineCancellable {
        scheduledDelays.append(deadline.duration)
        let task = ManualRealityDeadlineTask(
            dueTime: now + deadline.duration,
            owner: owner,
            operation: { resolvedOwner in
                guard let typedOwner = resolvedOwner as? Owner else { return }
                operation(typedOwner)
            }
        )
        tasks.append(task)
        return task
    }

    func advance(by duration: TimeInterval) {
        now += duration
        tasks.forEach { task in
            task.fireIfDue(at: now)
        }
    }
}

@MainActor
private final class ManualRealityDeadlineTask: RealityDeadlineCancellable {
    private let dueTime: TimeInterval
    private weak var owner: AnyObject?
    private var operation: (@MainActor (AnyObject) -> Void)?
    private var isCancelled = false
    private var didFire = false

    init(dueTime: TimeInterval, owner: AnyObject, operation: @escaping @MainActor (AnyObject) -> Void) {
        self.dueTime = dueTime
        self.owner = owner
        self.operation = operation
    }

    func cancel() {
        isCancelled = true
        operation = nil
    }

    func fireIfDue(at time: TimeInterval) {
        guard !isCancelled, !didFire, let owner, time >= dueTime else {
            if time >= dueTime {
                operation = nil
            }
            return
        }
        didFire = true
        let operation = operation
        self.operation = nil
        operation?(owner)
    }
}
