import SceneKit

/// 로드된 3D 모델은 원본 제작 스케일이 제각각이라, 방 좌표계(미터 단위)에
/// 맞춰 다시 정규화해야 한다. `PigPlacement`가 먼저 쓰던 "바운딩 박스를 재고
/// 목표 크기에 맞춰 균일하게 스케일한다" 패턴을 여러 자리(돼지, 가짜 소파,
/// 바닥)에서 공유하기 위한 도우미.
enum SceneKitGeometry {
    /// 노드(및 하위 계층 전체)의 로컬 좌표계 기준 바운딩 박스.
    static func boundingBox(of node: SCNNode) -> (SCNVector3, SCNVector3) {
        var lo = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var hi = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
        node.enumerateHierarchy { child, _ in
            guard let geometry = child.geometry else { return }
            let (minB, maxB) = geometry.boundingBox
            for x in [minB.x, maxB.x] {
                for y in [minB.y, maxB.y] {
                    for z in [minB.z, maxB.z] {
                        let p = child.convertPosition(SCNVector3(x, y, z), to: node)
                        lo = SCNVector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
                        hi = SCNVector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
                    }
                }
            }
        }
        return (lo, hi)
    }

    /// 세로(y) 치수를 재서 `targetHeight`에 맞도록 균일하게(x/y/z 동일 비율) 스케일한다.
    /// 돼지·가짜 소파처럼 "세워서 놓는" 소품에 쓴다.
    @MainActor
    static func normalize(_ node: SCNNode, toHeight targetHeight: Float) {
        let (lo, hi) = boundingBox(of: node)
        let height = hi.y - lo.y
        guard height > 0.0001 else { return }
        let scale = targetHeight / height
        node.scale = SCNVector3(scale, scale, scale)
    }

    /// 바닥면(x/z) 중 더 큰 치수를 재서 `targetWidth`에 맞도록 균일하게 스케일한다.
    /// 바닥 타일처럼 "가로로 깔아 놓는" 소품에 쓴다.
    @MainActor
    static func normalize(_ node: SCNNode, toFootprintWidth targetWidth: Float) {
        let (lo, hi) = boundingBox(of: node)
        let footprint = max(hi.x - lo.x, hi.z - lo.z)
        guard footprint > 0.0001 else { return }
        let scale = targetWidth / footprint
        node.scale = SCNVector3(scale, scale, scale)
    }
}
