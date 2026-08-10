import RealityKit
import XCTest
@testable import PiggyEscape

@MainActor
final class RealityPigVisualControllerTests: XCTestCase {
    func test_surpriseVisualUsesStableOuterEntityAndSceneKitScaleContract() {
        let controller = RealityPigVisualController.makeForTesting()
        let outerEntity = controller.outerEntity

        controller.showSurprised()
        controller.playSurpriseScale()

        XCTAssertTrue(controller.outerEntity === outerEntity)
        XCTAssertEqual(controller.outerEntity.name, "RealityEscapePig")
        XCTAssertEqual(controller.currentPose, .surprised)
        XCTAssertEqual(controller.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(controller.surpriseRestoreScale, 1.0, accuracy: 0.0001)
    }

    func test_testingWalkMovesStableOuterEntityAndFinishesIdle() {
        let controller = RealityPigVisualController.makeForTesting()
        let outerEntity = controller.outerEntity
        let destination = SIMD3<Float>(0.7, 0.2, -1.4)
        var completed = false

        controller.walk(to: destination) {
            completed = true
        }

        XCTAssertTrue(controller.outerEntity === outerEntity)
        XCTAssertEqual(controller.worldPosition.x, destination.x, accuracy: 0.0001)
        XCTAssertEqual(controller.worldPosition.y, destination.y, accuracy: 0.0001)
        XCTAssertEqual(controller.worldPosition.z, destination.z, accuracy: 0.0001)
        XCTAssertEqual(controller.currentPose, .idle)
        XCTAssertTrue(completed)
    }
}
