import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    var body: some View {
        SpatialLessonView(configuration: configuration)
    }

    private var configuration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        return configuration
    }
}
