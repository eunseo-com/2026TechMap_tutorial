import RealityKit
import UIKit

@MainActor
enum TutorialPig {
    static func make() -> Entity {
        let pig = Entity()
        pig.name = "Pig"
        if let url = Bundle.main.url(forResource: "Piggy", withExtension: "usdc"),
           let model = try? Entity.load(contentsOf: url) {
            // 원본 모델의 Z-up을 Y-up에 맞춘 뒤 실제 공간에서 18cm 크기로 맞춥니다.
            model.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                * simd_quatf(angle: .pi, axis: [0, 0, 1])
            pig.addChild(model)
            let bounds = pig.visualBounds(relativeTo: pig)
            let size = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            if size.isFinite && size > 0 {
                let scale: Float = 0.18 / size
                model.scale *= scale
                model.position -= [bounds.center.x * scale, bounds.min.y * scale, bounds.center.z * scale]
                return pig
            }
            model.removeFromParent()
        }
        pig.name = "Pig (모델 대신 분홍 상자)"
        let box = ModelEntity(mesh: .generateBox(size: 0.15), materials: [SimpleMaterial(color: .systemPink, isMetallic: false)])
        box.position.y = 0.075
        pig.addChild(box)
        return pig
    }
}
