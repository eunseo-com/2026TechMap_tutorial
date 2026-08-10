import Combine
import Foundation
import RealityKit
import simd

@MainActor
final class RealityPigVisualController {
    let outerEntity: Entity

    private(set) var currentPose: C3PigPose = .idle
    private(set) var surprisePeakScale: Float = 1
    private(set) var surpriseRestoreScale: Float = 1

    var worldPosition: SIMD3<Float> {
        outerEntity.position(relativeTo: nil)
    }

    private let skipsAssetLoadingAndTiming: Bool
    private var modelLoad: AnyCancellable?
    private var movementCompletion: DispatchWorkItem?

    init() {
        outerEntity = Entity()
        outerEntity.name = "RealityEscapePig"
        outerEntity.orientation = simd_quatf(angle: 3 * .pi / 4, axis: SIMD3(0, 1, 0))
        skipsAssetLoadingAndTiming = false
    }

    private init(testing: Bool) {
        outerEntity = Entity()
        outerEntity.name = "RealityEscapePig"
        outerEntity.orientation = simd_quatf(angle: 3 * .pi / 4, axis: SIMD3(0, 1, 0))
        skipsAssetLoadingAndTiming = testing
    }

    static func makeForTesting() -> RealityPigVisualController {
        RealityPigVisualController(testing: true)
    }

    func loadIdlePig() {
        setPose(.idle)
    }

    func walk(to destination: SIMD3<Float>, completion: @escaping () -> Void) {
        movementCompletion?.cancel()
        setPose(.running) { [weak self] in
            guard let self else { return }
            if self.skipsAssetLoadingAndTiming {
                self.outerEntity.setPosition(destination, relativeTo: nil)
                self.setPose(.idle, completion: completion)
                return
            }

            let distance = simd_distance(self.worldPosition, destination)
            let duration = TimeInterval(min(max(distance / 0.65, 0.5), 3.0))
            let target = Transform(
                scale: self.outerEntity.scale,
                rotation: self.outerEntity.orientation,
                translation: destination
            )
            self.outerEntity.move(
                to: target,
                relativeTo: self.outerEntity.parent,
                duration: duration,
                timingFunction: .easeInOut
            )

            let work = DispatchWorkItem { [weak self] in
                self?.setPose(.idle, completion: completion)
            }
            self.movementCompletion = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }

    func showSurprised() {
        movementCompletion?.cancel()
        setPose(.surprised)
    }

    func playSurpriseScale() {
        surprisePeakScale = 1.5
        surpriseRestoreScale = 1.0

        let peak = Transform(
            scale: SIMD3(repeating: surprisePeakScale),
            rotation: outerEntity.orientation,
            translation: outerEntity.position
        )
        outerEntity.move(
            to: peak,
            relativeTo: outerEntity.parent,
            duration: 0.16,
            timingFunction: .easeOut
        )

        guard !skipsAssetLoadingAndTiming else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self else { return }
            let restored = Transform(
                scale: SIMD3(repeating: self.surpriseRestoreScale),
                rotation: self.outerEntity.orientation,
                translation: self.outerEntity.position
            )
            self.outerEntity.move(
                to: restored,
                relativeTo: self.outerEntity.parent,
                duration: 0.34,
                timingFunction: .easeInOut
            )
        }
    }

    private func setPose(_ pose: C3PigPose, completion: (() -> Void)? = nil) {
        currentPose = pose
        guard !skipsAssetLoadingAndTiming else {
            completion?()
            return
        }

        modelLoad?.cancel()
        modelLoad = Entity.loadAsync(named: assetName(for: pose), in: .main)
            .sink(
                receiveCompletion: { result in
                    if case .failure = result {
                        completion?()
                    }
                },
                receiveValue: { [weak self] entity in
                    guard let self, self.currentPose == pose else { return }
                    self.install(entity, for: pose)
                    completion?()
                }
            )
    }

    private func assetName(for pose: C3PigPose) -> String {
        pose == .idle ? "Piggy" : "Piggy_\(pose.rawValue)"
    }

    private func install(_ model: Entity, for pose: C3PigPose) {
        outerEntity.children
            .filter { $0.name.hasPrefix("RealityPigModel_") }
            .forEach { $0.removeFromParent() }

        model.name = "RealityPigModel_\(pose.rawValue)"
        let xCorrection = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        let zCorrection = simd_quatf(angle: .pi, axis: SIMD3(0, 0, 1))
        model.orientation = zCorrection * xCorrection
        outerEntity.addChild(model)

        let unscaledBounds = model.visualBounds(recursive: true, relativeTo: outerEntity)
        let height = unscaledBounds.extents.y
        if height.isFinite, height > 0.0001 {
            model.scale *= SIMD3(repeating: 1.5 / height)
            let bounds = model.visualBounds(recursive: true, relativeTo: outerEntity)
            model.position += SIMD3(-bounds.center.x, -bounds.min.y, -bounds.center.z)
        }

        model.generateCollisionShapes(recursive: true)
        if pose == .running {
            playAnimations(in: model)
        }
    }

    private func playAnimations(in entity: Entity) {
        entity.availableAnimations.forEach {
            entity.playAnimation($0.repeat())
        }
        entity.children.forEach(playAnimations(in:))
    }
}
