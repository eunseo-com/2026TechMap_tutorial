import SwiftUI
import SceneKit

/// SwiftUI ↔ SceneKit(SCNView)을 잇는 다리. 방·돼지·가짜 소파를 씬에 담고,
/// 탭하면 돼지가 가짜 소파로 "숨는" 하나의 인터랙션만 처리한다.
struct ClosedWorldSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()

        scene.rootNode.addChildNode(RoomBuilder.build())
        let pig = PigPlacement.makePigNode()
        scene.rootNode.addChildNode(pig)
        scene.rootNode.addChildNode(FakeSofa.makeSofaNode())

        // 카메라는 방 안쪽(roomDepth/2 = 2보다 작은 z)에 둔다 — 방 밖에 두면
        // Wall_1(z=+2)에 가려 내부가 전혀 보이지 않는다.
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2, 1.7)
        cameraNode.look(at: SCNVector3(0, 0.3, -0.5))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = SCNVector3(0, 3, 2)
        scene.rootNode.addChildNode(light)

        view.scene = scene
        // pointOfView가 비어 있으면 SceneKit이 전체 씬을 자동으로 프레이밍하는
        // 기본 카메라를 대신 사용한다 — 위에서 공들여 배치한 cameraNode는
        // 렌더링에 전혀 쓰이지 않고 무시된다. 반드시 명시적으로 지정해야 한다.
        view.pointOfView = cameraNode
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true

        context.coordinator.pigNode = pig
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var pigNode: SCNNode?

        @objc func handleTap() {
            pigNode?.runAction(HideAction.makeMoveAction())
        }
    }
}
