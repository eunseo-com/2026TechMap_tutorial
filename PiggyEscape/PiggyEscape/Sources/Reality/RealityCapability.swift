import ARKit

protocol RealityMeshSupporting {
    var supportsMeshWithClassification: Bool { get }
}

struct SystemRealityMeshSupport: RealityMeshSupporting {
    var supportsMeshWithClassification: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }
}

enum RealityAvailabilityMessage {
    static let unavailable = "이 기능은 LiDAR로 공간을 읽을 수 있는 기기에서 사용할 수 있어."
    static let scanFirst = "주변 바닥과 숨을 물체를 조금 더 스캔해줘."
    static let selectVerticalSide = "숨을 물체의 옆면을 탭해줘."
    static let moveFartherAway = "조금 떨어진 물체의 옆면을 탭해줘."
    static let pigAssetLoadFailed = "돼지를 불러오지 못했어. 잠시 후 다시 시도해줘."
}
