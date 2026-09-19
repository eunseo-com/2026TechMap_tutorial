import SceneKit

enum NodeInspector {
    static func describe(_ node: SCNNode) -> [String] {
        var geometryCount = 0
        node.enumerateHierarchy { child, _ in
            if child.geometry != nil { geometryCount += 1 }
        }
        return [
            "node: \(node.name ?? "이름 없음")",
            "geometry (self): \(node.geometry == nil ? "없음" : "있음")",
            "geometry (subtree): \(geometryCount)",
            "physicsBody: \(node.physicsBody == nil ? "없음" : "있음")",
            "actions: \(node.actionKeys.joined(separator: ", "))"
        ]
    }
}
