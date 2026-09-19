import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    var body: some View {
        SpatialLessonView(configuration: configuration, enableOcclusion: false) { anchor in
            anchor.addChild(TutorialPig.make())
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
