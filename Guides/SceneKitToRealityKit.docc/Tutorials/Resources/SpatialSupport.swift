import SwiftUI
import Combine
import RealityKit
import ARKit
import AVFoundation
import UIKit

@MainActor
struct SpatialLessonView: View {
    let configuration: ARWorldTrackingConfiguration
    var enableOcclusion = false
    var place: ((AnchorEntity) -> Void)? = nil
    @StateObject private var state = SpatialLessonState()

    private var deviceSupportsAR: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        ARWorldTrackingConfiguration.isSupported
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            if !deviceSupportsAR {
                notice("이 실습은 실물 iPhone·iPad가 필요합니다", detail: "시뮬레이터에서는 카메라와 실제 공간을 읽을 수 없습니다. 4장의 ECS 실습은 시뮬레이터에서도 할 수 있습니다.")
            } else if state.permission == .authorized {
                SpatialSurface(state: state, configuration: configuration, enableOcclusion: enableOcclusion, place: place)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.status).font(.headline)
                    Text(state.tracking).font(.subheadline)
                    if configuration.sceneReconstruction != [] {
                        Text("공간 메시 \(state.meshCount)개 · 가려짐 \(enableOcclusion ? "켬" : "끔")").font(.caption)
                    } else if !ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                        Text("공간 메시 미지원 · 이 기기에서는 배치만 가능합니다.").font(.caption)
                    }
                    Button("처음부터 다시 찾기") { state.restart() }
                        .buttonStyle(.borderedProminent)
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                .padding().padding(.bottom, 20)
            } else {
                VStack(spacing: 18) {
                    Text("현실의 바닥을 보려면 카메라 접근이 필요합니다.").font(.headline)
                    if state.permission == .denied || state.permission == .restricted {
                        Text("설정에서 이 앱의 카메라 접근을 허용한 뒤 돌아오세요.")
                        Link("앱 설정 열기", destination: URL(string: UIApplication.openSettingsURLString)!)
                    } else {
                        Button("카메라 허용하기") { state.requestCamera() }.buttonStyle(.borderedProminent)
                    }
                }.foregroundStyle(.white).padding().frame(maxHeight: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermission()
        }
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "iphone").font(.largeTitle)
            Text(title).font(.title2.bold())
            Text(detail).foregroundStyle(.secondary)
        }.multilineTextAlignment(.center).padding(28).frame(maxHeight: .infinity)
            .foregroundStyle(.white)
    }
}

@MainActor
private final class SpatialLessonState: NSObject, ObservableObject, @preconcurrency ARSessionDelegate {
    @Published var permission = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var status = "밝은 곳에서 바닥을 천천히 비추세요."
    @Published var tracking = "공간 관찰을 준비하고 있습니다."
    @Published var meshCount = 0
    weak var view: ARView?
    var configuration: ARWorldTrackingConfiguration?
    var place: ((AnchorEntity) -> Void)?
    private var placedAnchor: ARAnchor?
    private var entityAnchor: AnchorEntity?
    private var meshes = Set<UUID>()
    private var planes = Set<UUID>()

    func refreshPermission() { permission = AVCaptureDevice.authorizationStatus(for: .video) }

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    func start(view: ARView, configuration: ARWorldTrackingConfiguration, place: ((AnchorEntity) -> Void)?) {
        self.view = view
        self.configuration = configuration
        self.place = place
        view.session.delegateQueue = .main
        view.session.delegate = self
        restart()
    }

