import SceneKit
import SwiftUI

// SwiftUI 안에 SceneKit 화면을 놓는 연결부입니다.
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
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
