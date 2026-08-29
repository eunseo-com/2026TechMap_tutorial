import simd

struct RealityCameraPose {
    let position: SIMD3<Float>
    let forward: SIMD3<Float>
}

struct RealityRevealMonitor {
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
            blockingPose = blockingPose ?? cameraPose
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
        guard stableVisibleObservationCount >= 2 else { return false }
        hasReportedReveal = true
        return true
    }

    private func hasMeaningfulViewpointChange(
        from blockedPose: RealityCameraPose,
        to currentPose: RealityCameraPose
    ) -> Bool {
        if simd_distance(blockedPose.position, currentPose.position) >= 0.15 {
            return true
        }
        let directionsDot = simd_dot(
            blockedPose.forward / simd_length(blockedPose.forward),
            currentPose.forward / simd_length(currentPose.forward)
        )
        return directionsDot <= cos(.pi / 12)
    }
}
