import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Entity · Component · System").font(.headline).padding()
            ECSLessonView { pig in
                pig.components.remove(PatrolComponent.self)
            }
        }
    }
}
