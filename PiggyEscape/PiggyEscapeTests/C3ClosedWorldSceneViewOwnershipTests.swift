import XCTest
import SceneKit
@testable import PiggyEscape

@MainActor
final class C3ClosedWorldSceneViewOwnershipTests: XCTestCase {
    func test_reduceMotionKeepsSurpriseContentWithoutScaleAction() {
        let coordinator = C3ClosedWorldSceneView(
            reduceMotionEnabled: true
        ).makeCoordinator()

        coordinator.world.performSurpriseReaction()

        XCTAssertEqual(coordinator.world.currentPose, .surprised)
        XCTAssertEqual(coordinator.world.lastCaption, "아, 들켰네… 제대로 숨고 싶은데.")
        XCTAssertNil(coordinator.world.pigContainer.action(forKey: "escapePig.surpriseScale"))
    }

    func test_standardMotionRunsSurpriseScaleAction() {
        let coordinator = C3ClosedWorldSceneView(
            reduceMotionEnabled: false
        ).makeCoordinator()

        coordinator.world.performSurpriseReaction()

        XCTAssertNotNil(coordinator.world.pigContainer.action(forKey: "escapePig.surpriseScale"))
    }

    func test_coordinatorIsReleasedWhenWorldOutlivesInstalledCallbacks() {
        weak var releasedCoordinator: C3ClosedWorldSceneView.Coordinator?
        var retainedWorld: C3ClosedWorld?

        autoreleasepool {
            var coordinator: C3ClosedWorldSceneView.Coordinator? = .init(onDiscovered: {})
            coordinator?.installCallbacks()
            retainedWorld = coordinator?.world
            releasedCoordinator = coordinator
            coordinator = nil
        }

        XCTAssertNotNil(retainedWorld)
        XCTAssertNil(releasedCoordinator)
    }

    func test_treeArrivalDefersCoordinatorDiscoveryUntilScheduledOperationFires() {
        let scheduler = ControlledAutoDiscoveryScheduler()
        var discoveries = 0
        let coordinator = C3ClosedWorldSceneView.Coordinator(
            onDiscovered: { discoveries += 1 },
            autoDiscoveryScheduler: scheduler
        )
        coordinator.installCallbacks()

        prepareTreeArrival(for: coordinator)

        XCTAssertEqual(scheduler.delays, [C3AutoAdvance.treeArrivalDelay])
        XCTAssertEqual(coordinator.world.currentPose, .idle)
        XCTAssertEqual(discoveries, 0)

        scheduler.fireAll()

        XCTAssertEqual(coordinator.world.currentPose, .surprised)
        XCTAssertEqual(discoveries, 1)
    }

    func test_treeArrivalQueuesOnlyOneCoordinatorOperation() {
        let scheduler = ControlledAutoDiscoveryScheduler()
        let coordinator = C3ClosedWorldSceneView.Coordinator(
            onDiscovered: {},
            autoDiscoveryScheduler: scheduler
        )
        coordinator.installCallbacks()

        prepareTreeArrival(for: coordinator)
        coordinator.world.finishTreeHideForTesting()

        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func test_dismantleCancelsAutomaticDiscoveryBeforeItsScheduledOperationFires() {
        let scheduler = ControlledAutoDiscoveryScheduler()
        var discoveries = 0
        let coordinator = C3ClosedWorldSceneView.Coordinator(
            onDiscovered: { discoveries += 1 },
            autoDiscoveryScheduler: scheduler
        )
        coordinator.installCallbacks()
        prepareTreeArrival(for: coordinator)

        C3ClosedWorldSceneView.dismantleUIView(SCNView(), coordinator: coordinator)
        scheduler.fireAll()

        XCTAssertEqual(coordinator.world.currentPose, .idle)
        XCTAssertEqual(discoveries, 0)
    }

    func test_panRemainsVisualOnlyWhileAutomaticDiscoveryIsQueued() {
        let scheduler = ControlledAutoDiscoveryScheduler()
        var discoveries = 0
        let coordinator = C3ClosedWorldSceneView.Coordinator(
            onDiscovered: { discoveries += 1 },
            autoDiscoveryScheduler: scheduler
        )
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        coordinator.scnView = view
        coordinator.installCallbacks()
        prepareTreeArrival(for: coordinator)

        let pan = UIPanGestureRecognizer()
        pan.setTranslation(CGPoint(x: 160, y: 0), in: view)
        coordinator.handlePan(pan)

        XCTAssertEqual(scheduler.scheduledCount, 1)
        XCTAssertEqual(discoveries, 0)
    }

    private func prepareTreeArrival(for coordinator: C3ClosedWorldSceneView.Coordinator) {
        coordinator.world.completeOpeningNarration()
        XCTAssertTrue(coordinator.world.tapPig())
        coordinator.world.finishTreeHideForTesting()
    }
}

@MainActor
private final class ControlledAutoDiscoveryScheduler: C3AutoDiscoveryScheduling {
    private(set) var delays: [TimeInterval] = []
    private var tasks: [ControlledAutoDiscoveryTask] = []

    var scheduledCount: Int { tasks.count }

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> C3AutoDiscoveryCancellable {
        delays.append(delay)
        let task = ControlledAutoDiscoveryTask(operation: operation)
        tasks.append(task)
        return task
    }

    func fireAll() {
        tasks.forEach { $0.fire() }
    }
}

private final class ControlledAutoDiscoveryTask: C3AutoDiscoveryCancellable {
    private var isCancelled = false
    private let operation: @MainActor () -> Void

    init(operation: @escaping @MainActor () -> Void) {
        self.operation = operation
    }

    func cancel() {
        isCancelled = true
    }

    @MainActor
    func fire() {
        guard !isCancelled else { return }
        operation()
    }
}
