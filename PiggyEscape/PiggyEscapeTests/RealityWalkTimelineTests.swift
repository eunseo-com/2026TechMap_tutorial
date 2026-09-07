import XCTest
import simd
#if !REALITY_POLICY_HOST_TESTS
@testable import PiggyEscape
#endif

final class RealityWalkTimelineTests: XCTestCase {
    func test_turnHappensGraduallyBeforeTranslation() throws {
        let timeline = try XCTUnwrap(RealityWalkTimeline(points: [.zero, [1, 0, 0]], initialYaw: 0))
        let sample = timeline.sample(at: 0.1)
        XCTAssertEqual(sample.position, .zero)
        XCTAssertGreaterThan(sample.yaw, 0)
        XCTAssertLessThan(sample.yaw, .pi / 2)
        XCTAssertFalse(sample.isComplete)
    }

    func test_movementUsesWorldDistanceAndFinishesAtTheExactFinalPoint() throws {
        let timeline = try XCTUnwrap(RealityWalkTimeline(points: [.zero, [1, 0, 0]], initialYaw: .pi / 2))
        XCTAssertEqual(timeline.sample(at: 1).position.x, 0.45, accuracy: 0.001)
        XCTAssertFalse(timeline.sample(at: 1).isComplete)
        XCTAssertEqual(timeline.sample(at: timeline.duration).position, [1, 0, 0])
        XCTAssertTrue(timeline.sample(at: timeline.duration + 10).isComplete)
    }

    func test_sampleNeverCutsAcrossTheValidatedCorner() throws {
        let timeline = try XCTUnwrap(RealityWalkTimeline(points: [.zero, [1, 0, 0], [1, 0, -1]], initialYaw: .pi / 2))
        for index in 0...100 {
            let position = timeline.sample(at: timeline.duration * Double(index) / 100).position
            XCTAssertTrue(abs(position.z) < 0.0001 || abs(position.x - 1) < 0.0001)
        }
    }

    func test_turnUsesTheShortestArcAcrossTheYawBoundary() throws {
        let direction = SIMD3<Float>(sin(-Float.pi + 0.1), 0, cos(-Float.pi + 0.1))
        let timeline = try XCTUnwrap(RealityWalkTimeline(points: [.zero, direction], initialYaw: .pi - 0.1))
        XCTAssertLessThan(timeline.duration - 1 / 0.45, 0.2)
    }

    func test_invalidInputsAndTimeCannotCreateATeleportOrCompletion() throws {
        XCTAssertNil(RealityWalkTimeline(points: [.zero], initialYaw: 0))
        XCTAssertNil(RealityWalkTimeline(points: [.zero, [.nan, 0, 0]], initialYaw: 0))
        XCTAssertNil(RealityWalkTimeline(points: [.zero, [1, 0, 0]], initialYaw: .nan))
        let timeline = try XCTUnwrap(RealityWalkTimeline(points: [.zero, [1, 0, 0]], initialYaw: 0))
        for time in [Double.nan, .infinity, -1] {
            XCTAssertEqual(timeline.sample(at: time).position, .zero)
            XCTAssertFalse(timeline.sample(at: time).isComplete)
        }
    }
}
