import XCTest
@testable import PiggyEscape

final class RealityEnvironmentReadinessTests: XCTestCase {
    func test_progressSnapshotChangesIndependentlyAndDuplicateInputProducesNoUpdate() {
        var readiness = RealityEnvironmentReadiness()

        XCTAssertEqual(readiness.progress, RealityScanProgress(
            hasMesh: false,
            hasClassifiedFloor: false
        ))
        XCTAssertEqual(
            readiness.observe(hasMesh: true, hasClassifiedFloor: false),
            RealityScanUpdate(
                progress: RealityScanProgress(hasMesh: true, hasClassifiedFloor: false),
                becameReady: false
            )
        )
        XCTAssertNil(readiness.observe(hasMesh: true, hasClassifiedFloor: false))
        XCTAssertEqual(
            readiness.observe(hasMesh: true, hasClassifiedFloor: true),
            RealityScanUpdate(
                progress: RealityScanProgress(hasMesh: true, hasClassifiedFloor: true),
                becameReady: true
            )
        )
        XCTAssertNil(readiness.observe(hasMesh: true, hasClassifiedFloor: true))
    }

    func test_scanPresentationUsesRealMeshOnlyInChapterTwoAndStaticFeedbackForReduceMotion() {
        XCTAssertTrue(RealityScanPresentation(
            showsSceneUnderstanding: true,
            reduceMotion: false
        ).showsAnimatedSweep)
        XCTAssertFalse(RealityScanPresentation(
            showsSceneUnderstanding: true,
            reduceMotion: true
        ).showsAnimatedSweep)
        XCTAssertFalse(RealityScanPresentation(
            showsSceneUnderstanding: false,
            reduceMotion: false
        ).showsAnimatedSweep)
    }

    func test_meshAloneDoesNotMakeTheEnvironmentReady() {
        var readiness = RealityEnvironmentReadiness()

        XCTAssertFalse(readiness.observeMesh())
        XCTAssertFalse(readiness.isReady)
    }

    func test_classifiedFloorAloneDoesNotMakeTheEnvironmentReady() {
        var readiness = RealityEnvironmentReadiness()

        XCTAssertFalse(readiness.observeClassifiedFloor())
        XCTAssertFalse(readiness.isReady)
    }

    func test_eitherObservationOrderReportsTheFirstCompleteEnvironmentOnce() {
        var meshThenFloor = RealityEnvironmentReadiness()
        XCTAssertFalse(meshThenFloor.observeMesh())
        XCTAssertTrue(meshThenFloor.observeClassifiedFloor())
        XCTAssertFalse(meshThenFloor.observeMesh())
        XCTAssertFalse(meshThenFloor.observeClassifiedFloor())
        XCTAssertTrue(meshThenFloor.isReady)

        var floorThenMesh = RealityEnvironmentReadiness()
        XCTAssertFalse(floorThenMesh.observeClassifiedFloor())
        XCTAssertTrue(floorThenMesh.observeMesh())
        XCTAssertFalse(floorThenMesh.observeMesh())
        XCTAssertTrue(floorThenMesh.isReady)
    }
}
