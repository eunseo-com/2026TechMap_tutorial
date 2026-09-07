import XCTest
import simd
#if !REALITY_POLICY_HOST_TESTS
@testable import PiggyEscape
#endif

final class RealityWalkRouteTests: XCTestCase {
    func test_obstructionReturnsToSelectionWithoutClaimingArrivalOrHidden() {
        var machine = EscapeExperienceMachine(state: .walkingBehindRealObject)
        XCTAssertTrue(machine.send(.movementObstructed))
        XCTAssertEqual(machine.state, .waitingForRealTarget)
        XCTAssertFalse(machine.send(.movementFinished))
        XCTAssertFalse(machine.send(.occlusionVerified))
    }

    func test_lateObstructionDoesNotUndoAnAlreadyVerifiedHide() {
        var machine = EscapeExperienceMachine(state: .hiddenInReality)
        XCTAssertFalse(machine.send(.movementObstructed))
        XCTAssertEqual(machine.state, .hiddenInReality)
    }

    func test_routeGoesAroundAnObstacleInsteadOfJoiningFrontAndBackDirectly() throws {
        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(for: plan(), isSegmentClear: clearOfBox))
        XCTAssertEqual(route.points.first, plan().start)
        XCTAssertGreaterThanOrEqual(route.points.count, 4)
        XCTAssertTrue(zip(route.points, route.points.dropFirst()).allSatisfy { clearOfBox($0.0, $0.1) })
        XCTAssertGreaterThan(route.points.map { abs($0.x) }.max()!, 0.35)
    }

    func test_noClearSideReturnsNoRouteRatherThanWalkingThroughTheObject() {
        XCTAssertNil(RealityWalkRoutePlanner.route(for: plan()) { _, _ in false })
    }

    func test_routeNeverLeavesTheRecognizedFloor() {
        let narrow = plan(extent: [0.55, 3])
        XCTAssertNil(RealityWalkRoutePlanner.route(for: narrow, isSegmentClear: clearOfBox))
    }

    func test_blockedPreferredSideUsesTheOtherSide() throws {
        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(for: plan()) { start, end in
            start.x <= 0.001 && end.x <= 0.001 && self.clearOfBox(start, end)
        })
        XCTAssertLessThan(route.points.map(\.x).min()!, -0.35)
        XCTAssertLessThanOrEqual(route.points.map(\.x).max()!, 0.001)
    }

    func test_deepObjectRequiresADeeperDestination() throws {
        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(for: plan()) { start, end in
            self.clearOfBox(start, end, back: -0.65)
        })
        XCTAssertLessThan(route.points.last!.z, -0.65)
    }

    func test_nonFinitePlanDoesNotReachTheCollisionProvider() {
        var castCount = 0
        let invalid = RealityHidePlan(start: [.nan, 0, 0], destination: [0, 0, -0.28],
                                      retreatDirection: [0, 0, -1], floorRegion: plan().floorRegion)
        XCTAssertNil(RealityWalkRoutePlanner.route(for: invalid) { _, _ in castCount += 1; return true })
        XCTAssertEqual(castCount, 0)
    }

    private func plan(extent: SIMD2<Float> = [5, 5]) -> RealityHidePlan {
        RealityHidePlan(start: [0, 0, 0.28], destination: [0, 0, -0.28],
                        retreatDirection: [0, 0, -1], floorRegion: RealityFloorRegion(
                            anchorIdentifier: UUID(), transform: matrix_identity_float4x4,
                            center: .zero, extent: extent
                        ))
    }

    /// Analytic segment-vs-rectangle intersection: independent of the route algorithm.
    private func clearOfBox(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> Bool {
        clearOfBox(start, end, back: -0.2)
    }

    private func clearOfBox(_ start: SIMD3<Float>, _ end: SIMD3<Float>, back: Float) -> Bool {
        var entering: Float = 0
        var leaving: Float = 1
        for (s, d, lower, upper) in [(start.x, end.x - start.x, Float(-0.35), Float(0.35)),
                                    (start.z, end.z - start.z, back, Float(0.12))] {
            if abs(d) < 0.00001 {
                if s < lower || s > upper { return true }
            } else {
                let first = (lower - s) / d
                let second = (upper - s) / d
                entering = max(entering, min(first, second))
                leaving = min(leaving, max(first, second))
                if entering > leaving { return true }
            }
        }
        return false
    }
}
