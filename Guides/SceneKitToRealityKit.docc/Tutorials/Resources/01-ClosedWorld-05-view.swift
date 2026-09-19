import SceneKit
import SwiftUI

@MainActor
struct ClosedWorldSceneView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        // 모델 파일에 들어 있는 카메라 대신 실습용 카메라를 선택합니다.
        view.pointOfView = scene.rootNode.childNode(withName: "Camera", recursively: false)
        view.backgroundColor = .black
        view.allowsCameraControl = false
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.hidePig)
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene)
    }

    @MainActor
    final class Coordinator: NSObject {
        private let scene: SCNScene

        init(scene: SCNScene) {
            self.scene = scene
        }

        @objc func hidePig() {
            guard let pig = scene.rootNode.childNode(withName: "Piggy", recursively: true) else { return }
            // 연속으로 눌러도 이전 이동을 같은 키로 교체합니다.
            pig.runAction(HideAction.makeMoveAction(groundedY: pig.position.y), forKey: "hide")
            print(NodeInspector.describe(pig).joined(separator: "\n"))
        }
    }
}
