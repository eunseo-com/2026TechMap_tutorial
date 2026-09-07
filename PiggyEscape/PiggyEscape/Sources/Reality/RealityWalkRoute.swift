import simd

struct RealityWalkRoute: Equatable {
    let points: [SIMD3<Float>]
}

enum RealityWalkRoutePlanner {
    /// Conservative horizontal clearance for route candidates; the renderer checks
    /// the installed model's actual footprint again before it starts to move.
    static let footprintRadius: Float = 0.20

    static func route(
        for plan: RealityHidePlan,
        isSegmentClear: (SIMD3<Float>, SIMD3<Float>) -> Bool
    ) -> RealityWalkRoute? {
        guard plan.start.allFinite, plan.destination.allFinite,
              plan.retreatDirection.allFinite else { return nil }
        let horizontal = SIMD3(plan.retreatDirection.x, 0, plan.retreatDirection.z)
        guard simd_length_squared(horizontal) > 0.0001 else { return nil }
        let retreat = simd_normalize(horizontal)
        let side = SIMD3(-retreat.z, 0, retreat.x)
        var candidates: [RealityWalkRoute] = []
        for extraDepth: Float in [0, 0.25, 0.55, 0.85] {
            for sideDistance: Float in [0.40, 0.70, 1.0, 1.4] {
                for sign: Float in [1, -1] {
                    let destination = plan.destination + retreat * extraDepth
                    let offset = side * sideDistance * sign
                    let unprojected = [plan.start, plan.start + offset, destination + offset, destination]
                    let points = unprojected.compactMap { plan.floorRegion.pointOnFloor(projecting: $0) }
                    guard points.count == 4,
                          points.allSatisfy({ hasFloor(for: $0, in: plan.floorRegion) }) else { continue }
                    candidates.append(RealityWalkRoute(points: points))
                }
            }
        }
        // Stable ordering prefers the shortest bounded side route. There is no
        // straight-through fallback if every route crosses measured geometry.
        let ordered = candidates.enumerated().sorted {
            let lhs = length(of: $0.element)
            let rhs = length(of: $1.element)
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }
        for candidate in ordered {
            let route = candidate.element
            if zip(route.points, route.points.dropFirst()).allSatisfy({ isSegmentClear($0.0, $0.1) }) {
                return route
            }
        }
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
