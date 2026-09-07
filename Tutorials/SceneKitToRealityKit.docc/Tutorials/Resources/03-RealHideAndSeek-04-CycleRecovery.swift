// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityHideARView.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityWalkClearance.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityWalkRoute.swift
// Production: PiggyEscape/PiggyEscape/Sources/Reality/RealityWalkTimeline.swift
// Production: PiggyEscape/PiggyEscape/Sources/Escape/EscapeRootCoordinator.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityHideARViewCoordinatorTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityWalkRouteTests.swift
// Contract tests: PiggyEscape/PiggyEscapeTests/RealityWalkTimelineTests.swift

import Foundation
import RealityKit
import simd

struct PlacementFloorRegion {
    // Teaching simplification: axis-aligned, already projected to floor Y and
    // inset by 0.10m. Production uses the rotated immutable AR floor snapshot.
    let minimumXZ: SIMD2<Float>
    let maximumXZ: SIMD2<Float>

    func contains(_ point: SIMD3<Float>) -> Bool {
        point.x >= minimumXZ.x && point.x <= maximumXZ.x
            && point.z >= minimumXZ.y && point.z <= maximumXZ.y
    }
}

struct SideWalkRoute {
    let points: [SIMD3<Float>]
}

enum SideWalkRouteFailure {
    case invalidPlan, insufficientFloor, cameraTooClose, movementObstructed
}

enum SideWalkRoutePlanner {
    static let footprintRadius: Float = 0.20
    static let minimumCameraDistance: Float = 0.90
    static let startExtras: [Float] = [0, 0.15, 0.30, 0.45, 0.60]
    static let sideDistances: [Float] = [0.40, 0.50, 0.60, 0.70, 0.80, 1.0, 1.2, 1.4]
    static let extraDepths: [Float] = [0, 0.25, 0.55, 0.85]

    private struct Segment: Hashable {
        let start: SIMD3<Float>
        let end: SIMD3<Float>
    }

    static func route(
        start: SIMD3<Float>,
        destination: SIMD3<Float>,
        retreatDirection: SIMD3<Float>,
        floor: PlacementFloorRegion,
        cameraPosition: SIMD3<Float>?,
        onFailure: (SideWalkRouteFailure) -> Void,
        isSegmentClear: (SIMD3<Float>, SIMD3<Float>) -> Bool
    ) -> SideWalkRoute? {
        let horizontal = SIMD3(retreatDirection.x, 0, retreatDirection.z)
        let magnitude = simd_length_squared(horizontal)
        guard start.allFinite, destination.allFinite, retreatDirection.allFinite,
              cameraPosition?.allFinite ?? true,
              magnitude.isFinite, magnitude > 0.0001 else {
            onFailure(.invalidPlan)
            return nil
        }
        let retreat = simd_normalize(horizontal)
        let side = SIMD3(-retreat.z, 0, retreat.x)
        var candidates: [SideWalkRoute] = []
        var hadFloorCandidate = false

        // Without the selection-time camera snapshot, preserve the legacy spawn.
        for extra in cameraPosition == nil ? [0] : startExtras {
            let spawn = start - retreat * extra
            for depth in extraDepths {
                for distance in sideDistances {
                    for sign: Float in [1, -1] {
                        let end = destination + retreat * depth
                        let offset = side * distance * sign
                        let points = [spawn, spawn + offset, end + offset, end]
                        guard points.allSatisfy({ hasFloor(at: $0, in: floor) }) else {
                            continue
                        }
                        hadFloorCandidate = true
                        if let cameraPosition {
                            let distance = simd_distance(spawn, cameraPosition)
                            guard distance.isFinite, distance >= minimumCameraDistance else {
                                continue
                            }
                        }
                        candidates.append(SideWalkRoute(points: points))
                    }
                }
            }
        }

        guard !candidates.isEmpty else {
            onFailure(hadFloorCandidate ? .cameraTooClose : .insufficientFloor)
            return nil
        }
        let ordered = candidates.enumerated().sorted {
            let lhs = length($0.element)
            let rhs = length($1.element)
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }
        var clearances: [Segment: Bool] = [:]
        for candidate in ordered {
            let route = candidate.element
            if zip(route.points, route.points.dropFirst()).allSatisfy({ start, end in
                let segment = Segment(start: start, end: end)
                if let clear = clearances[segment] { return clear }
                let clear = isSegmentClear(start, end)
                clearances[segment] = clear
                return clear
            }) {
                // Place the still-disabled pig at points.first, then walk along
                // dropFirst(). Never move from the rejected original start.
                return route
            }
        }
        onFailure(.movementObstructed)
        return nil
    }

    private static func hasFloor(
        at point: SIMD3<Float>,
        in floor: PlacementFloorRegion
    ) -> Bool {
        for x in [-footprintRadius, footprintRadius] {
            for z in [-footprintRadius, footprintRadius] {
                if !floor.contains(point + SIMD3(x, 0, z)) { return false }
            }
        }
        return true
    }

