import XCTest
import simd
#if !REALITY_POLICY_HOST_TESTS
@testable import PiggyEscape
#endif

final class RealityWalkRouteTests: XCTestCase {
    func test_protrudingFurnitureBaseUsesClearerInitialSpawnInRoutedPlan() throws {
        let result = RealityHidePlanner.plan(
            hit: RealitySurfaceHit(point: [0, 0.8, 0], normal: [0, 0, 1]),
            cameraPosition: [0, 1.2, 2], floorRegion: plan().floorRegion
        )
        guard case let .accepted(sofaPlan) = result else { return XCTFail("Expected valid side selection") }
        XCTAssertEqual(sofaPlan.cameraPosition, [0, 1.2, 2])
        // Configuration-space obstacle: a 1m-wide base protrudes 0.40m in front
        // of the tapped upper surface, expanded by the 0.20m body radius.
        let isClear: (SIMD3<Float>, SIMD3<Float>) -> Bool = {
            self.clearOfRectangle($0, $1, minimum: [-0.70, -0.75], maximum: [0.70, 0.60])
        }
        XCTAssertFalse(isClear(sofaPlan.start, sofaPlan.start + [0.8, 0, 0]))
        let knownOpenPath: [SIMD3<Float>] = [[0, 0, 0.73], [0.8, 0, 0.73], [0.8, 0, -0.83], [0, 0, -0.83]]
        XCTAssertTrue(zip(knownOpenPath, knownOpenPath.dropFirst()).allSatisfy(isClear))

        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(for: sofaPlan, isSegmentClear: isClear))
        XCTAssertGreaterThan(route.points.first!.z, 0.60)
        XCTAssertLessThan(route.points.last!.z, -0.75)
        XCTAssertTrue(zip(route.points, route.points.dropFirst()).allSatisfy(isClear))

