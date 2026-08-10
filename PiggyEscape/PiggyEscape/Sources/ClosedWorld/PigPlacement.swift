import SceneKit

/// 돼지를 하드코딩된 좌표에 배치한다. 이 좌표는 개발자가 정한 것일 뿐,
/// 방 안의 어떤 실제 기준(가구 위치 등)과도 연결되어 있지 않다.
enum PigPlacement {
    static let hardcodedPosition = SCNVector3(0, 0, 1)
    private static let standardHeight: Float = 0.6

    @MainActor
    static func makePigNode() -> SCNNode {
        let model = AssetLoader.object(named: "Piggy") {
            AssetLoader.voxelBox(width: 0.4, height: 0.4, length: 0.6, color: .systemPink)
        }
        SceneKitGeometry.normalize(model, toHeight: standardHeight)
        model.name = "Piggy"
        model.position = hardcodedPosition
        return model
    }
}