    private static func length(_ route: SideWalkRoute) -> Float {
        zip(route.points, route.points.dropFirst()).reduce(0) {
            $0 + simd_distance($1.0, $1.1)
        }
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

/// A real implementation uses the installed model footprint for bodyRadius.
/// An empty cast only describes measured geometry; it cannot certify unscanned space.
@MainActor
func clearsMeasuredBodyVolume(
    in scene: RealityKit.Scene,
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    bodyRadius: Float
) -> Bool {
    guard bodyRadius.isFinite, bodyRadius > 0 else { return false }
    let pigHeight: Float = 0.18
    let shape = ShapeResource.generateBox(
        size: [bodyRadius * 2, pigHeight, bodyRadius * 2]
    )
    let offset = SIMD3<Float>(0, pigHeight / 2 + 0.025, 0)
    let orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    return scene.convexCast(
        convexShape: shape,
        fromPosition: start + offset,
        fromOrientation: orientation,
        toPosition: end + offset,
        toOrientation: orientation,
        query: .nearest,
        mask: .sceneUnderstanding,
        relativeTo: nil
    ).isEmpty
}

struct WalkSample {
    let position: SIMD3<Float>
    let yaw: Float
    let isComplete: Bool
}

/// Production feeds SceneEvents.Update.deltaTime into this timeline and checks
/// every small move again. A blocked move cancels the cycle and returns to selection.
struct SceneTimeWalkTimeline {
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
        guard points.count >= 2, initialYaw.isFinite else { return nil }
        var result: [Phase] = []
        var elapsed: TimeInterval = 0
        var yaw = initialYaw

        for (start, end) in zip(points, points.dropFirst()) {
            let distance = simd_distance(start, end)
            guard distance.isFinite, distance > 0.0001 else { return nil }
            let delta = end - start
            let heading = atan2(delta.x, delta.z)
            let shortestTurn = atan2(sin(heading - yaw), cos(heading - yaw))
            let nextYaw = yaw + shortestTurn
            if abs(shortestTurn) > 0.01 {
                let turnDuration = TimeInterval(max(0.10, abs(shortestTurn) / 3.5))
                result.append(Phase(
                    startTime: elapsed, duration: turnDuration,
                    start: start, end: start, startYaw: yaw, endYaw: nextYaw
                ))
                elapsed += turnDuration
            }
            let moveDuration = TimeInterval(distance / Self.metersPerSecond)
            result.append(Phase(
                startTime: elapsed, duration: moveDuration,
                start: start, end: end, startYaw: nextYaw, endYaw: nextYaw
            ))
            elapsed += moveDuration
            yaw = nextYaw
        }
        guard elapsed.isFinite, !result.isEmpty else { return nil }
        phases = result
        duration = elapsed
    }

    func sample(at elapsed: TimeInterval) -> WalkSample {
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        if time >= duration, let last = phases.last {
            return WalkSample(position: last.end, yaw: last.endYaw, isComplete: true)
        }
        let phase = phases.first { time < $0.startTime + $0.duration } ?? phases[0]
        let fraction = Float(min(1, max(0, (time - phase.startTime) / phase.duration)))
        let easedTurn = fraction * fraction * (3 - 2 * fraction)
        return WalkSample(
            position: phase.start + (phase.end - phase.start) * fraction,
            yaw: phase.startYaw + (phase.endYaw - phase.startYaw) * easedTurn,
            isComplete: false
        )
    }
}

enum RetryDecision {
    case move(to: SIMD3<Float>, retryCount: Int)
    case returnToTargetSelection
}

struct BoundedHideRecovery {
    static let retryDistance: Float = 0.18
    static let maximumRetries = 2

    private(set) var destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let floor: PlacementFloorRegion
    private var retryCount = 0

    mutating func exhaustedAttempt() -> RetryDecision {
        guard retryCount < Self.maximumRetries else {
            return .returnToTargetSelection
        }
        let candidate = destination + retreatDirection * Self.retryDistance
        guard floor.contains(candidate) else { return .returnToTargetSelection }
        retryCount += 1
        destination = candidate
        return .move(to: candidate, retryCount: retryCount)
    }
}

struct HideCycleToken: Equatable {
    let realityGeneration: Int
    let cycleGeneration: Int
}

struct HideCycleLifetime {
    private var realityGeneration = 0
    private var cycleGeneration = 0

    var current: HideCycleToken {
        HideCycleToken(
            realityGeneration: realityGeneration,
            cycleGeneration: cycleGeneration
        )
    }

    mutating func beginFreshCycle() { cycleGeneration += 1 }
    mutating func beginFreshSession() {
        realityGeneration += 1
        cycleGeneration += 1
    }
    func accepts(_ token: HideCycleToken) -> Bool { token == current }
}

/// The learning sheet keeps only the latest scan update and one ready/reveal edge.
/// Closing it drains those events once; the app restarts active-time deadlines then.
struct DeferredLearningEvents<ScanUpdate> {
    private(set) var latestScan: ScanUpdate?
    private(set) var becameReady = false
    private(set) var revealed = false

    mutating func recordScan(_ update: ScanUpdate) { latestScan = update }
    mutating func recordReady() { becameReady = true }
    mutating func recordReveal() { revealed = true }

    mutating func drain() -> (ScanUpdate?, Bool, Bool) {
        defer {
            latestScan = nil
            becameReady = false
            revealed = false
        }
        return (latestScan, becameReady, revealed)
    }
}