    func restart() {
        guard let view, let configuration else { return }
        entityAnchor?.removeFromParent()
        entityAnchor = nil
        placedAnchor = nil
        meshes.removeAll()
        planes.removeAll()
        meshCount = 0
        status = configuration.planeDetection.isEmpty
            ? "카메라가 켜졌습니다. 아직 평면 탐지는 꺼져 있습니다."
            : "밝은 곳에서 바닥을 천천히 비추세요."
        tracking = "공간을 관찰하고 있습니다."
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    @objc func tapped(_ gesture: UITapGestureRecognizer) {
        guard let view, let place else { return }
        guard let camera = view.session.currentFrame?.camera,
              case .normal = camera.trackingState else {
            status = "아직 위치를 안정적으로 읽지 못했습니다. 밝은 바닥을 천천히 비추세요."
            return
        }
        let point = gesture.location(in: view)
        guard let hit = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first else {
            status = "여기서는 수평면을 찾지 못했습니다. 바닥을 더 비춘 뒤 다시 눌러 보세요."
            return
        }
        if let placedAnchor { view.session.remove(anchor: placedAnchor) }
        entityAnchor?.removeFromParent()
        let trackedAnchor = ARAnchor(name: "Pig placement", transform: hit.worldTransform)
        let root = AnchorEntity(anchor: trackedAnchor)
        place(root)
        view.session.add(anchor: trackedAnchor)
        view.scene.addAnchor(root)
        placedAnchor = trackedAnchor
        entityAnchor = root
        let fallback = root.children.contains { $0.name.contains("분홍 상자") }
        status = fallback ? "모델 대신 분홍 상자를 놓았습니다. Piggy.usdc의 앱 타깃 포함을 확인하세요." : "돼지를 놓았습니다. 기기를 천천히 옮겨 보세요."
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { update(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { update(anchors) }

    private func update(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal { planes.insert(plane.identifier) }
            if anchor is ARMeshAnchor { meshes.insert(anchor.identifier) }
        }
        meshCount = meshes.count
        if placedAnchor == nil && !planes.isEmpty {
            status = place == nil ? "수평면을 찾았습니다. 다음 단계에서 돼지를 추가하세요." : "수평면을 찾았습니다. 보이는 바닥을 눌러 돼지를 놓으세요."
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            planes.remove(anchor.identifier)
            meshes.remove(anchor.identifier)
            if anchor.identifier == placedAnchor?.identifier {
                entityAnchor?.removeFromParent()
                entityAnchor = nil
                placedAnchor = nil
                status = "배치 기준을 잃었습니다. 바닥을 다시 눌러 놓으세요."
            }
        }
        meshCount = meshes.count
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal: tracking = "위치 추적이 안정적입니다."
        case .notAvailable: tracking = "위치를 읽을 수 없습니다. 처음부터 다시 찾아보세요."
        case .limited(.excessiveMotion): tracking = "기기를 조금 더 천천히 움직이세요."
        case .limited(.insufficientFeatures): tracking = "무늬가 있는 밝은 바닥을 비추세요."
        case .limited: tracking = "위치를 찾는 중입니다. 바닥을 천천히 둘러보세요."
        }
    }

    func sessionWasInterrupted(_ session: ARSession) { tracking = "공간 관찰이 잠시 중단됐습니다." }
    func sessionInterruptionEnded(_ session: ARSession) { restart() }
    func session(_ session: ARSession, didFailWithError error: Error) {
        status = "AR을 시작하지 못했습니다. 카메라 권한을 확인하고 다시 찾아보세요."
        tracking = error.localizedDescription
    }
}

@MainActor
private struct SpatialSurface: UIViewRepresentable {
    let state: SpatialLessonState
    let configuration: ARWorldTrackingConfiguration
    let enableOcclusion: Bool
    let place: ((AnchorEntity) -> Void)?

    func makeCoordinator() -> SpatialLessonState { state }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let tap = UITapGestureRecognizer(target: state, action: #selector(SpatialLessonState.tapped(_:)))
        view.addGestureRecognizer(tap)
        applyOcclusion(view)
        state.view = view
        Task { @MainActor [weak view] in
            guard let view, state.view === view else { return }
            state.start(view: view, configuration: configuration, place: place)
        }
        return view
    }

    func updateUIView(_ view: ARView, context: Context) { applyOcclusion(view) }

    private func applyOcclusion(_ view: ARView) {
        if enableOcclusion && configuration.sceneReconstruction != [] {
            view.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            view.environment.sceneUnderstanding.options.remove(.occlusion)
        }
    }

    static func dismantleUIView(_ view: ARView, coordinator: SpatialLessonState) {
        view.session.delegate = nil
        view.session.pause()
        if coordinator.view === view { coordinator.view = nil }
    }
}
