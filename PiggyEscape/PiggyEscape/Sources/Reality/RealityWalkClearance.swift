import ARKit
import RealityKit
import simd

/// Tests a conservative body volume against measured scene-understanding geometry.
/// Unknown/unscanned geometry is not a guarantee of free real-world space.
@MainActor
final class RealityWalkClearance {
    private weak var arView: ARView?
    private var cachedRadius: Float?
    private var cachedShape: ShapeResource?

    init(arView: ARView) { self.arView = arView }

    func isClear(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float = RealityWalkRoutePlanner.footprintRadius) -> Bool {
        guard radius.isFinite, radius > 0, radius < 1,
              start.allFinite, end.allFinite,
              let arView, let frame = arView.session.currentFrame,
              case .normal = frame.camera.trackingState,
              frame.anchors.contains(where: { $0 is ARMeshAnchor }) else { return false }
        if cachedRadius != radius {
            cachedRadius = radius
            cachedShape = .generateBox(size: [radius * 2, PigScalePolicy.targetHeight, radius * 2])
        }
        guard let shape = cachedShape else { return false }
        // Lift the cast above floor mesh noise. This checks body clearance, not
        // a physics simulation of individual feet or a human navigation route.
        let centerOffset = SIMD3<Float>(0, PigScalePolicy.targetHeight / 2 + 0.025, 0)
        let orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        return arView.scene.convexCast(
            convexShape: shape, fromPosition: start + centerOffset, fromOrientation: orientation,
            toPosition: end + centerOffset, toOrientation: orientation,
            query: .nearest, mask: .sceneUnderstanding, relativeTo: nil
        ).isEmpty
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}
