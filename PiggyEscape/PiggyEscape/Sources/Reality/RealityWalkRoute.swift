import simd

struct RealityWalkRoute: Equatable {
    let points: [SIMD3<Float>]
}

extension RealityHidePlan {
    func routed(along route: RealityWalkRoute) -> RealityHidePlan? {
        guard route.points.count >= 2,
              let start = route.points.first,
              let destination = route.points.last,
              route.points.allSatisfy(\.allFinite) else { return nil }
        return RealityHidePlan(
            start: start,
            destination: destination,
            retreatDirection: retreatDirection,
            floorRegion: floorRegion,
            waypoints: Array(route.points.dropFirst()),
            cameraPosition: cameraPosition
        )
    }
}

enum RealityWalkRouteFailure: Equatable {
    case invalidPlan
    case insufficientFloor
    case cameraTooClose
    case movementObstructed
}

enum RealityWalkRoutePlanner {
    /// Conservative horizontal clearance for route candidates; the renderer checks
    /// the installed model's actual footprint again before it starts to move.
    static let footprintRadius: Float = 0.20

    static func route(
        for plan: RealityHidePlan,
        onFailure: (RealityWalkRouteFailure) -> Void = { _ in },
        isSegmentClear: (SIMD3<Float>, SIMD3<Float>) -> Bool
    ) -> RealityWalkRoute? {
        guard plan.start.allFinite, plan.destination.allFinite,
              plan.retreatDirection.allFinite,
              plan.cameraPosition?.allFinite != false else {
            return fail(.invalidPlan, notifying: onFailure)
        }
        let horizontal = SIMD3(plan.retreatDirection.x, 0, plan.retreatDirection.z)
        let horizontalMagnitudeSquared = simd_length_squared(horizontal)
        guard horizontalMagnitudeSquared.isFinite,
              horizontalMagnitudeSquared > 0.0001 else {
            return fail(.invalidPlan, notifying: onFailure)
        }
        let retreat = simd_normalize(horizontal)
        let side = SIMD3(-retreat.z, 0, retreat.x)
        let startExtras: [Float] = plan.cameraPosition == nil ? [0] : [0, 0.15, 0.30, 0.45, 0.60]
        var candidates: [RealityWalkRoute] = []
        var foundFloorCandidate = false
        for startExtra in startExtras {
            let start = plan.start - retreat * startExtra
            for extraDepth: Float in [0, 0.25, 0.55, 0.85] {
                for sideDistance: Float in [0.40, 0.50, 0.60, 0.70, 0.80, 1.0, 1.2, 1.4] {
                    for sign: Float in [1, -1] {
                        let destination = plan.destination + retreat * extraDepth
                        let offset = side * sideDistance * sign
                        let unprojected = [start, start + offset, destination + offset, destination]
                        let points = unprojected.compactMap { plan.floorRegion.pointOnFloor(projecting: $0) }
                        guard points.count == 4,
                              points.allSatisfy({ hasFloor(for: $0, in: plan.floorRegion) }) else { continue }
                        foundFloorCandidate = true
                        if let cameraPosition = plan.cameraPosition {
                            let cameraDistance = simd_distance(points[0], cameraPosition)
                            guard cameraDistance.isFinite,
                                  cameraDistance >= RealityHidePlanner.minimumCameraDistance else { continue }
                        }
                        candidates.append(RealityWalkRoute(points: points))
                    }
                }
            }
        }
        guard !candidates.isEmpty else {
            let failure: RealityWalkRouteFailure = foundFloorCandidate ? .cameraTooClose : .insufficientFloor
            return fail(failure, notifying: onFailure)
        }
        // Stable ordering prefers the shortest bounded side route. There is no
        // straight-through fallback if every route crosses measured geometry.
        let ordered = candidates.enumerated().sorted {
            let lhs = length(of: $0.element)
            let rhs = length(of: $1.element)
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }
        var collisionResults: [RouteSegmentKey: Bool] = [:]
        for candidate in ordered {
            let route = candidate.element
            let isClear = zip(route.points, route.points.dropFirst()).allSatisfy { start, end in
                let key = RouteSegmentKey(start, end)
                if let cached = collisionResults[key] { return cached }
                let result = isSegmentClear(start, end)
                collisionResults[key] = result
                return result
            }
            if isClear {
                return route
            }
        }
        return fail(.movementObstructed, notifying: onFailure)
    }

    private static func fail(
        _ failure: RealityWalkRouteFailure,
        notifying onFailure: (RealityWalkRouteFailure) -> Void
    ) -> RealityWalkRoute? {
        onFailure(failure)
        return nil
    }

    private static func hasFloor(for point: SIMD3<Float>, in floor: RealityFloorRegion) -> Bool {
        for x in [-footprintRadius, footprintRadius] {
            for z in [-footprintRadius, footprintRadius] {
                guard floor.containsPlacementXZ(point + SIMD3(x, 0, z)) else { return false }
            }
        }
        return true
    }

    private static func length(of route: RealityWalkRoute) -> Float {
        zip(route.points, route.points.dropFirst()).reduce(0) { $0 + simd_distance($1.0, $1.1) }
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

private struct RoutePointKey: Hashable, Comparable {
    let x: UInt32
    let y: UInt32
    let z: UInt32

    init(_ point: SIMD3<Float>) {
        x = Self.bits(for: point.x)
        y = Self.bits(for: point.y)
        z = Self.bits(for: point.z)
    }

    static func < (lhs: RoutePointKey, rhs: RoutePointKey) -> Bool {
        if lhs.x != rhs.x { return lhs.x < rhs.x }
        if lhs.y != rhs.y { return lhs.y < rhs.y }
        return lhs.z < rhs.z
    }

    private static func bits(for value: Float) -> UInt32 {
        value == 0 ? 0 : value.bitPattern
    }
}

private struct RouteSegmentKey: Hashable {
    let first: RoutePointKey
    let second: RoutePointKey

    init(_ start: SIMD3<Float>, _ end: SIMD3<Float>) {
        let startKey = RoutePointKey(start)
        let endKey = RoutePointKey(end)
        if startKey < endKey {
            first = startKey
            second = endKey
        } else {
            first = endKey
            second = startKey
        }
    }
}
