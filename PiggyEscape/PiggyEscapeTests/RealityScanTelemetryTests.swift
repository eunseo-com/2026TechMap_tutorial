import XCTest
#if !REALITY_POLICY_HOST_TESTS
@testable import PiggyEscape
#endif

final class RealityScanTelemetryTests: XCTestCase {
    func test_liveCountsContinueChangingAfterReadiness() {
        var tracker = RealityScanTelemetryTracker()
        XCTAssertEqual(tracker.observe(sample(10, meshes: 1, faces: 20))?.meshFaceCount, 20)
        XCTAssertEqual(tracker.observe(sample(10.25, meshes: 3, faces: 84))?.meshAnchorCount, 3)
        XCTAssertEqual(tracker.latest.meshFaceCount, 84)
        XCTAssertTrue(tracker.latest.canSelectTargets)
    }

    func test_duplicateOutOfOrderAndInvalidFramesCannotOverwriteLatest() {
        var tracker = RealityScanTelemetryTracker()
        _ = tracker.observe(sample(10, meshes: 2))
        for timestamp in [10, 9, .nan, .infinity, -1] {
            XCTAssertNil(tracker.observe(sample(timestamp, meshes: 99)))
        }
        XCTAssertEqual(tracker.latest.meshAnchorCount, 2)
        XCTAssertNil(tracker.observe(sample(11, meshes: -1)))
    }

    func test_geometryUpdatesAreThrottledButTrackingLossIsImmediate() {
        var tracker = RealityScanTelemetryTracker()
        _ = tracker.observe(sample(10))
        XCTAssertNil(tracker.observe(sample(10.1, faces: 40)))
        let lost = tracker.observe(sample(10.11, tracking: .excessiveMotion))
        XCTAssertEqual(lost?.tracking, .excessiveMotion)
        XCTAssertFalse(tracker.latest.canSelectTargets)
        XCTAssertEqual(tracker.observe(sample(10.12))?.tracking, .normal)
    }

    func test_currentGeometryLossDoesNotKeepOldReadyCheckmarks() {
        var tracker = RealityScanTelemetryTracker()
        _ = tracker.observe(sample(10))
        let missingFloor = tracker.observe(sample(10.01, floors: 0))
        XCTAssertEqual(missingFloor?.floorAnchorCount, 0)
        XCTAssertFalse(tracker.latest.canSelectTargets)
        let missingMesh = tracker.observe(sample(10.02, meshes: 0, faces: 0))
        XCTAssertEqual(missingMesh?.meshAnchorCount, 0)
        XCTAssertFalse(tracker.latest.canSelectTargets)
    }

    func test_sessionResetAllowsNewTimestampEpochWithoutOldCounts() {
        var tracker = RealityScanTelemetryTracker()
        _ = tracker.observe(sample(100))
        tracker.reset()
        XCTAssertFalse(tracker.latest.canSelectTargets)
        XCTAssertEqual(tracker.observe(sample(1, meshes: 5))?.meshAnchorCount, 5)
    }

    private func sample(
        _ timestamp: Double,
        meshes: Int = 1,
        faces: Int = 20,
        floors: Int = 1,
        tracking: RealityTrackingStatus = .normal
    ) -> RealityScanTelemetry {
        RealityScanTelemetry(timestamp: timestamp, meshAnchorCount: meshes,
                             meshFaceCount: faces, floorAnchorCount: floors, tracking: tracking)
    }
}
