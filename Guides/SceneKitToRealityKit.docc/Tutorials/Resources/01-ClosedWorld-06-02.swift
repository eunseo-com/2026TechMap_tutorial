import SceneKit

@MainActor
enum HideAction {
    static func makeMoveAction(groundedY: Float) -> SCNAction {
        // 바닥에 맞춘 높이는 유지하고, 소파보다 뒤쪽으로 이동합니다.
        let destination = SCNVector3(
            FakeSofa.hardcodedPosition.x,
            groundedY,
            FakeSofa.hardcodedPosition.z - 0.9
        )
        return .move(to: destination, duration: 0.8)
    }
}
