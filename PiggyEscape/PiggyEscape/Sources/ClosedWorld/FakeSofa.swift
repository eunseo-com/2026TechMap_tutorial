import SceneKit
import UIKit

/// "가짜 소파" — 개발자가 코드로 선언한 숨는 지점. 실제 방의 진짜 소파와는
/// 아무 관계가 없다. 스텝 5의 "숨어봐" 인터랙션이 이동시키는 목적지가 바로 이 좌표다.
enum FakeSofa {
    static let hardcodedPosition = SCNVector3(1.2, 0, -1.2)
    /// 방(벽 높이 2.5m)과 돼지(0.6m) 사이, "작은 가구 한 점" 정도의 눈대중 높이.
    private static let standardHeight: Float = 0.45

    @MainActor
    static func makeSofaNode() -> SCNNode {
        let model = AssetLoader.object(named: "Wood_Color") {
            AssetLoader.voxelBox(width: 0.8, height: 0.4, length: 0.5, color: .brown)
        }
        SceneKitGeometry.normalize(model, toHeight: standardHeight)
        model.name = "FakeSofa"
        model.position = hardcodedPosition
        return model
    }
}
