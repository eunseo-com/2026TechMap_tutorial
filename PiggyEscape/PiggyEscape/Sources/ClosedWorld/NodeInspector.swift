import SceneKit

/// 노드 하나를 들여다보고, 생김새(geometry)·물리(physicsBody)·행동(action)이
/// 전부 같은 SCNNode 객체 위에 얹혀 있다는 걸 텍스트로 보여준다.
/// RealityKit의 ECS는 이 세 가지를 각각 다른 Component로 분리하지만,
/// SceneKit은 분리하지 않는다 — 이걸 실행 결과로 확인하기 위한 디버그 도구.
enum NodeInspector {
    static func describe(_ node: SCNNode) -> [String] {
        var lines: [String] = []

        if let geometry = node.geometry {
            lines.append("geometry: \(type(of: geometry))")
        }
        if let physicsBody = node.physicsBody {
            lines.append("physicsBody: type=\(physicsBody.type.rawValue)")
        }
        for key in node.actionKeys {
            lines.append("action[\(key)]: \(node.action(forKey: key).map(String.init(describing:)) ?? "nil")")
        }

        return lines
    }
}
