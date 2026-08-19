import RealityKit
import UIKit

final class RealityARSessionContainer: UIView {
    let arView = ARView(
        frame: .zero,
        cameraMode: .ar,
        automaticallyConfigureSession: false
    )
    var onReadyForSession: ((ARView) -> Void)?
    private var hasStarted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(arView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        arView.frame = bounds
        guard !hasStarted,
              window != nil,
              !bounds.isEmpty,
              !arView.bounds.isEmpty else { return }
        hasStarted = true
        onReadyForSession?(arView)
    }
}
