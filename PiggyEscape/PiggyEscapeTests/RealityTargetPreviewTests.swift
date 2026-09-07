import XCTest
import simd
#if !REALITY_POLICY_HOST_TESTS
@testable import PiggyEscape
#endif

final class RealityTargetPreviewTests: XCTestCase {
    func test_noMeshHitDoesNotAdvertiseASelectableObject() {
        XCTAssertEqual(preview(hit: nil), .noSurface)
    }

    func test_trackingLossOverridesEvenAnOtherwiseValidSurface() {
        XCTAssertEqual(preview(tracking: .excessiveMotion), .tracking(.excessiveMotion))
    }

    func test_previewUsesTheSameDistanceFloorAndNormalRejectionsAsTheTapPlanner() {
        XCTAssertEqual(preview(hit: .init(point: [0, 0.4, 0.5], normal: [0, 0, 1])),
                       .rejected(.moveFartherAway))
        XCTAssertEqual(preview(floor: nil), .rejected(.findFloor))
        XCTAssertEqual(preview(hit: .init(point: [0, 0, 0], normal: [0, 1, 0])),
                       .rejected(.selectVerticalSide))
    }

    func test_validPreviewReportsMeasuredDistanceWithoutInventingAnObjectLabel() {
        guard case let .ready(distance) = preview() else { return XCTFail("Expected a valid side") }
        XCTAssertEqual(distance, sqrt(1.16), accuracy: 0.0001)
        XCTAssertTrue(preview().isSelectable)
        XCTAssertFalse(preview(floor: nil).isSelectable)
    }

    private func preview(
        hit: RealitySurfaceHit? = .init(point: [0, 0.4, 0], normal: [0, 0, 1]),
        floor: RealityFloorRegion? = RealityFloorRegion(
            anchorIdentifier: UUID(), transform: matrix_identity_float4x4,
            center: .zero, extent: [4, 4]
        ),
        tracking: RealityTrackingStatus = .normal
    ) -> RealityTargetPreview {
        RealityTargetPreview.evaluate(hit: hit, cameraPosition: [0, 0, 1],
                                      floorRegion: floor, tracking: tracking)
    }
}
