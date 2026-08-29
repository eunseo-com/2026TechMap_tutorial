import AVFoundation

enum CameraAuthorizationResult {
    case authorized
    case denied
    case restricted
    case notDetermined
}

struct SystemCameraAuthorizer {
    func requestVideoAccess(
        _ completion: @escaping @MainActor (CameraAuthorizationResult) -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(.authorized)
        case .denied:
            completion(.denied)
        case .restricted:
            completion(.restricted)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    completion(granted ? .authorized : .denied)
                }
            }
        @unknown default:
            completion(.restricted)
        }
    }
}
