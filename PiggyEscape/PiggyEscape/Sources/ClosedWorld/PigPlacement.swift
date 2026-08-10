import SceneKit

/// 돼지를 하드코딩된 좌표에 배치한다. 이 좌표는 개발자가 정한 것일 뿐,
/// 방 안의 어떤 실제 기준(가구 위치 등)과도 연결되어 있지 않다.
enum PigPlacement {
    static let hardcodedPosition = SCNVector3(0, 0, 1)
    private static let standardHeight: Float = 0.6

    @MainActor
    static func makePigNode() -> SCNNode {
        let model = AssetLoader.object(named: "Piggy") {
            AssetLoader.voxelBox(width: 0.4, height: 0.4, length: 0.6, color: .systemPink)
        }
        normalize(model, toHeight: standardHeight)
        model.name = "Piggy"
        model.position = hardcodedPosition
        return model
    }

    @MainActor
    private static func normalize(_ node: SCNNode, toHeight targetHeight: Float) {
        let (lo, hi) = boundingBox(of: node)
        let height = hi.y - lo.y
        guard height > 0.0001 else { return }
        let scale = targetHeight / height
        node.scale = SCNVector3(scale, scale, scale)
    }

    private static func boundingBox(of node: SCNNode) -> (SCNVector3, SCNVector3) {
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
}
