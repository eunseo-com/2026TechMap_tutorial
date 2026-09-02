import RealityKit
import UIKit
import simd

@MainActor
protocol AcceptedSurfaceMarking: AnyObject {
    func attach(to arView: ARView)
    func show(point: SIMD3<Float>, normal: SIMD3<Float>, animated: Bool)
    func cancel()
}

@MainActor
final class RealityAcceptedSurfaceMarker: AcceptedSurfaceMarking {
    private weak var arView: ARView?
    private var markerAnchor: AnchorEntity?
    private var removalTask: Task<Void, Never>?

    func attach(to arView: ARView) {
        self.arView = arView
    }

    func show(
        point: SIMD3<Float>,
        normal: SIMD3<Float>,
        animated: Bool
    ) {
        cancel()
        guard point.allFinite,
              normal.allFinite,
              simd_length_squared(normal) > 0.000_001,
              let arView else { return }

        let surfaceNormal = simd_normalize(normal)
        let anchor = AnchorEntity(world: point + surfaceNormal * 0.006)
        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.036),
            materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
        )
        marker.name = "AcceptedRealitySurfaceMarker"
        marker.scale = SIMD3(1, 0.08, 1)
        marker.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: surfaceNormal
        )
        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
        markerAnchor = anchor

        if animated {
            let pulse = Transform(
                scale: SIMD3(1.28, 0.08, 1.28),
                rotation: marker.orientation,
                translation: marker.position
            )
            marker.move(
                to: pulse,
                relativeTo: marker.parent,
                duration: 0.24,
                timingFunction: .easeOut
            )
        }

        removalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            self?.cancel()
        }
    }

    func cancel() {
        removalTask?.cancel()
        removalTask = nil
        markerAnchor?.removeFromParent()
        markerAnchor = nil
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
