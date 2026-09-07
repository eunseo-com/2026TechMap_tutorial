import Foundation
import simd

struct RealityWalkSample {
    let position: SIMD3<Float>
    let yaw: Float
    let isComplete: Bool
}

/// Sampled by scene updates, never by a guessed DispatchQueue completion deadline.
/// Turns stay in place so smoothing cannot cut through a validated obstacle corner.
struct RealityWalkTimeline {
    static let metersPerSecond: Float = 0.45
    private struct Phase {
        let startTime: TimeInterval
        let duration: TimeInterval
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        let startYaw: Float
        let endYaw: Float
    }
    private let phases: [Phase]
    let duration: TimeInterval

    init?(points: [SIMD3<Float>], initialYaw: Float) {
        guard points.count >= 2, initialYaw.isFinite,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else { return nil }
        var phases: [Phase] = []
        var elapsed: TimeInterval = 0
        var yaw = initialYaw
        for (start, end) in zip(points, points.dropFirst()) {
            let delta = end - start
            let distance = simd_length(delta)
            guard distance.isFinite, distance > 0.0001 else { return nil }
            let heading = atan2(delta.x, delta.z)
            let turn = atan2(sin(heading - yaw), cos(heading - yaw))
            let nextYaw = yaw + turn
            if abs(turn) > 0.01 {
                let turnDuration = TimeInterval(max(0.10, abs(turn) / 3.5))
                phases.append(Phase(startTime: elapsed, duration: turnDuration, start: start,
                                    end: start, startYaw: yaw, endYaw: nextYaw))
                elapsed += turnDuration
            }
            let moveDuration = TimeInterval(distance / Self.metersPerSecond)
            phases.append(Phase(startTime: elapsed, duration: moveDuration, start: start,
                                end: end, startYaw: nextYaw, endYaw: nextYaw))
            elapsed += moveDuration
            yaw = nextYaw
        }
        guard elapsed.isFinite, !phases.isEmpty else { return nil }
        self.phases = phases
        duration = elapsed
    }

    func sample(at elapsed: TimeInterval) -> RealityWalkSample {
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        if time >= duration, let last = phases.last {
            return RealityWalkSample(position: last.end, yaw: last.endYaw, isComplete: true)
        }
        let phase = phases.first { time < $0.startTime + $0.duration } ?? phases[0]
        let fraction = Float(min(1, max(0, (time - phase.startTime) / phase.duration)))
        let easedTurn = fraction * fraction * (3 - 2 * fraction)
        return RealityWalkSample(position: phase.start + (phase.end - phase.start) * fraction,
                                 yaw: phase.startYaw + (phase.endYaw - phase.startYaw) * easedTurn,
                                 isComplete: false)
    }
}
