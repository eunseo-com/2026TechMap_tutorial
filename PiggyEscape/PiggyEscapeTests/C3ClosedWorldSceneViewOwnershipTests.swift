import XCTest
@testable import PiggyEscape

@MainActor
final class C3ClosedWorldSceneViewOwnershipTests: XCTestCase {
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
}
