import RealityKit
import XCTest
@testable import PiggyEscape

@MainActor
final class RealityPigVisualControllerTests: XCTestCase {
    func test_eachPoseKeepsItsOwnEighteenCentimeterBaseline() {
        typealias PendingLoad = (asset: String, completion: (Result<Entity, Error>) -> Void)
        var pendingLoads: [PendingLoad] = []
        let controller = RealityPigVisualController.makeForTesting { asset, completion in
            pendingLoads.append((asset, completion))
            return nil
        }

        controller.loadIdlePig()
        completePoseLoad(pendingLoads.removeFirst())
        assertInstalledHeight(controller, pose: .idle)

        controller.walk(to: SIMD3(0, 0, -1)) { _ in }
        completePoseLoad(pendingLoads.removeFirst())
        assertInstalledHeight(controller, pose: .running)
        completePoseLoad(pendingLoads.removeFirst())
        assertInstalledHeight(controller, pose: .idle)

        controller.showSurprised()
        completePoseLoad(pendingLoads.removeFirst())
        assertInstalledHeight(controller, pose: .surprised)
        controller.playSurpriseScale()

        XCTAssertEqual(controller.surprisePeakScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(controller.surpriseRestoreScale, 1.0, accuracy: 0.0001)
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

        finishLoading?(.success(ModelEntity(mesh: .generateBox(size: 0.3))))

        XCTAssertTrue(completed)
        XCTAssertNotNil(controller.outerEntity.findEntity(named: "RealityPigModel_surprised"))
    }

    func test_emptyVisualBoundsFailThePoseInstallWithoutChangingTheCurrentPose() {
        let controller = RealityPigVisualController.makeForTesting { _, completion in
            completion(.success(Entity()))
            return nil
        }
        var result: RealityPigVisualController.PoseResult?

        controller.loadIdlePig { result = $0 }

        guard case let .failure(error)? = result else {
            return XCTFail("expected invalid bounds failure")
        }
        XCTAssertEqual(error, .invalidVisualBounds(.idle))
        XCTAssertEqual(controller.currentPose, .idle)
        XCTAssertNil(controller.outerEntity.findEntity(named: "RealityPigModel_idle"))
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

private func completePoseLoad(
    _ load: (asset: String, completion: (Result<Entity, Error>) -> Void)
) {
    let sourceDepth: Float
    switch load.asset {
    case "Piggy": sourceDepth = 0.45
    case "Piggy_running": sourceDepth = 0.90
    default: sourceDepth = 0.30
    }
    load.completion(.success(ModelEntity(
        mesh: .generateBox(width: 0.2, height: 0.25, depth: sourceDepth)
    )))
}

@MainActor
private func assertInstalledHeight(
    _ controller: RealityPigVisualController,
    pose: C3PigPose,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let model = controller.outerEntity.findEntity(named: "RealityPigModel_\(pose.rawValue)") else {
        return XCTFail("expected installed pose", file: file, line: line)
    }
    let bounds = model.visualBounds(recursive: true, relativeTo: controller.outerEntity)
    XCTAssertEqual(bounds.extents.y, PigScalePolicy.targetHeight, accuracy: 0.001, file: file, line: line)
}
