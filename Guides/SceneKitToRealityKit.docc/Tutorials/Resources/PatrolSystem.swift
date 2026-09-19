import RealityKit

// Component는 데이터입니다. 이 값만으로 움직이지는 않습니다.
struct PatrolComponent: Component {
    var speed: Float
    var direction: Float = 1
}

// System은 해당 Component를 가진 Entity를 매 프레임 갱신합니다.
struct PatrolSystem: System {
    static let query = EntityQuery(where: .has(PatrolComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard var patrol = entity.components[PatrolComponent.self] else { continue }
            let next = PatrolMotion.step(
                position: entity.position.x,
                direction: patrol.direction,
                speed: patrol.speed,
                deltaTime: context.deltaTime
            )
            entity.position.x = next.position
            patrol.direction = next.direction
            entity.components.set(patrol)
        }
    }
}
