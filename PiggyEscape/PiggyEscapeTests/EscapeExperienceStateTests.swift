import XCTest
@testable import PiggyEscape

final class EscapeExperienceStateTests: XCTestCase {
    func test_pigTapIsIgnoredUntilOpeningNarrationCompletes() {
        var machine = EscapeExperienceMachine()
        XCTAssertFalse(machine.send(.pigTapped))
        XCTAssertEqual(machine.state, .openingNarration)

        XCTAssertTrue(machine.send(.narrationFinished))
        XCTAssertTrue(machine.send(.pigTapped))
        XCTAssertEqual(machine.state, .walkingBehindTree)
    }

    func test_discoverySequenceCanReachRealityOnlyInOrder() {
        var machine = EscapeExperienceMachine(state: .hiddenInClosedWorld)
        XCTAssertTrue(machine.send(.closedWorldPigDiscovered))
        XCTAssertEqual(machine.state, .discoveredByCamera)
        XCTAssertTrue(machine.send(.closedWorldFadeFinished))
        XCTAssertEqual(machine.state, .requestingCameraPermission)
        XCTAssertTrue(machine.send(.cameraAuthorized))
        XCTAssertEqual(machine.state, .scanningReality)
    }
}
