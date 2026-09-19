import SwiftUI

@MainActor
struct ContentView: View {
    // 화면을 다시 그려도 같은 세계를 유지합니다.
    @State private var world = ClosedWorld()

    var body: some View {
        ClosedWorldSceneView(scene: world.scene)
            .ignoresSafeArea()
    }
}
