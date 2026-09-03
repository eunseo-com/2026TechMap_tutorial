import SceneKit
import XCTest
@testable import PiggyEscape

@MainActor
final class C3ClosedWorldTests: XCTestCase {
    func test_worldUsesOrthographicC3OrbitCamera() {
        let world = C3ClosedWorld()

        XCTAssertTrue(world.cameraNode.camera?.usesOrthographicProjection ?? false)
        XCTAssertEqual(world.cameraNode.camera?.orthographicScale ?? 0, 6.0, accuracy: 0.001)
    }

    func test_worldPlacesPigAtTheIslandSpawnAndExposesTheSameHideTree() {
        let world = C3ClosedWorld()
        let island = world.scene.rootNode.childNode(withName: "C3Island", recursively: false)
        let spawn = island?.childNode(withName: "BigPigSpawn", recursively: false)

        XCTAssertNotNil(spawn)
        XCTAssertTrue(world.hideTree === island?.childNode(withName: "HideTree", recursively: true))
        XCTAssertEqual(world.pigContainer.position.x, spawn?.position.x ?? 0, accuracy: 0.0001)
        XCTAssertEqual(world.pigContainer.position.y, spawn?.position.y ?? 0, accuracy: 0.0001)
        XCTAssertEqual(world.pigContainer.position.z, spawn?.position.z ?? 0, accuracy: 0.0001)
    }

    func test_worldRotatesAndClampsC3OrbitZoom() {
        let world = C3ClosedWorld()

        world.rotateCamera(byYaw: .pi / 4)
        XCTAssertEqual(world.cameraYaw, .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(world.cameraNode.position.x, 17, accuracy: 0.0001)
        XCTAssertEqual(world.cameraNode.position.y, 12, accuracy: 0.0001)
        XCTAssertEqual(world.cameraNode.position.z, 0, accuracy: 0.0001)

        world.zoom(by: 100)
        XCTAssertEqual(world.cameraNode.camera?.orthographicScale ?? 0, 3, accuracy: 0.0001)
        world.zoom(by: 0.01)
        XCTAssertEqual(world.cameraNode.camera?.orthographicScale ?? 0, 12, accuracy: 0.0001)
    }
}
