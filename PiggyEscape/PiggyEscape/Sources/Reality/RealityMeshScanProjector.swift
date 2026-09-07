import ARKit
import RealityKit

/// Draws a bounded sample of actual mesh edges without an opaque debug surface.
/// AR buffers are read on the owning AR view's main-actor update, not retained by SwiftUI.
@MainActor
enum RealityMeshScanProjector {
    static func telemetry(in frame: ARFrame) -> RealityScanTelemetry {
        let meshes = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let floors = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.filter {
            $0.alignment == .horizontal && $0.classification == .floor
        }
        let tracking: RealityTrackingStatus
        switch frame.camera.trackingState {
        case .normal: tracking = .normal
        case .notAvailable: tracking = .unavailable
        case .limited(let reason):
            switch reason {
            case .initializing: tracking = .initializing
            case .excessiveMotion: tracking = .excessiveMotion
            case .insufficientFeatures: tracking = .insufficientFeatures
            case .relocalizing: tracking = .relocalizing
            @unknown default: tracking = .unavailable
            }
        }
        return RealityScanTelemetry(timestamp: frame.timestamp, meshAnchorCount: meshes.count,
                                    meshFaceCount: meshes.reduce(0) { $0 + $1.geometry.faces.count },
                                    floorAnchorCount: floors.count, tracking: tracking)
    }

    static func patches(in frame: ARFrame, arView: ARView) -> [RealityScanPatch] {
        guard !arView.bounds.isEmpty else { return [] }
        let meshes = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let totalFaces = meshes.reduce(0) { $0 + $1.geometry.faces.count }
        let faceStride = max(1, Int(ceil(Double(totalFaces) / 120)))
        var patches: [RealityScanPatch] = []
        let cameraPosition = SIMD3(frame.camera.transform.columns.3.x,
                                   frame.camera.transform.columns.3.y,
                                   frame.camera.transform.columns.3.z)
        let forward = -SIMD3(frame.camera.transform.columns.2.x,
                            frame.camera.transform.columns.2.y,
                            frame.camera.transform.columns.2.z)
        var globalFaceIndex = 0
        for anchor in meshes {
            let geometry = anchor.geometry
            guard geometry.vertices.format == .float3,
                  geometry.faces.indexCountPerPrimitive == 3,
                  [2, 4].contains(geometry.faces.bytesPerIndex) else { continue }
            let firstFace = (faceStride - globalFaceIndex % faceStride) % faceStride
            globalFaceIndex += geometry.faces.count
            for face in stride(from: firstFace, to: geometry.faces.count, by: faceStride) {
                var points: [CGPoint] = []
                for corner in 0..<3 {
                    let byteOffset = (face * 3 + corner) * geometry.faces.bytesPerIndex
                    guard byteOffset + geometry.faces.bytesPerIndex <= geometry.faces.buffer.length else { break }
                    let indices = geometry.faces.buffer.contents().advanced(by: byteOffset)
                    let index = geometry.faces.bytesPerIndex == 4
                        ? Int(indices.load(as: UInt32.self)) : Int(indices.load(as: UInt16.self))
                    guard index < geometry.vertices.count else { break }
                    let vertexOffset = geometry.vertices.offset + index * geometry.vertices.stride
                    guard vertexOffset + 12 <= geometry.vertices.buffer.length else { break }
                    let values = geometry.vertices.buffer.contents().advanced(by: vertexOffset)
                        .assumingMemoryBound(to: Float.self)
                    let world = anchor.transform * SIMD4(values[0], values[1], values[2], 1)
                    let position = SIMD3(world.x, world.y, world.z)
                    guard simd_dot(forward, position - cameraPosition) > 0,
                          let projected = arView.project(position),
                          arView.bounds.contains(projected) else { break }
                    points.append(CGPoint(x: projected.x / arView.bounds.width,
                                          y: projected.y / arView.bounds.height))
                }
                guard points.count == 3 else { continue }
                var isFloor = false
                if let classifications = geometry.classification,
                   classifications.format == .uchar,
                   face < classifications.count {
                    let offset = classifications.offset + face * classifications.stride
                    if offset < classifications.buffer.length {
                        let value = classifications.buffer.contents().advanced(by: offset).load(as: UInt8.self)
                        isFloor = Int(value) == ARMeshClassification.floor.rawValue
                    }
                }
                patches.append(RealityScanPatch(a: points[0], b: points[1], c: points[2], isFloor: isFloor))
            }
        }
        return patches
    }
}
