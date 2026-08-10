import SceneKit

@MainActor
enum C3IslandBuilder {
    private static let groundRotation = SCNVector3(-Float.pi / 2, 0, 0)
    private static let groundHorizontalScale = Float(sqrt(2.0))

    private struct Decoration {
        let assetName: String
        let tileIndex: Int
        let offset: SCNVector3
        let yaw: Float
        let maxHeight: Float
        let maxFootprint: Float

        init(
            _ assetName: String,
            _ tileIndex: Int,
            _ offset: SCNVector3,
            _ yaw: Float,
            _ maxHeight: Float,
            _ maxFootprint: Float
        ) {
            self.assetName = assetName
            self.tileIndex = tileIndex
            self.offset = offset
            self.yaw = yaw
            self.maxHeight = maxHeight
            self.maxFootprint = maxFootprint
        }
    }

    static func build() -> SCNNode {
        let island = SCNNode()
        island.name = "C3Island"

        guard let centerGround = AssetLoader.object(named: "Ground_Color") else {
            return island
        }

        centerGround.name = "FlatGround_Center"
        centerGround.eulerAngles = groundRotation
        centerGround.scale = SCNVector3(groundHorizontalScale, groundHorizontalScale, 1)
        let metrics = flatGroundMetrics(for: centerGround)
        let outerPositions = [
            SCNVector3(metrics.width, 0, 0),
            SCNVector3(metrics.width / 2, 0, metrics.depth * 0.75),
            SCNVector3(-metrics.width / 2, 0, metrics.depth * 0.75),
            SCNVector3(-metrics.width, 0, 0),
            SCNVector3(-metrics.width / 2, 0, -metrics.depth * 0.75),
            SCNVector3(metrics.width / 2, 0, -metrics.depth * 0.75)
        ]
        let centerY = metrics.height * 0.6
        centerGround.position = SCNVector3(0, centerY, 0)
        island.addChildNode(centerGround)

        for (index, position) in outerPositions.enumerated() {
            let ground = centerGround.clone()
            ground.name = "FlatGround_\(index)"
            ground.position = position
            island.addChildNode(ground)
        }

        island.addChildNode(
            buildDecorations(tilePositions: outerPositions, groundTopY: metrics.topY)
        )

        let bigPigSpawn = SCNNode()
        bigPigSpawn.name = "BigPigSpawn"
        bigPigSpawn.position = SCNVector3(0, metrics.topY + centerY, 0)
        island.addChildNode(bigPigSpawn)
        return island
    }

    private static func buildDecorations(
        tilePositions: [SCNVector3],
        groundTopY: Float
    ) -> SCNNode {
        let decorations = SCNNode()
        decorations.name = "FlatGroundDecorations"
        let specs = [
            Decoration("Cylinder_Tree1_Color", 3, SCNVector3(-0.42, 0, -0.36), 0.24, 1.74, 0.92),
            Decoration("Manger_Color", 3, SCNVector3(-0.38, 0, 0.34), -0.58, 0.54, 1.02),
            Decoration("Stone_Color", 3, SCNVector3(0.34, 0, -0.02), 0.42, 0.28, 0.40),
            Decoration("Stone_Color", 3, SCNVector3(0.66, 0, 0.18), -0.16, 0.23, 0.34),
            Decoration("Stone_Color", 3, SCNVector3(0.02, 0, 0.56), 0.72, 0.16, 0.24),
            Decoration("Coin_Color", 3, SCNVector3(0.44, 0, 0.46), -0.24, 0.04, 0.30),
            Decoration("Cylinder_Tree2_Color", 5, SCNVector3(-0.54, 0, -0.38), -0.18, 1.78, 0.92),
            Decoration("Warehouse_Color", 5, SCNVector3(0.34, 0, -0.16), -0.34, 0.98, 1.18),
            Decoration("Wood_Color", 5, SCNVector3(0.58, 0, 0.78), 0.68, 0.30, 0.70)
        ]

        for spec in specs {
            guard tilePositions.indices.contains(spec.tileIndex),
                  let decoration = makeDecoration(spec) else { continue }
            let tilePosition = tilePositions[spec.tileIndex]
            decoration.position = SCNVector3(
                tilePosition.x + spec.offset.x,
                groundTopY + 0.01,
                tilePosition.z + spec.offset.z
            )
            decorations.addChildNode(decoration)
        }
        return decorations
    }

    private static func makeDecoration(_ spec: Decoration) -> SCNNode? {
        guard let model = AssetLoader.object(named: spec.assetName) else { return nil }

        let container = SCNNode()
        container.name = spec.assetName == "Cylinder_Tree1_Color"
            ? "HideTree"
            : "Decoration_\(spec.assetName)"
        model.name = "\(spec.assetName)_Model"
        model.eulerAngles = groundRotation
        container.addChildNode(model)

        guard let bounds = geometryBounds(in: container) else { return container }
        let height = bounds.max.y - bounds.min.y
        let footprint = max(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z)
        let heightScale = height > 0.0001 ? spec.maxHeight / height : 1
        let footprintScale = footprint > 0.0001 ? spec.maxFootprint / footprint : 1
        let scale = min(heightScale, footprintScale)
        model.scale = SCNVector3(scale, scale, scale)

        if let scaledBounds = geometryBounds(in: container) {
            model.position = SCNVector3(
                -(scaledBounds.min.x + scaledBounds.max.x) / 2,
                -scaledBounds.min.y,
                -(scaledBounds.min.z + scaledBounds.max.z) / 2
            )
        }
        container.eulerAngles = SCNVector3(0, spec.yaw, 0)
        return container
    }

    private static func flatGroundMetrics(for ground: SCNNode) -> (width: Float, height: Float, depth: Float, topY: Float) {
        let probeRoot = SCNNode()
        probeRoot.addChildNode(ground.clone())
        guard let bounds = geometryBounds(in: probeRoot) else {
            return (1.732, 0.5, 2.0, 0.25)
        }
        return (
            bounds.max.x - bounds.min.x,
            bounds.max.y - bounds.min.y,
            bounds.max.z - bounds.min.z,
            bounds.max.y
        )
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
