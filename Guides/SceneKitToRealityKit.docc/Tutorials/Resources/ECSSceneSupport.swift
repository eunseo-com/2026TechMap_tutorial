import SwiftUI
import RealityKit
import UIKit

@MainActor
struct ECSLessonView: UIViewRepresentable {
    let configure: (Entity) -> Void

    // 타입 등록은 앱 실행 중 한 번만 합니다.
    private static let registration: Void = {
        PatrolComponent.registerComponent()
        PatrolSystem.registerSystem()
    }()

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        _ = Self.registration
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.93, green: 0.96, blue: 1, alpha: 1))
        let anchor = AnchorEntity(world: .zero)
        let pig = TutorialPig.make()
        configure(pig)
        anchor.addChild(pig)
        context.coordinator.pig = pig

        let floor = ModelEntity(mesh: .generateBox(width: 0.9, height: 0.015, depth: 0.5), materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)])
        floor.position.y = -0.008
        anchor.addChild(floor)
        let camera = PerspectiveCamera()
        camera.look(at: [0, 0.06, 0], from: [0, 0.55, 0.95], relativeTo: nil)
        anchor.addChild(camera)
        let light = DirectionalLight()
        light.light.intensity = 2000
        light.look(at: .zero, from: [1, 2, 1], relativeTo: nil)
        anchor.addChild(light)
        view.scene.addAnchor(anchor)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        if let pig = context.coordinator.pig { configure(pig) }
    }

    final class Coordinator {
        var pig: Entity?
    }
}
