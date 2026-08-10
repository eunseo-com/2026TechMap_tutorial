import ARKit
import RealityKit

@MainActor
func startClassifiedMeshSession(in arView: ARView) -> Bool {
    guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
        return false
    }

    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    configuration.sceneReconstruction = .meshWithClassification

    arView.environment.sceneUnderstanding.options = [
        .occlusion,
        .collision,
        .physics,
        .receivesLighting
    ]
    arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    return true
}
