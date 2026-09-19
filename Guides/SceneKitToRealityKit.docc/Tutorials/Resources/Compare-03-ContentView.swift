import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var isMoving = true

    var body: some View {
        VStack(spacing: 0) {
            Text("Entity · Component · System").font(.headline).padding()
            Toggle("움직이기", isOn: $isMoving)
                .padding()
            ECSLessonView { pig in
                var patrol = pig.components[PatrolComponent.self] ?? PatrolComponent(speed: 0)
                patrol.speed = isMoving ? 0.25 : 0
                pig.components.set(patrol)
            }
        }
    }
}
