import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var world = LessonWorld(pigX: -1.5)

    var body: some View {
        ClosedWorldSceneView(scene: world.scene)
            .ignoresSafeArea()
            .onTapGesture {
                let target = SCNVector3(1.5, world.pigNode.position.y, -2.9)
                world.pigNode.runAction(.move(to: target, duration: 0.8))
            }
    }
}
