import SceneKit

/// "숨어봐" 인터랙션의 핵심: 하드코딩된 가짜 소파 좌표로 이동하는 액션 하나.
/// 이 액션은 실제 방에 있는 진짜 소파가 어디 있든 상관하지 않는다 —
/// 목적지는 오직 FakeSofa.hardcodedPosition, 즉 개발자가 선언한 좌표뿐이다.
enum HideAction {
    static func makeMoveAction() -> SCNAction {
        .move(to: FakeSofa.hardcodedPosition, duration: 0.5)
    }
}
