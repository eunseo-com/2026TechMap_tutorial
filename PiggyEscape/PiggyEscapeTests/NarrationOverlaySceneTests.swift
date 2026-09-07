import SceneKit
import SpriteKit
import XCTest
@testable import PiggyEscape

@MainActor
final class NarrationOverlaySceneTests: XCTestCase {
    func test_renderedOpeningNarrationFinishesOnMainThread() async throws {
        let overlay = NarrationOverlayScene(size: CGSize(width: 320, height: 180))
        let completed = expectation(description: "Narration completion reaches the UI thread")
        completed.assertForOverFulfill = true
        overlay.showOpeningNarration(onFinished: Self.checkMainThread(completed))

        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.scene = SCNScene()
        view.overlaySKScene = overlay
        view.isPlaying = true
        view.rendersContinuously = true
        controller.view = view
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            view.isPlaying = false
            view.overlaySKScene = nil
            view.scene = nil
            window.rootViewController = nil
        }

        // A displayed SCNView drives the same timed overlay actions as the app.
        let result = await XCTWaiter.fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(result, .completed)
    }

    nonisolated private static func checkMainThread(_ completed: XCTestExpectation) -> () -> Void {
        {
            XCTAssertTrue(Thread.isMainThread, "Narration completion must not publish UI state on the renderer thread")
            completed.fulfill()
        }
    }

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
