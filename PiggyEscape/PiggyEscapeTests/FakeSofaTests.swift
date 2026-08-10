import XCTest
import SceneKit
@testable import PiggyEscape

final class FakeSofaTests: XCTestCase {
    @MainActor
    func test_makeSofaNode_isNamedFakeSofa() {
        let sofa = FakeSofa.makeSofaNode()
        XCTAssertEqual(sofa.name, "FakeSofa")
    }

    @MainActor
    func test_makeSofaNode_isPlacedAtHardcodedPosition() {
        let sofa = FakeSofa.makeSofaNode()
        XCTAssertEqual(sofa.position.x, FakeSofa.hardcodedPosition.x, accuracy: 0.0001)
        XCTAssertEqual(sofa.position.z, FakeSofa.hardcodedPosition.z, accuracy: 0.0001)
    }

    func test_hardcodedPosition_isInsideRoomBounds() {
        // "가짜 소파"도 방 안 좌표일 뿐 — 실제 소파 위치와는 무관하다는 걸 좌표 자체로 보여준다.
        XCTAssertLessThan(abs(FakeSofa.hardcodedPosition.x), RoomBuilder.roomWidth / 2)
        XCTAssertLessThan(abs(FakeSofa.hardcodedPosition.z), RoomBuilder.roomDepth / 2)
    }

    /// 회귀 방지: Wood_Color.usdc는 원본 스케일이 방보다 몇 배 큰 메시라서,
    /// makeSofaNode()가 정규화를 빼먹으면 방(wallHeight 2.5m)보다 커지거나
    /// 돼지(0.6m)보다 비정상적으로 커져 화면을 뒤덮는다. 실제 렌더된 바운딩
    /// 박스 높이가 방/돼지 스케일에 비해 "작은 가구 하나" 수준인지 확인한다.
    @MainActor
    func test_makeSofaNode_isNormalizedToSmallFurnitureScale() {
        let sofa = FakeSofa.makeSofaNode()
        let (lo, hi) = SceneKitGeometry.boundingBox(of: sofa)
        let height = (hi.y - lo.y) * sofa.scale.y

        XCTAssertGreaterThan(height, 0.05, "sofa should not collapse to zero size")
        XCTAssertLessThan(height, RoomBuilder.wallHeight, "sofa should fit under the room's ceiling")
        XCTAssertLessThan(height, 1.0, "a normalized sofa should be furniture-scale, not room-scale")
    }
}
