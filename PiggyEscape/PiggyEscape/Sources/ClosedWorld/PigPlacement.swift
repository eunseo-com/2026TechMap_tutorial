import SceneKit

/// 돼지를 하드코딩된 좌표에 배치한다. 이 좌표는 개발자가 정한 것일 뿐,
/// 방 안의 어떤 실제 기준(가구 위치 등)과도 연결되어 있지 않다.
enum PigPlacement {
    static let hardcodedPosition = SCNVector3(0, 0, 0)
    private static let standardHeight: Float = 0.6

    @MainActor
    static func makePigNode() -> SCNNode {
        let pig = SCNNode()
        let model = SCNNode()
        let art: SCNNode

        if let bundledModel = AssetLoader.object(named: "Piggy") {
            // Piggy.usdc는 Blender의 Z-up 좌표계로 만든 모델이다. SceneKit의 y-up 세계에
            // 세워 주고, 화면을 향하도록 roll을 보정한다.
            bundledModel.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi)
            art = bundledModel
        } else {
            art = AssetLoader.voxelBox(width: 0.4, height: 0.4, length: 0.6, color: .systemPink)
        }
        model.addChildNode(art)

        // 바깥 `pig`은 위치와 행동을 맡고, 안쪽 `model`은 에셋의 회전·크기·바닥 정렬만
        // 맡는다. 그래서 나중에 이동 액션을 실행해도 모델 보정값이 섞이지 않는다.
        SceneKitGeometry.normalize(model, toHeight: standardHeight)
        pig.addChildNode(model)

        let (lo, hi) = SceneKitGeometry.boundingBox(of: pig)
        model.position = SCNVector3(
            -(lo.x + hi.x) / 2,
            -lo.y,
            -(lo.z + hi.z) / 2
        )
        pig.name = "Piggy"
        pig.position = hardcodedPosition
        return pig
    }
}
