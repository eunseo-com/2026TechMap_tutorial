import ARKit
import RealityKit
import UIKit
import simd

struct RealityOcclusionFrameSnapshot {
    let timestamp: TimeInterval
    let cameraTransform: simd_float4x4
    let viewportBounds: CGRect
    let interfaceOrientation: UIInterfaceOrientation
}

@MainActor
protocol RealityOcclusionObservationProviding {
    func makeObservation(
        in arView: ARView,
        pigEntity: Entity
    ) -> RealityOcclusionObservation?
}

@MainActor
struct RealityOcclusionObservationProvider: RealityOcclusionObservationProviding {
    func makeObservation(
        in arView: ARView,
        pigEntity: Entity
    ) -> RealityOcclusionObservation? {
        let localBounds = pigEntity.visualBounds(recursive: true, relativeTo: pigEntity)
        let pigWorldTransform = pigEntity.transformMatrix(relativeTo: nil)

        return makeObservation(
            captureFrame: {
                guard let frame = arView.session.currentFrame else { return nil }
                return RealityOcclusionFrameSnapshot(
                    timestamp: frame.timestamp,
                    cameraTransform: frame.camera.transform,
                    viewportBounds: arView.bounds,
                    interfaceOrientation: arView.window?.windowScene?.interfaceOrientation ?? .unknown
                )
            },
            localBoundsMinimum: localBounds.min,
            localBoundsMaximum: localBounds.max,
            pigWorldTransform: pigWorldTransform,
            project: { worldPoint, _ in
                arView.project(worldPoint)
            },
            sceneUnderstandingHit: { screenPoint in
                arView.hitTest(
                    screenPoint,
                    query: .nearest,
                    mask: .sceneUnderstanding
                ).first?.position
            }
        )
    }

    func makeObservation(
        captureFrame: () -> RealityOcclusionFrameSnapshot?,
        localBoundsMinimum: SIMD3<Float>,
        localBoundsMaximum: SIMD3<Float>,
        pigWorldTransform: simd_float4x4,
        project: (SIMD3<Float>, UIInterfaceOrientation) -> CGPoint?,
        sceneUnderstandingHit: (CGPoint) -> SIMD3<Float>?
    ) -> RealityOcclusionObservation? {
        guard let frame = captureFrame() else { return nil }

        let cameraPose = Self.cameraPose(from: frame.cameraTransform)
        guard frame.timestamp.isFinite else { return nil }
        guard let cameraPose,
              frame.interfaceOrientation != .unknown,
              !frame.viewportBounds.isEmpty,
              let corners = Self.worldBoundsCorners(
                localMinimum: localBoundsMinimum,
                localMaximum: localBoundsMaximum,
                worldTransform: pigWorldTransform
              ),
              let cameraRight = Self.direction(column: frame.cameraTransform.columns.0),
              let cameraUp = Self.direction(column: frame.cameraTransform.columns.1),
              let samplePoints = PigOcclusionSampler.samples(
                boundsCorners: corners,
                cameraRight: cameraRight,
                cameraUp: cameraUp
              ) else {
            return RealityOcclusionObservation(
                frameTimestamp: frame.timestamp,
                samples: Self.invalidSamples,
                cameraPose: cameraPose
            )
        }

        let samples = Dictionary(uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { sampleID in
            guard let worldPoint = samplePoints[sampleID],
                  let screenPoint = project(worldPoint, frame.interfaceOrientation),
                  screenPoint.x.isFinite,
                  screenPoint.y.isFinite,
                  RealityProjectionGate.canObserve(
                    projectedPoint: screenPoint,
                    viewportBounds: frame.viewportBounds,
                    pigPosition: worldPoint,
                    cameraTransform: frame.cameraTransform
                  ) else {
                return (sampleID, OcclusionSampleState.invalid)
            }

            let pigDistance = simd_distance(cameraPose.position, worldPoint)
            let meshDistance = sceneUnderstandingHit(screenPoint).map {
                simd_distance(cameraPose.position, $0)
            }
            return (
                sampleID,
                OcclusionSampleState.classify(
                    pigDistance: pigDistance,
                    meshDistance: meshDistance
                )
            )
        })

        return RealityOcclusionObservation(
            frameTimestamp: frame.timestamp,
            samples: samples,
            cameraPose: cameraPose
        )
    }

    static func worldBoundsCorners(
        localMinimum: SIMD3<Float>,
        localMaximum: SIMD3<Float>,
        worldTransform: simd_float4x4
    ) -> [SIMD3<Float>]? {
        guard localMinimum.allFinite,
              localMaximum.allFinite,
              worldTransform.allFinite,
              localMinimum.x < localMaximum.x,
              localMinimum.y < localMaximum.y,
              localMinimum.z < localMaximum.z else {
            return nil
        }

        var corners: [SIMD3<Float>] = []
        for x in [localMinimum.x, localMaximum.x] {
            for y in [localMinimum.y, localMaximum.y] {
                for z in [localMinimum.z, localMaximum.z] {
                    let transformed = worldTransform * SIMD4<Float>(x, y, z, 1)
                    guard transformed.x.isFinite,
                          transformed.y.isFinite,
                          transformed.z.isFinite,
                          transformed.w.isFinite,
                          abs(transformed.w) > 0.000_001 else {
                        return nil
                    }
                    corners.append(SIMD3(transformed.x, transformed.y, transformed.z) / transformed.w)
                }
            }
        }
        return corners
    }

    private static var invalidSamples: [PigOcclusionSampleID: OcclusionSampleState] {
        Dictionary(uniqueKeysWithValues: PigOcclusionSampleID.allCases.map { ($0, .invalid) })
    }

    private static func cameraPose(from transform: simd_float4x4) -> RealityCameraPose? {
        guard transform.allFinite,
              let position = Self.position(from: transform),
              let forwardColumn = Self.direction(column: transform.columns.2) else {
            return nil
        }
        return RealityCameraPose(position: position, forward: -forwardColumn)
    }

    private static func position(from transform: simd_float4x4) -> SIMD3<Float>? {
        let value = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        return value.allFinite ? value : nil
    }

    private static func direction(column: SIMD4<Float>) -> SIMD3<Float>? {
        let value = SIMD3(column.x, column.y, column.z)
        guard value.allFinite else { return nil }
        let lengthSquared = simd_length_squared(value)
        guard lengthSquared.isFinite, lengthSquared > 0.000_001 else { return nil }
        return value / sqrt(lengthSquared)
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

private extension simd_float4x4 {
    var allFinite: Bool {
        columns.0.x.isFinite && columns.0.y.isFinite && columns.0.z.isFinite && columns.0.w.isFinite
            && columns.1.x.isFinite && columns.1.y.isFinite && columns.1.z.isFinite && columns.1.w.isFinite
            && columns.2.x.isFinite && columns.2.y.isFinite && columns.2.z.isFinite && columns.2.w.isFinite
            && columns.3.x.isFinite && columns.3.y.isFinite && columns.3.z.isFinite && columns.3.w.isFinite
    }
}
