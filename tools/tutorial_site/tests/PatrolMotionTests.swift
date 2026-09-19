import Foundation

@main
struct PatrolMotionTests {
    static func main() {
        func close(_ a: Float, _ b: Float) -> Bool { abs(a - b) < 0.0001 }
        let start = PatrolMotion.step(position: 0, direction: 1, speed: 0.25, deltaTime: 0.4)
        let reflected = PatrolMotion.step(position: 0.24, direction: 1, speed: 0.25, deltaTime: 0.08)
        let stopped = PatrolMotion.step(position: 0.1, direction: -1, speed: 0, deltaTime: 1)
        let longFrame = PatrolMotion.step(position: 0, direction: 1, speed: 0.25, deltaTime: 10)
        var split: (position: Float, direction: Float) = (0, 1)
        for _ in 0..<10 {
            split = PatrolMotion.step(position: split.position, direction: split.direction, speed: 0.25, deltaTime: 0.2)
        }
        let whole = PatrolMotion.step(position: 0, direction: 1, speed: 0.25, deltaTime: 2)
        let reverse = PatrolMotion.step(position: -0.24, direction: -1, speed: 0.25, deltaTime: 0.08)
        let invalid = PatrolMotion.step(position: 0.1, direction: 1, speed: 0.25, deltaTime: -.infinity)
        let cases: [(String, Bool)] = [
            ("speed is metres per second", close(start.position, 0.1)),
            ("reflects at right boundary without losing overshoot", close(reflected.position, 0.24) && reflected.direction == -1),
            ("zero speed preserves position and direction", close(stopped.position, 0.1) && stopped.direction == -1),
            ("long frames stay within bounds", close(longFrame.position, 0) && longFrame.direction == -1),
            ("frame partition preserves motion", close(split.position, whole.position) && split.direction == whole.direction),
            ("reflects at left boundary", close(reverse.position, -0.24) && reverse.direction == 1),
            ("invalid time does not corrupt position", close(invalid.position, 0.1)),
        ]
        for (name, passed) in cases { print("\(passed ? "PASS" : "FAIL"): \(name)") }
        if cases.contains(where: { !$0.1 }) { exit(1) }
    }
}
