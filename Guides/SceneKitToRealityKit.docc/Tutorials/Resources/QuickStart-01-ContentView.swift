import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var world = LessonWorld(pigX: 0)

    var body: some View {
        ClosedWorldSceneView(scene: world.scene)
            .ignoresSafeArea()
    }
}
