import simd

struct RealitySurfaceHit: Equatable {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
}

struct RealityFloor: Equatable {
    let point: SIMD3<Float>
}

struct RealityFloorPlane {
    /// AR plane edges can jitter by a few centimeters while scanning, so only a 2 cm footprint margin is accepted.
    static let footprintTolerance: Float = 0.02

    let transform: simd_float4x4
    let center: SIMD3<Float>
    let extent: SIMD2<Float>
    let rotationOnYAxis: Float

    init(
        transform: simd_float4x4,
        center: SIMD3<Float>,
        extent: SIMD2<Float>,
        rotationOnYAxis: Float = 0
    ) {
        self.transform = transform
        self.center = center
        self.extent = extent
        self.rotationOnYAxis = rotationOnYAxis
    }

    func floor(containing worldPoint: SIMD3<Float>) -> RealityFloor? {
        guard extent.x.isFinite,
              extent.y.isFinite,
              extent.x > 0,
              extent.y > 0 else {
            return nil
        }

        let localPoint = SIMD4(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let local = simd_inverse(transform) * localPoint
        let relativeX = local.x - center.x
        let relativeZ = local.z - center.z
        let cosine = cos(rotationOnYAxis)
        let sine = sin(rotationOnYAxis)
        let xOffset = abs(cosine * relativeX - sine * relativeZ)
        let zOffset = abs(sine * relativeX + cosine * relativeZ)
        guard xOffset <= extent.x / 2 + Self.footprintTolerance,
              zOffset <= extent.y / 2 + Self.footprintTolerance else {
            return nil
        }

        let floorLocal = SIMD4(local.x, center.y, local.z, 1)
        let floorWorld = transform * floorLocal
        return RealityFloor(point: SIMD3(floorWorld.x, floorWorld.y, floorWorld.z))
    }
}

enum RealityHideRejection: Equatable {
    case selectVerticalSide
    case moveFartherAway
    case findFloor
}

enum RealityHidePlanResult: Equatable {
    case accepted(SIMD3<Float>)
    case rejected(RealityHideRejection)
}

struct RealityHideAttempt: Equatable {
    let destination: SIMD3<Float>
    let retreatDirection: SIMD3<Float>
    let retryCount: Int
}

enum RealityHideVerificationDecision: Equatable {
    case hidden
    case retry(RealityHideAttempt)
    case selectAnotherTarget
}

enum RealityHideVerificationPolicy {
    static let meshSafetyMargin: Float = 0.03
    static let retryDistance: Float = 0.18
    static let maximumRetries = 2

    static func decide(
        meshDistance: Float?,
        pigDistance: Float,
        attempt: RealityHideAttempt
    ) -> RealityHideVerificationDecision {
        if let meshDistance, meshDistance + meshSafetyMargin < pigDistance {
            return .hidden
        }
        guard attempt.retryCount < maximumRetries else {
            return .selectAnotherTarget
        }
        return .retry(RealityHideAttempt(
            destination: attempt.destination + attempt.retreatDirection * retryDistance,
            retreatDirection: attempt.retreatDirection,
            retryCount: attempt.retryCount + 1
        ))
    }
}

enum RealityHidePlanner {
    static let verticalNormalMaximumY: Float = 0.35
    static let minimumCameraDistance: Float = 0.45
    static let objectClearance: Float = 0.28
    /// Keeps direct callers from pairing a selected surface with an unrelated floor point.
    /// AR plane footprint projection supplies the selected point's local XZ, never an anchor center.
    static let maximumFloorDistance: Float = 1.2

    static func plan(
        hit: RealitySurfaceHit,
        cameraPosition: SIMD3<Float>,
        floor: RealityFloor?
    ) -> RealityHidePlanResult {
        guard abs(hit.normal.y) <= verticalNormalMaximumY else {
            return .rejected(.selectVerticalSide)
        }
        guard simd_distance(hit.point, cameraPosition) >= minimumCameraDistance else {
            return .rejected(.moveFartherAway)
        }
        guard let floor else {
            return .rejected(.findFloor)
        }

        let floorOffset = SIMD2(hit.point.x - floor.point.x, hit.point.z - floor.point.z)
        guard simd_length(floorOffset) <= maximumFloorDistance else {
            return .rejected(.findFloor)
        }
        guard simd_length_squared(hit.normal) > 0.0001 else {
            return .rejected(.selectVerticalSide)
        }

        let normal = simd_normalize(hit.normal)
        let towardCamera = simd_dot(normal, cameraPosition - hit.point) >= 0 ? normal : -normal
        let hiddenPoint = hit.point - towardCamera * objectClearance
        return .accepted(SIMD3(hiddenPoint.x, floor.point.y, hiddenPoint.z))
    }
}

struct RealityCameraPose: Equatable {
    let position: SIMD3<Float>
    let forward: SIMD3<Float>
}

struct RealityRevealMonitor {
    /// 15 cm exceeds ordinary hand tremor while still representing a small physical step around an object.
    static let minimumTranslation: Float = 0.15
    /// 15° is a deliberate device reframe; mesh visibility must still remain stable before revealing.
    static let minimumRotation: Float = .pi / 12
    static let requiredStableVisibleObservations = 2

    private var hasObservedBlockingMesh = false
    private var hasReportedReveal = false
    private var blockingPose: RealityCameraPose?
    private var stableVisibleObservationCount = 0

    mutating func update(
        meshDistance: Float?,
        pigDistance: Float,
        cameraPose: RealityCameraPose
    ) -> Bool {
        let blocked = meshDistance.map { $0 + 0.03 < pigDistance } ?? false
        if blocked {
            hasObservedBlockingMesh = true
            if blockingPose == nil {
                blockingPose = cameraPose
            }
            stableVisibleObservationCount = 0
            return false
        }

        guard hasObservedBlockingMesh,
              !hasReportedReveal,
              let blockingPose,
              hasMeaningfulViewpointChange(from: blockingPose, to: cameraPose) else {
            stableVisibleObservationCount = 0
            return false
        }

        stableVisibleObservationCount += 1
        guard stableVisibleObservationCount >= Self.requiredStableVisibleObservations else {
            return false
        }
        hasReportedReveal = true
        return true
    }

    mutating func recordInvalidObservation() {
        stableVisibleObservationCount = 0
    }

    private func hasMeaningfulViewpointChange(
        from blockedPose: RealityCameraPose,
        to currentPose: RealityCameraPose
    ) -> Bool {
        let translation = simd_distance(blockedPose.position, currentPose.position)
        guard translation.isFinite else { return false }
        if translation >= Self.minimumTranslation {
            return true
        }

        let blockedLength = simd_length(blockedPose.forward)
        let currentLength = simd_length(currentPose.forward)
        guard blockedLength > 0.0001, currentLength > 0.0001 else { return false }
        let directionsDot = simd_dot(blockedPose.forward / blockedLength, currentPose.forward / currentLength)
        return directionsDot <= cos(Self.minimumRotation) + 0.000_001
    }
}
