import SpriteKit
import XCTest
@testable import PiggyEscape

@MainActor
final class NarrationOverlaySceneTests: XCTestCase {
    func test_showUpdatesCaptionSynchronouslyWithoutAnSKView() {
        let overlay = NarrationOverlayScene(size: CGSize(width: 320, height: 180))

        overlay.show("테스트 자막")

        XCTAssertEqual(overlay.captionText, "테스트 자막")
    }

    func test_openingAndSurpriseCaptionsUseTheRequiredCopy() {
        let overlay = NarrationOverlayScene(size: CGSize(width: 320, height: 180))

        overlay.showOpeningNarration()
        XCTAssertEqual(overlay.captionText, "아, 나 좀 그만 쳐다보지. 나 숨고 싶어…")

        overlay.showSurpriseCaption()
        XCTAssertEqual(overlay.captionText, "아, 들켰네… 제대로 숨고 싶은데.")
    }
}