        let routedPlan = try XCTUnwrap(sofaPlan.routed(along: route))
        XCTAssertEqual(routedPlan.start, route.points.first)
        XCTAssertEqual(routedPlan.destination, route.points.last)
        XCTAssertEqual(routedPlan.waypoints, Array(route.points.dropFirst()))
        XCTAssertEqual(routedPlan.cameraPosition, sofaPlan.cameraPosition)
        XCTAssertNotEqual(routedPlan.start, sofaPlan.start)
    }

    func test_clearCorridorBetweenCoarseSideCandidatesIsNotMissed() throws {
        let corridorPlan = plan(extent: [1.65, 3])
        let isClear: (SIMD3<Float>, SIMD3<Float>) -> Bool = {
            self.clearOfRectangle($0, $1, minimum: [-0.45, -0.40], maximum: [0.45, 0.20])
        }
        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(for: corridorPlan, isSegmentClear: isClear))
        let side = route.points.map { abs($0.x) }.max()!
        XCTAssertGreaterThan(side, 0.45)
        XCTAssertLessThanOrEqual(side, 0.525)
        XCTAssertTrue(zip(route.points, route.points.dropFirst()).allSatisfy(isClear))
    }

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
        var failures: [RealityWalkRouteFailure] = []
        let route = try XCTUnwrap(RealityWalkRoutePlanner.route(
            for: plan(),
            onFailure: { failures.append($0) },
            isSegmentClear: clearOfBox
        ))
        XCTAssertEqual(route.points.first, plan().start)
        XCTAssertGreaterThanOrEqual(route.points.count, 4)
        XCTAssertTrue(zip(route.points, route.points.dropFirst()).allSatisfy { clearOfBox($0.0, $0.1) })
        XCTAssertGreaterThan(route.points.map { abs($0.x) }.max()!, 0.35)
        XCTAssertEqual(failures, [])
    }

    func test_noClearSideReportsObstructionOnceRatherThanWalkingThroughTheObject() {
        var failures: [RealityWalkRouteFailure] = []
        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: plan(),
            onFailure: { failures.append($0) },
            isSegmentClear: { _, _ in false }
        ))
        XCTAssertEqual(failures, [.movementObstructed])
    }

    func test_routeNeverLeavesTheRecognizedFloorAndReportsInsufficientFloorOnce() {
        let narrow = plan(extent: [0.55, 3])
        var failures: [RealityWalkRouteFailure] = []
        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: narrow,
            onFailure: { failures.append($0) },
            isSegmentClear: clearOfBox
        ))
        XCTAssertEqual(failures, [.insufficientFloor])
    }

    func test_cameraClearanceRejectsEveryCandidateBeforeCollisionChecks() {
        let closeCameraPlan = plan(cameraPosition: [0, 0, 0.88])
        var failures: [RealityWalkRouteFailure] = []
        var collisionCheckCount = 0

        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: closeCameraPlan,
            onFailure: { failures.append($0) },
            isSegmentClear: { _, _ in
                collisionCheckCount += 1
                return true
            }
        ))

        XCTAssertEqual(failures, [.cameraTooClose])
        XCTAssertEqual(collisionCheckCount, 0)
    }

    func test_legacyPlanWithoutCameraSnapshotDoesNotExpandItsStart() {
        let legacyPlan = plan()
        var observedExpandedStart = false

        XCTAssertNil(RealityWalkRoutePlanner.route(for: legacyPlan) { start, _ in
            if abs(start.x - legacyPlan.start.x) < 0.0001,
               start.z > legacyPlan.start.z + 0.0001 {
                observedExpandedStart = true
            }
            return false
        })

        XCTAssertFalse(observedExpandedStart)
    }

    func test_repeatedSegmentsUseOneCollisionResultWithinASearch() {
        var callsBySegment: [String: Int] = [:]

        XCTAssertNil(RealityWalkRoutePlanner.route(for: plan(cameraPosition: [0, 0, 4])) { start, end in
            let key = [start.x, start.y, start.z, end.x, end.y, end.z]
                .map { String($0.bitPattern) }
                .joined(separator: ":")
            callsBySegment[key, default: 0] += 1
            return false
        })

        XCTAssertFalse(callsBySegment.isEmpty)
        XCTAssertEqual(callsBySegment.values.max(), 1)
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
        var failures: [RealityWalkRouteFailure] = []
        let invalid = RealityHidePlan(start: [.nan, 0, 0], destination: [0, 0, -0.28],
                                      retreatDirection: [0, 0, -1], floorRegion: plan().floorRegion)
        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: invalid,
            onFailure: { failures.append($0) },
            isSegmentClear: { _, _ in castCount += 1; return true }
        ))
        XCTAssertEqual(castCount, 0)
        XCTAssertEqual(failures, [.invalidPlan])
    }

    func test_nonFiniteCameraSnapshotDoesNotReachTheCollisionProvider() {
        var castCount = 0
        var failures: [RealityWalkRouteFailure] = []
        let invalid = plan(cameraPosition: [.nan, 0, 0])

        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: invalid,
            onFailure: { failures.append($0) },
            isSegmentClear: { _, _ in castCount += 1; return true }
        ))

        XCTAssertEqual(castCount, 0)
        XCTAssertEqual(failures, [.invalidPlan])
    }

    func test_finiteRetreatWhoseSquaredLengthOverflowsIsRejectedBeforeCollisionChecks() {
        var castCount = 0
        var failures: [RealityWalkRouteFailure] = []
        let invalid = RealityHidePlan(
            start: [0, 0, 0.28],
            destination: [0, 0, -0.28],
            retreatDirection: [.greatestFiniteMagnitude, 0, .greatestFiniteMagnitude],
            floorRegion: plan().floorRegion
        )

        XCTAssertNil(RealityWalkRoutePlanner.route(
            for: invalid,
            onFailure: { failures.append($0) },
            isSegmentClear: { _, _ in castCount += 1; return true }
        ))

        XCTAssertEqual(castCount, 0)
        XCTAssertEqual(failures, [.invalidPlan])
    }

    private func plan(
        extent: SIMD2<Float> = [5, 5],
        cameraPosition: SIMD3<Float>? = nil
    ) -> RealityHidePlan {
        RealityHidePlan(start: [0, 0, 0.28], destination: [0, 0, -0.28],
                        retreatDirection: [0, 0, -1], floorRegion: RealityFloorRegion(
                            anchorIdentifier: UUID(), transform: matrix_identity_float4x4,
                            center: .zero, extent: extent
                        ), cameraPosition: cameraPosition)
    }

    /// Analytic segment-vs-rectangle intersection: independent of the route algorithm.
    private func clearOfBox(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> Bool {
        clearOfBox(start, end, back: -0.2)
    }

    private func clearOfBox(_ start: SIMD3<Float>, _ end: SIMD3<Float>, back: Float) -> Bool {
        clearOfRectangle(start, end, minimum: [-0.35, back], maximum: [0.35, 0.12])
    }

    private func clearOfRectangle(
        _ start: SIMD3<Float>, _ end: SIMD3<Float>,
        minimum: SIMD2<Float>, maximum: SIMD2<Float>
    ) -> Bool {
        var entering: Float = 0
        var leaving: Float = 1
        for (s, d, lower, upper) in [(start.x, end.x - start.x, minimum.x, maximum.x),
                                    (start.z, end.z - start.z, minimum.y, maximum.y)] {
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
