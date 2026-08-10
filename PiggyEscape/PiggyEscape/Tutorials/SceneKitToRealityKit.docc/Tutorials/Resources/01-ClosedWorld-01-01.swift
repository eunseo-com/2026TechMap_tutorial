import SceneKit

/// 이 발췌본은 C3 섬의 이름 있는 나무와 바깥 돼지 컨테이너를 만든다.
/// 실제 앱에서는 같은 역할을 C3IslandBuilder와 C3PigModelFactory가 더 많은 타일·장식으로 확장한다.
@MainActor
final class C3ClosedWorldLesson {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let hideTree: SCNNode
    let pigContainer = SCNNode()

    init() {
        let island = loadC3Node(named: "Ground_Color")
        island.name = "C3Island"
        scene.rootNode.addChildNode(island)

        let tree = loadC3Node(named: "Cylinder_Tree1_Color")
        tree.name = "HideTree"
        tree.position = SCNVector3(0, 0, -1)
        hideTree = tree
        scene.rootNode.addChildNode(tree)

        pigContainer.name = "EscapePig"
        pigContainer.addChildNode(loadC3Node(named: "Piggy"))
        pigContainer.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(pigContainer)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 6
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
    }

    private func loadC3Node(named asset: String) -> SCNNode {
        let extensions = ["usdc", "usdz"]
        for fileExtension in extensions {
            if let scene = SCNScene(named: "\(asset).\(fileExtension)") {
                return scene.rootNode.clone()
            }
        }
        return SCNNode()
    }
}
