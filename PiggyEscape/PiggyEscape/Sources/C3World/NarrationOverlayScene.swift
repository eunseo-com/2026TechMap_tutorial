import SpriteKit

@MainActor
final class NarrationOverlayScene: SKScene {
    private let panel = SKShapeNode()
    private let shadowLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private(set) var captionText = ""

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        configureCaptionNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = .clear
        configureCaptionNodes()
    }

    func show(_ text: String, onFinished: (() -> Void)? = nil) {
        captionText = text
        label.text = text
        shadowLabel.text = text
        layoutCaption()

        panel.removeAllActions()
        panel.alpha = 0
        panel.setScale(0.94)
        let fade = SKAction.fadeIn(withDuration: 0.16)
        let scale = SKAction.scale(to: 1, duration: 0.16)
        scale.timingMode = .easeOut
        panel.run(.sequence([.group([fade, scale]), .run { onFinished?() }]))
    }

    func showOpeningNarration(onFinished: (() -> Void)? = nil) {
        show("아, 나 좀 그만 쳐다보지. 나 숨고 싶어…", onFinished: onFinished)
    }

    func showSurpriseCaption() {
        show("아, 들켰네… 제대로 숨고 싶은데.")
    }

    private func configureCaptionNodes() {
        panel.fillColor = SKColor(white: 0.05, alpha: 0.66)
        panel.strokeColor = .clear
        panel.zPosition = 10
        addChild(panel)

        shadowLabel.fontSize = 20
        shadowLabel.fontColor = SKColor(white: 0, alpha: 0.18)
        shadowLabel.horizontalAlignmentMode = .center
        shadowLabel.verticalAlignmentMode = .center
        shadowLabel.zPosition = 11
        panel.addChild(shadowLabel)

        label.fontSize = 20
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 12
        panel.addChild(label)
    }

    private func layoutCaption() {
        let width = min(max(size.width - 32, 160), 440)
        let height: CGFloat = 60
        panel.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        label.position = .zero
        shadowLabel.position = CGPoint(x: 1, y: -1)
    }
}
