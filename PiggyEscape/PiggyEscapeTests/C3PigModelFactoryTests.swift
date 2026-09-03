import SceneKit
import XCTest
@testable import PiggyEscape

final class C3PigModelFactoryTests: XCTestCase {
    private func bounds(of node: SCNNode, in referenceNode: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minimum = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var maximum = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)

        node.enumerateHierarchy { child, _ in
            guard let geometry = child.geometry else { return }
            let (lower, upper) = geometry.boundingBox
            for x in [lower.x, upper.x] {
                for y in [lower.y, upper.y] {
                    for z in [lower.z, upper.z] {
                        let point = child.convertPosition(SCNVector3(x, y, z), to: referenceNode)
                        minimum = SCNVector3(min(minimum.x, point.x), min(minimum.y, point.y), min(minimum.z, point.z))
                        maximum = SCNVector3(max(maximum.x, point.x), max(maximum.y, point.y), max(maximum.z, point.z))
                    }
                }
            }
        }
        return (minimum, maximum)
    }

    @MainActor
    func test_pigContainerKeepsInnerModelCorrectionWhenPoseChanges() {
        let pig = C3PigModelFactory.makeContainer(pose: .idle)
        let originalScale = pig.scale

        C3PigModelFactory.setPose(.surprised, on: pig)

        XCTAssertEqual(pig.name, "EscapePig")
        XCTAssertEqual(pig.scale.x, originalScale.x, accuracy: 0.0001)
        XCTAssertEqual(pig.scale.y, originalScale.y, accuracy: 0.0001)
        XCTAssertEqual(pig.scale.z, originalScale.z, accuracy: 0.0001)
        XCTAssertNotNil(pig.childNode(withName: "PigModel_surprised", recursively: false))
    }

    @MainActor
    func test_pigKeepsC3FacingOnTheOuterContainer() {
        let pig = C3PigModelFactory.makeContainer(pose: .running)

        XCTAssertEqual(pig.eulerAngles.y, 3 * .pi / 4, accuracy: 0.0001)
        XCTAssertEqual(pig.scale.x, 1, accuracy: 0.0001)
        XCTAssertEqual(pig.scale.y, 1, accuracy: 0.0001)
        XCTAssertEqual(pig.scale.z, 1, accuracy: 0.0001)
        XCTAssertEqual(pig.childNodes.count, 1)
    }

    @MainActor
    func test_innerModelOwnsUsdAxisCorrectionAndFloorNormalization() {
        let pig = C3PigModelFactory.makeContainer(pose: .idle)
        guard let model = pig.childNode(withName: "PigModel_idle", recursively: false) else {
            XCTFail("expected inner idle model")
            return
        }

        let modelBounds = bounds(of: model, in: pig)
        XCTAssertEqual(model.eulerAngles.x, Float.pi / 2, accuracy: 0.0001)
        XCTAssertEqual(model.eulerAngles.z, Float.pi, accuracy: 0.0001)
        XCTAssertEqual(pig.eulerAngles.x, 0, accuracy: 0.0001)
        XCTAssertEqual(pig.eulerAngles.z, 0, accuracy: 0.0001)
        XCTAssertEqual(modelBounds.min.y, 0, accuracy: 0.001)
        XCTAssertEqual(modelBounds.max.y - modelBounds.min.y, 1.5, accuracy: 0.001)
    }
}
