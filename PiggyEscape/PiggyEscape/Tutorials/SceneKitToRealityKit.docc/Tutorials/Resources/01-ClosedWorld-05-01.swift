import simd

/// 실제 메쉬가 먼저 한 번 가린 뒤에만, 사용자의 이동으로 다시 보인 순간을 발행한다.
struct RealityRevealMonitorLesson {
    private var observedBlockingMesh = false
    private var reportedReveal = false

    mutating func update(meshDistance: Float?, pigDistance: Float) -> Bool {
        let isBlocked = meshDistance.map { $0 + 0.03 < pigDistance } ?? false
        observedBlockingMesh = observedBlockingMesh || isBlocked
        guard observedBlockingMesh, !isBlocked, !reportedReveal else { return false }
        reportedReveal = true
        return true
    }
}
