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
}
