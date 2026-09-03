import Combine
import Foundation
import RealityKit
import simd

enum RealityPigVisualError: Error, Equatable {
    case assetLoadFailed(C3PigPose)
    case invalidVisualBounds(C3PigPose)
}

@MainActor
final class RealityPigVisualController {
    typealias EntityLoader = @MainActor (String, @escaping (Result<Entity, Error>) -> Void) -> AnyCancellable?
    typealias PoseResult = Result<Void, RealityPigVisualError>

    let outerEntity: Entity

    private(set) var currentPose: C3PigPose = .idle
    private(set) var surprisePeakScale: Float = 1
    private(set) var surpriseRestoreScale: Float = 1

    var worldPosition: SIMD3<Float> {
        outerEntity.position(relativeTo: nil)
    }

    private let skipsAssetLoadingAndTiming: Bool
    private let entityLoader: EntityLoader
    private var modelLoad: AnyCancellable?
    private var movementCompletion: DispatchWorkItem?
    private var surpriseRestoreCompletion: DispatchWorkItem?
    private var requestedPose: C3PigPose?

    init() {
        outerEntity = Entity()
        outerEntity.name = "RealityEscapePig"
        outerEntity.orientation = simd_quatf(angle: 3 * .pi / 4, axis: SIMD3(0, 1, 0))
        outerEntity.isEnabled = false
        skipsAssetLoadingAndTiming = false
        entityLoader = Self.loadEntity
    }

    private init(testing: Bool, entityLoader: @escaping EntityLoader) {
        outerEntity = Entity()
        outerEntity.name = "RealityEscapePig"
        outerEntity.orientation = simd_quatf(angle: 3 * .pi / 4, axis: SIMD3(0, 1, 0))
        outerEntity.isEnabled = false
        skipsAssetLoadingAndTiming = testing
        self.entityLoader = entityLoader
    }

    static func makeForTesting(
        entityLoader: @escaping EntityLoader = { _, completion in
            completion(.success(ModelEntity(mesh: .generateBox(size: 0.3))))
            return nil
        }
    ) -> RealityPigVisualController {
        RealityPigVisualController(testing: true, entityLoader: entityLoader)
    }

    func loadIdlePig(completion: @escaping (PoseResult) -> Void = { _ in }) {
        setPose(.idle, completion: completion)
    }

    func walk(to destination: SIMD3<Float>, completion: @escaping (PoseResult) -> Void) {
        movementCompletion?.cancel()
        face(toward: destination)
        setPose(.running) { [weak self] result in
            guard let self else { return }
            guard case .success = result else {
                completion(result)
                return
            }
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

    func showSurprised(completion: @escaping (PoseResult) -> Void = { _ in }) {
        movementCompletion?.cancel()
        movementCompletion = nil
        setPose(.surprised, completion: completion)
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
        surpriseRestoreCompletion?.cancel()
        let restore = DispatchWorkItem { [weak self] in
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
        surpriseRestoreCompletion = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: restore)
    }

    func cancelPendingWork() {
        modelLoad?.cancel()
        modelLoad = nil
        requestedPose = nil
        movementCompletion?.cancel()
        movementCompletion = nil
        surpriseRestoreCompletion?.cancel()
        surpriseRestoreCompletion = nil
    }

    private func face(toward destination: SIMD3<Float>) {
        let delta = destination - worldPosition
        guard delta.allFinite,
              abs(delta.x) > 0.0001 || abs(delta.z) > 0.0001 else { return }
        outerEntity.orientation = simd_quatf(
            angle: atan2(delta.x, delta.z),
            axis: SIMD3(0, 1, 0)
        )
    }

    private func setPose(_ pose: C3PigPose, completion: @escaping (PoseResult) -> Void) {
        requestedPose = pose
        modelLoad?.cancel()
        modelLoad = entityLoader(assetName(for: pose)) { [weak self] result in
            guard let self, self.requestedPose == pose else { return }
            self.requestedPose = nil
            switch result {
            case let .success(entity):
                do {
                    try self.install(entity, for: pose)
                    self.currentPose = pose
                    completion(.success(()))
                } catch {
                    completion(.failure(.invalidVisualBounds(pose)))
                }
            case .failure:
                completion(.failure(.assetLoadFailed(pose)))
            }
        }
    }

    private func assetName(for pose: C3PigPose) -> String {
        pose == .idle ? "Piggy" : "Piggy_\(pose.rawValue)"
    }

    private func install(_ model: Entity, for pose: C3PigPose) throws {
        model.name = "RealityPigModel_\(pose.rawValue)"
        let xCorrection = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        let zCorrection = simd_quatf(angle: .pi, axis: SIMD3(0, 0, 1))
        model.orientation = zCorrection * xCorrection
        outerEntity.addChild(model)

        do {
            let correctedBounds = model.visualBounds(recursive: true, relativeTo: outerEntity)
            _ = try PigScalePolicy.uniformScale(
                visualBoundsMin: correctedBounds.min,
                visualBoundsMax: correctedBounds.max
            )
            model.position += SIMD3(
                -correctedBounds.center.x,
                -correctedBounds.min.y,
                -correctedBounds.center.z
            )

            let alignedBounds = model.visualBounds(recursive: true, relativeTo: outerEntity)
            let baselineScale = try PigScalePolicy.uniformScale(
                visualBoundsMin: alignedBounds.min,
                visualBoundsMax: alignedBounds.max
            )
            model.scale *= SIMD3(repeating: baselineScale)

            let normalizedBounds = model.visualBounds(recursive: true, relativeTo: outerEntity)
            try PigScalePolicy.validateNormalizedBounds(
                visualBoundsMin: normalizedBounds.min,
                visualBoundsMax: normalizedBounds.max
            )
            model.position += SIMD3(
                -normalizedBounds.center.x,
                -normalizedBounds.min.y,
                -normalizedBounds.center.z
            )
        } catch {
            model.removeFromParent()
            throw error
        }

        outerEntity.children
            .filter { $0 !== model && $0.name.hasPrefix("RealityPigModel_") }
            .forEach { $0.removeFromParent() }
        outerEntity.scale = .one

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

    private static func loadEntity(
        named assetName: String,
        completion: @escaping (Result<Entity, Error>) -> Void
    ) -> AnyCancellable? {
        Entity.loadAsync(named: assetName, in: .main)
            .sink(
                receiveCompletion: { result in
                    if case let .failure(error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { completion(.success($0)) }
            )
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
