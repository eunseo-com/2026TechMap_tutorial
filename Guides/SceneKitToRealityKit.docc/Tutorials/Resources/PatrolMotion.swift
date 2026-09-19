import Foundation

enum PatrolMotion {
    static func step(position: Float, direction: Float, speed: Float, deltaTime: Double) -> (position: Float, direction: Float) {
        guard deltaTime.isFinite, deltaTime > 0, speed.isFinite, speed > 0 else {
            return (position, direction)
        }
        // -0.25m부터 +0.25m까지 왕복합니다. 긴 프레임도 경계를 넘지 않습니다.
        let limit = 0.25
        let x = Double(min(0.25, max(-0.25, position)))
        let phase = direction >= 0 ? x + limit : 3 * limit - x
        let next = (phase + Double(speed) * deltaTime).truncatingRemainder(dividingBy: 4 * limit)
        return next < 2 * limit
            ? (Float(next - limit), 1)
            : (Float(3 * limit - next), -1)
    }
}
