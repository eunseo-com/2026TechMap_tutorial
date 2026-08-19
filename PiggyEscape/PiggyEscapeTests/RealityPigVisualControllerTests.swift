import RealityKit
import XCTest
@testable import PiggyEscape

@MainActor
final class RealityPigVisualControllerTests: XCTestCase {
    func test_realityPigUsesTabletopScaleForPhysicalWorldHiding() {
        XCTAssertEqual(RealityPigVisualController.targetHeightInMeters, 0.35, accuracy: 0.0001)
    }

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

    func test_surpriseCompletionWaitsUntilTheSurprisedModelIsInstalled() {
        var requestedAsset: String?
        var finishLoading: ((Result<Entity, Error>) -> Void)?
        let controller = RealityPigVisualController.makeForTesting { asset, completion in
            requestedAsset = asset
            finishLoading = completion
            return nil
        }
        var completed = false

        controller.showSurprised { result in
            if case .success = result {
                completed = true
            }
        }

        XCTAssertEqual(requestedAsset, "Piggy_surprised")
        XCTAssertFalse(completed)
        XCTAssertNil(controller.outerEntity.findEntity(named: "RealityPigModel_surprised"))

        finishLoading?(.success(Entity()))

        XCTAssertTrue(completed)
        XCTAssertNotNil(controller.outerEntity.findEntity(named: "RealityPigModel_surprised"))
    }

    func test_testingWalkMovesStableOuterEntityAndFinishesIdle() {
        let controller = RealityPigVisualController.makeForTesting()
        let outerEntity = controller.outerEntity
        let destination = SIMD3<Float>(0.7, 0.2, -1.4)
        var completed = false

        controller.walk(to: destination) { result in
            if case .success = result {
                completed = true
            }
        }

        XCTAssertTrue(controller.outerEntity === outerEntity)
        XCTAssertEqual(controller.worldPosition.x, destination.x, accuracy: 0.0001)
        XCTAssertEqual(controller.worldPosition.y, destination.y, accuracy: 0.0001)
        XCTAssertEqual(controller.worldPosition.z, destination.z, accuracy: 0.0001)
        XCTAssertEqual(controller.currentPose, .idle)
        XCTAssertTrue(completed)
    }

    func test_idlePigDoesNotGenerateCollisionShapesBecauseRealWorldMeshHandlesTaps() {
        let model = ModelEntity(mesh: .generateBox(size: 1))
        let controller = RealityPigVisualController.makeForTesting { _, completion in
            completion(.success(model))
            return nil
        }

        controller.loadIdlePig()

        XCTAssertNil(model.components[CollisionComponent.self])
    }
}
