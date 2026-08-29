import XCTest
@testable import PiggyEscape

final class EscapeExperienceLifetimeTests: XCTestCase {
    func test_resetAdvancesEveryGenerationAndRejectsThePreviousToken() {
        var lifetime = EscapeExperienceLifetime()
        let previous = lifetime.currentToken

        lifetime.resetExperience()

        XCTAssertEqual(lifetime.currentToken, RealityCallbackToken(
            experienceGeneration: 1,
            realityGeneration: 1,
            hideCycleGeneration: 1
        ))
        XCTAssertFalse(lifetime.accepts(previous))
    }

    func test_newRealitySessionAdvancesRealityAndCycleWithoutResettingExperience() {
        var lifetime = EscapeExperienceLifetime()
        let previous = lifetime.currentToken

        lifetime.beginNewRealitySession()

        XCTAssertEqual(lifetime.currentToken, RealityCallbackToken(
            experienceGeneration: 0,
            realityGeneration: 1,
            hideCycleGeneration: 1
        ))
        XCTAssertFalse(lifetime.accepts(previous))
    }

    func test_newHideCycleAdvancesOnlyTheCycleAndStaleCallbackIsRejected() {
        var lifetime = EscapeExperienceLifetime()
        let previous = lifetime.currentToken

        lifetime.beginNewHideCycle()

        XCTAssertEqual(lifetime.currentToken, RealityCallbackToken(
            experienceGeneration: 0,
            realityGeneration: 0,
            hideCycleGeneration: 1
        ))
        XCTAssertFalse(lifetime.accepts(previous))
        XCTAssertTrue(lifetime.accepts(lifetime.currentToken))
    }
}
