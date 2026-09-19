import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    @State private var occlusionEnabled = true

    var body: some View {
        SpatialLessonView(configuration: configuration, enableOcclusion: occlusionEnabled) { anchor in
            anchor.addChild(TutorialPig.make())
        }
        .safeAreaInset(edge: .top) {
            Toggle("실제 물체에 가려지기", isOn: $occlusionEnabled)
                .padding().background(.regularMaterial)
        }
    }

    private var configuration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        return configuration
    }
}
