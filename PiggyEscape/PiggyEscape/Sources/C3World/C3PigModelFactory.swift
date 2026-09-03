import SceneKit

enum C3PigPose: String {
    case idle
    case running
    case surprised
}

@MainActor
enum C3PigModelFactory {
    static func makeContainer(pose: C3PigPose) -> SCNNode {
        let container = SCNNode()
        container.name = "EscapePig"
        container.eulerAngles = SCNVector3(0, 3 * Float.pi / 4, 0)
        setPose(pose, on: container)
        return container
    }

    static func setPose(_ pose: C3PigPose, on container: SCNNode) {
        container.childNodes.forEach { $0.removeFromParentNode() }
        let model = loadNormalizedModel(named: assetName(for: pose))
        model.name = "PigModel_\(pose.rawValue)"
        container.addChildNode(model)
        if pose == .running {
            playEmbeddedAnimations(on: model)
        }
    }

    private static func assetName(for pose: C3PigPose) -> String {
        pose == .idle ? "Piggy" : "Piggy_\(pose.rawValue)"
    }

    private static func loadNormalizedModel(named name: String) -> SCNNode {
        let model = SCNNode()
        guard let art = AssetLoader.object(named: name) else { return model }

        model.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi)
        model.addChildNode(art)
        let measurementRoot = SCNNode()
        measurementRoot.addChildNode(model)
        guard let bounds = geometryBounds(in: measurementRoot) else { return model }
        let height = bounds.max.y - bounds.min.y
        guard height > 0.0001 else { return model }

        let scale = 1.5 / height
        model.scale = SCNVector3(scale, scale, scale)
        if let scaledBounds = geometryBounds(in: measurementRoot) {
            model.position = SCNVector3(
                -(scaledBounds.min.x + scaledBounds.max.x) / 2,
                -scaledBounds.min.y,
                -(scaledBounds.min.z + scaledBounds.max.z) / 2
            )
        }
        model.removeFromParentNode()
        return model
    }

    private static func playEmbeddedAnimations(on root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            for key in node.animationKeys {
                guard let player = node.animationPlayer(forKey: key) else { continue }
                player.animation.repeatCount = .greatestFiniteMagnitude
                player.play()
            }
        }
    }

    private static func geometryBounds(in root: SCNNode) -> (min: SCNVector3, max: SCNVector3)? {
        var minimum = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var maximum = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
        var foundGeometry = false

        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let (lower, upper) = geometry.boundingBox
            for x in [lower.x, upper.x] {
                for y in [lower.y, upper.y] {
                    for z in [lower.z, upper.z] {
                        let point = node.convertPosition(SCNVector3(x, y, z), to: root)
                        minimum = SCNVector3(min(minimum.x, point.x), min(minimum.y, point.y), min(minimum.z, point.z))
                        maximum = SCNVector3(max(maximum.x, point.x), max(maximum.y, point.y), max(maximum.z, point.z))
                        foundGeometry = true
                    }
                }
            }
        }
        return foundGeometry ? (minimum, maximum) : nil
    }
}
