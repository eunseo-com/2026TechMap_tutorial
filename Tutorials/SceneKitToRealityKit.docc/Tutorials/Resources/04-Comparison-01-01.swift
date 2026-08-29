import RealityKit

// Xcode에 포함한 Apple Pyro Panda RealityKit 샘플을 줄여 읽는 예시다.
public struct RunAwayComponent: Component, Codable {
    public var curve: Float = 0.4
    public var speed: Float = 1.0
    public var isRunning = false
}

final class RunAwaySystem: System {
    static let query = EntityQuery(where: .has(RunAwayComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let component = entity.components[RunAwayComponent.self],
                  component.isRunning else { continue }

            var position = entity.position
            position.z += component.speed * Float(context.deltaTime) * 0.5
            position.x = sin(component.curve * position.z)
            entity.position = position
        }
    }
}
