import XCTest
import simd
@testable import PiggyEscape

final class PigOcclusionSamplerTests: XCTestCase {
    func test_rotatedBoundsUseEightyPercentCameraSpaceSupportForFiveDistinctSamples() {
        let center = SIMD3<Float>(10, 2, -3)
        let localRight = simd_normalize(SIMD3<Float>(1, 0, 1))
        let localUp = SIMD3<Float>(0, 1, 0)
        let localDepth = simd_normalize(SIMD3<Float>(-1, 0, 1))
        let corners = makeCorners(
            center: center,
            axes: (localRight * 0.5, localUp, localDepth * 0.25)
        )

        let samples = PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: localRight,
            cameraUp: localUp
        )

        XCTAssertVectorEqual(samples?[.center], center)
        XCTAssertVectorEqual(samples?[.left], center - localRight * 0.4)
        XCTAssertVectorEqual(samples?[.right], center + localRight * 0.4)
        XCTAssertVectorEqual(samples?[.top], center + localUp * 0.8)
        XCTAssertVectorEqual(samples?[.bottom], center - localUp * 0.8)
        XCTAssertNotEqual(samples?[.left], samples?[.right])
    }

    func test_cameraRightChangesWhichRotatedBoundsSupportDefinesLeftAndRight() {
        let center = SIMD3<Float>(1, 1, 1)
        let wideAxis = simd_normalize(SIMD3<Float>(1, 0, 1)) * 0.6
        let depthAxis = simd_normalize(SIMD3<Float>(-1, 0, 1)) * 0.2
        let corners = makeCorners(
            center: center,
            axes: (wideAxis, SIMD3<Float>(0, 0.5, 0), depthAxis)
        )

        let wideView = PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: simd_normalize(wideAxis),
            cameraUp: SIMD3<Float>(0, 1, 0)
        )
        let depthView = PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: simd_normalize(depthAxis),
            cameraUp: SIMD3<Float>(0, 1, 0)
        )

        XCTAssertVectorEqual(wideView?[.left], center - wideAxis * 0.8)
        XCTAssertVectorEqual(wideView?[.right], center + wideAxis * 0.8)
        XCTAssertVectorEqual(depthView?[.left], center - depthAxis * 0.8)
        XCTAssertVectorEqual(depthView?[.right], center + depthAxis * 0.8)
        XCTAssertNotEqual(wideView?[.left], depthView?[.left])
    }

    func test_samplerRejectsAnythingOtherThanEightFiniteNondegenerateCorners() {
        let valid = makeCorners(
            center: .zero,
            axes: (
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 1)
            )
        )
        var nonFinite = valid
        nonFinite[3].z = .infinity
        let flat = Array(repeating: SIMD3<Float>(0, 0, 0), count: 8)

        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: Array(valid.dropLast()),
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: nonFinite,
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: flat,
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
    }

    func test_samplerRejectsEightUniqueCornersThatOnlySpanARotatedPlane() {
        let planeRight = simd_normalize(SIMD3<Float>(1, 1, 0))
        let planeUp = simd_normalize(SIMD3<Float>(-1, 1, 2))
        let coefficients: [(Float, Float)] = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1),
        ]
        let corners = coefficients.map { right, up in
            planeRight * right + planeUp * up
        }

        XCTAssertEqual(Set(corners).count, 8)
        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
    }

    func test_samplerRejectsDuplicateCornerEvenWhenWorldExtentsAndRankRemainNonzero() {
        var corners = makeCorners(
            center: .zero,
            axes: (
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 1)
            )
        )
        corners[7] = corners[6]

        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
    }

    func test_samplerRejectsNonFiniteZeroLengthAndParallelCameraBasis() {
        let corners = makeCorners(
            center: .zero,
            axes: (
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 1)
            )
        )

        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: SIMD3<Float>(.nan, 0, 0),
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: .zero,
            cameraUp: SIMD3<Float>(0, 1, 0)
        ))
        XCTAssertNil(PigOcclusionSampler.samples(
            boundsCorners: corners,
            cameraRight: SIMD3<Float>(1, 0, 0),
            cameraUp: SIMD3<Float>(2, 0, 0)
        ))
    }
}

final class OcclusionSampleStateTests: XCTestCase {
    func test_onlyMeshMoreThanThreeCentimetersBeforePigIsBlocked() {
        let margin = OcclusionSampleState.meshSafetyMargin

        XCTAssertEqual(
            OcclusionSampleState.classify(pigDistance: 1 + margin + 0.001, meshDistance: 1),
            .blocked
        )
        XCTAssertEqual(
            OcclusionSampleState.classify(pigDistance: 1 + margin, meshDistance: 1),
            .visible
        )
        XCTAssertEqual(
            OcclusionSampleState.classify(pigDistance: 1 + margin - 0.001, meshDistance: 1),
            .visible
        )
        XCTAssertEqual(
            OcclusionSampleState.classify(pigDistance: 1, meshDistance: 1.2),
            .visible,
            "a hit behind the pig sample must not occlude it"
        )
        XCTAssertEqual(
            OcclusionSampleState.classify(pigDistance: 1, meshDistance: nil),
            .visible
        )
    }

    func test_missingOrNonFinitePigAndNonFiniteMeshDistancesAreInvalid() {
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: nil, meshDistance: nil), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: .nan, meshDistance: nil), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: .infinity, meshDistance: 1), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: 1, meshDistance: .nan), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: 1, meshDistance: .infinity), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: -1, meshDistance: nil), .invalid)
        XCTAssertEqual(OcclusionSampleState.classify(pigDistance: 1, meshDistance: -0.1), .invalid)
    }

    func test_strictMarginUsesFiniteSubtractionInsteadOfRoundedAddition() {
        let meshDistance = Float(bitPattern: 0x3e99_999a)
        let pigDistance = Float(bitPattern: 0x3ea8_f5c3)
        let difference = pigDistance - meshDistance

        XCTAssertFalse(pigDistance > meshDistance + OcclusionSampleState.meshSafetyMargin)
        XCTAssertGreaterThan(difference, OcclusionSampleState.meshSafetyMargin)
        XCTAssertTrue(difference.isFinite)
        XCTAssertEqual(
            OcclusionSampleState.classify(
                pigDistance: pigDistance,
                meshDistance: meshDistance
            ),
            .blocked
        )
    }
}

final class StableHideMonitorTests: XCTestCase {
    func test_hideRequiresAllFiveValidCenterBlockedAndFourBlockedOnTwoUniqueFrames() {
        var monitor = StableHideMonitor(startTime: 10)
        let firstPose = pose(position: .zero)
        let secondPose = pose(position: SIMD3<Float>(0.01, 0, 0))

        XCTAssertEqual(
            monitor.update(
                observation(timestamp: 1, states: hiddenCandidate(), pose: firstPose),
                now: 10.1
            ),
            .waiting
        )
        XCTAssertEqual(
            monitor.update(
                observation(timestamp: 2, states: hiddenCandidate(), pose: secondPose),
                now: 10.2
            ),
            .hidden(referencePose: secondPose),
            "the second successful observation pose is the reveal reference"
        )
        XCTAssertEqual(
            monitor.update(
                observation(timestamp: 3, states: hiddenCandidate(), pose: secondPose),
                now: 10.3
            ),
            .waiting,
            "hide completion must emit once"
        )
    }

    func test_duplicateAndOlderTimestampsAreIgnoredWithoutConsumingOrResettingStability() {
        var monitor = StableHideMonitor(startTime: 0)
        let pose = pose(position: .zero)

        XCTAssertEqual(monitor.update(
            observation(timestamp: 4, states: hiddenCandidate(), pose: pose),
            now: 0.1
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 4, states: visibleStates(), pose: pose),
            now: 0.2
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 3, states: visibleStates(), pose: pose),
            now: 0.3
        ), .waiting)

        XCTAssertEqual(monitor.uniqueFrameCount, 1)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 5, states: hiddenCandidate(), pose: pose),
            now: 0.4
        ), .hidden(referencePose: pose))
        XCTAssertEqual(monitor.uniqueFrameCount, 2)
    }

    func test_invalidThreeOfFiveAndCenterVisibleObservationsEachResetHideStreak() {
        let resetStates: [[PigOcclusionSampleID: OcclusionSampleState]] = [
            states(center: .blocked, top: .blocked, bottom: .blocked, left: .blocked, right: .invalid),
            states(center: .blocked, top: .blocked, bottom: .blocked, left: .visible, right: .visible),
            states(center: .visible, top: .blocked, bottom: .blocked, left: .blocked, right: .blocked),
        ]
        let pose = pose(position: .zero)

        for (index, resetState) in resetStates.enumerated() {
            var monitor = StableHideMonitor(startTime: 0)
            XCTAssertEqual(monitor.update(
                observation(timestamp: 1, states: hiddenCandidate(), pose: pose),
                now: 0.1
            ), .waiting)
            XCTAssertEqual(monitor.update(
                observation(timestamp: 2, states: resetState, pose: pose),
                now: 0.2
            ), .waiting, "reset fixture \(index) must not hide")
            XCTAssertEqual(monitor.update(
                observation(timestamp: 3, states: hiddenCandidate(), pose: pose),
                now: 0.3
            ), .waiting, "reset fixture \(index) must discard the earlier candidate")
            XCTAssertEqual(monitor.update(
                observation(timestamp: 4, states: hiddenCandidate(), pose: pose),
                now: 0.4
            ), .hidden(referencePose: pose))
        }
    }

    func test_missingSampleOrInvalidCameraPoseInvalidatesWholeHideObservation() {
        var missingSample = hiddenCandidate()
        missingSample[.right] = nil
        let validPose = pose(position: .zero)
        let invalidPose = RealityCameraPose(position: .zero, forward: .zero)
        var monitor = StableHideMonitor(startTime: 0)

        XCTAssertEqual(monitor.update(
            observation(timestamp: 1, states: hiddenCandidate(), pose: validPose),
            now: 0.1
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 2, states: missingSample, pose: validPose),
            now: 0.2
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 3, states: hiddenCandidate(), pose: invalidPose),
            now: 0.3
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 4, states: hiddenCandidate(), pose: validPose),
            now: 0.4
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 5, states: hiddenCandidate(), pose: validPose),
            now: 0.5
        ), .hidden(referencePose: validPose))
    }

    func test_sixtiethUniqueFrameIsEvaluatedAndCanCompleteHide() {
        var monitor = StableHideMonitor(startTime: 0)
        let pose = pose(position: .zero)

        for frame in 1...58 {
            XCTAssertEqual(monitor.update(
                observation(timestamp: TimeInterval(frame), states: visibleStates(), pose: pose),
                now: Double(frame) / 100
            ), .waiting)
        }
        XCTAssertEqual(monitor.update(
            observation(timestamp: 59, states: hiddenCandidate(), pose: pose),
            now: 0.59
        ), .waiting)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 60, states: hiddenCandidate(), pose: pose),
            now: 0.60
        ), .hidden(referencePose: pose))
        XCTAssertEqual(monitor.uniqueFrameCount, 60)
    }

    func test_failedSixtiethFrameExhaustsAndSixtyFirstFrameIsNotProcessed() {
        var monitor = StableHideMonitor(startTime: 0)
        let pose = pose(position: .zero)

        for frame in 1...59 {
            XCTAssertEqual(monitor.update(
                observation(timestamp: TimeInterval(frame), states: visibleStates(), pose: pose),
                now: Double(frame) / 100
            ), .waiting)
        }
        XCTAssertEqual(monitor.update(
            observation(timestamp: 60, states: visibleStates(), pose: pose),
            now: 0.60
        ), .exhausted)
        XCTAssertEqual(monitor.update(
            observation(timestamp: 61, states: hiddenCandidate(), pose: pose),
            now: 0.61
        ), .waiting)
        XCTAssertEqual(monitor.uniqueFrameCount, 60)
    }

    func test_frameAtOrAfterDeadlineIsExcludedButFrameBeforeDeadlineIsEvaluated() {
        let pose = pose(position: .zero)
        var canFinish = StableHideMonitor(startTime: 20)
        XCTAssertEqual(canFinish.update(
            observation(timestamp: 1, states: hiddenCandidate(), pose: pose),
            now: 21.49
        ), .waiting)
        XCTAssertEqual(canFinish.update(
            observation(timestamp: 2, states: hiddenCandidate(), pose: pose),
            now: 21.499
        ), .hidden(referencePose: pose))

        var excluded = StableHideMonitor(startTime: 20)
        XCTAssertEqual(excluded.update(
            observation(timestamp: 1, states: hiddenCandidate(), pose: pose),
            now: 21.49
        ), .waiting)
        XCTAssertEqual(excluded.update(
            observation(timestamp: 2, states: hiddenCandidate(), pose: pose),
            now: 21.5
        ), .exhausted)
        XCTAssertEqual(excluded.uniqueFrameCount, 1)
    }

    func test_deadlineCanExhaustWithoutAnotherSceneFrame() {
        var monitor = StableHideMonitor(startTime: 5)

        XCTAssertEqual(monitor.deadlineElapsed(at: 6.49), .waiting)
        XCTAssertEqual(monitor.deadlineElapsed(at: 6.5), .exhausted)
        XCTAssertEqual(monitor.deadlineElapsed(at: 7), .waiting)
    }
}

final class RealityRevealMonitorObservationTests: XCTestCase {
    func test_exactTranslationLatchesAndTwoUniqueThreeOfFiveVisibleFramesDiscoverOnce() {
        let reference = pose(position: .zero)
        let exactMove = pose(position: SIMD3<Float>(0.15, 0, 0))
        var monitor = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(monitor.update(observation(
            timestamp: 1,
            states: revealedCandidateWithTwoBlocked(),
            pose: exactMove
        )))
        XCTAssertTrue(monitor.hasMeaningfulViewpointChange)
        XCTAssertTrue(monitor.update(observation(
            timestamp: 2,
            states: revealedCandidateWithTwoBlocked(),
            pose: reference
        )), "movement history must remain latched after returning")
        XCTAssertFalse(monitor.update(observation(
            timestamp: 3,
            states: revealedCandidateWithTwoBlocked(),
            pose: exactMove
        )), "discovery emits once")
    }

    func test_exactFifteenDegreeRotationLatchesMovement() {
        let angle: Float = .pi / 12
        let reference = pose(position: .zero)
        let exactTurn = RealityCameraPose(
            position: .zero,
            forward: SIMD3<Float>(sin(angle), 0, -cos(angle))
        )
        var monitor = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(monitor.update(observation(
            timestamp: 1,
            states: visibleStates(),
            pose: exactTurn
        )))
        XCTAssertTrue(monitor.hasMeaningfulViewpointChange)
        XCTAssertTrue(monitor.update(observation(
            timestamp: 2,
            states: visibleStates(),
            pose: exactTurn
        )))
    }

    func test_subthresholdTranslationAndRotationDoNotEnableReveal() {
        let reference = pose(position: .zero)
        let angle: Float = (.pi / 12) - 0.001
        var translation = RealityRevealMonitor(referencePose: reference)
        var rotation = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(translation.update(observation(
            timestamp: 1,
            states: visibleStates(),
            pose: pose(position: SIMD3<Float>(0.149, 0, 0))
        )))
        XCTAssertFalse(translation.update(observation(
            timestamp: 2,
            states: visibleStates(),
            pose: pose(position: SIMD3<Float>(0.149, 0, 0))
        )))
        XCTAssertFalse(translation.hasMeaningfulViewpointChange)

        let shortTurn = RealityCameraPose(
            position: .zero,
            forward: SIMD3<Float>(sin(angle), 0, -cos(angle))
        )
        XCTAssertFalse(rotation.update(observation(
            timestamp: 1,
            states: visibleStates(),
            pose: shortTurn
        )))
        XCTAssertFalse(rotation.update(observation(
            timestamp: 2,
            states: visibleStates(),
            pose: shortTurn
        )))
        XCTAssertFalse(rotation.hasMeaningfulViewpointChange)
    }

    func test_rotationTwoMillionthsOfARadianBelowThresholdDoesNotLatch() {
        let reference = pose(position: .zero)
        let angle = RealityRevealMonitor.minimumRotation - 0.000_002
        let shortTurn = RealityCameraPose(
            position: .zero,
            forward: SIMD3<Float>(sin(angle), 0, -cos(angle))
        )
        var monitor = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(monitor.update(observation(
            timestamp: 1,
            states: visibleStates(),
            pose: shortTurn
        )))
        XCTAssertFalse(monitor.update(observation(
            timestamp: 2,
            states: visibleStates(),
            pose: shortTurn
        )))
        XCTAssertFalse(monitor.hasMeaningfulViewpointChange)
    }

    func test_duplicateAndOlderRevealFramesDoNotAdvanceStability() {
        let reference = pose(position: .zero)
        let moved = pose(position: SIMD3<Float>(0.15, 0, 0))
        var monitor = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(monitor.update(observation(timestamp: 7, states: visibleStates(), pose: moved)))
        XCTAssertFalse(monitor.update(observation(timestamp: 7, states: visibleStates(), pose: moved)))
        XCTAssertFalse(monitor.update(observation(timestamp: 6, states: visibleStates(), pose: moved)))
        XCTAssertTrue(monitor.update(observation(timestamp: 8, states: visibleStates(), pose: moved)))
    }

    func test_invalidCenterBlockedAndFewerThanThreeVisibleEachResetOnlyRevealStreak() {
        let resetStates: [[PigOcclusionSampleID: OcclusionSampleState]] = [
            states(center: .visible, top: .visible, bottom: .visible, left: .visible, right: .invalid),
            states(center: .blocked, top: .visible, bottom: .visible, left: .visible, right: .visible),
            states(center: .visible, top: .visible, bottom: .blocked, left: .blocked, right: .blocked),
        ]
        let reference = pose(position: .zero)
        let moved = pose(position: SIMD3<Float>(0.15, 0, 0))

        for (index, resetState) in resetStates.enumerated() {
            var monitor = RealityRevealMonitor(referencePose: reference)
            XCTAssertFalse(monitor.update(observation(
                timestamp: 1,
                states: visibleStates(),
                pose: moved
            )))
            XCTAssertFalse(monitor.update(observation(
                timestamp: 2,
                states: resetState,
                pose: reference
            )), "reset fixture \(index) must not discover")
            XCTAssertTrue(monitor.hasMeaningfulViewpointChange, "reset must preserve movement latch")
            XCTAssertFalse(monitor.update(observation(
                timestamp: 3,
                states: visibleStates(),
                pose: reference
            )), "reset fixture \(index) must discard the earlier candidate")
            XCTAssertTrue(monitor.update(observation(
                timestamp: 4,
                states: visibleStates(),
                pose: reference
            )))
        }
    }

    func test_invalidObservationCanLatchMovementButCannotCountAsVisible() {
        let reference = pose(position: .zero)
        let moved = pose(position: SIMD3<Float>(0.15, 0, 0))
        var monitor = RealityRevealMonitor(referencePose: reference)

        XCTAssertFalse(monitor.update(observation(
            timestamp: 1,
            states: states(
                center: .invalid,
                top: .invalid,
                bottom: .invalid,
                left: .invalid,
                right: .invalid
            ),
            pose: moved
        )))
        XCTAssertTrue(monitor.hasMeaningfulViewpointChange)
        XCTAssertFalse(monitor.update(observation(timestamp: 2, states: visibleStates(), pose: reference)))
        XCTAssertTrue(monitor.update(observation(timestamp: 3, states: visibleStates(), pose: reference)))
    }

    func test_secondSuccessfulHidePoseIsTheOnlyRevealReference() {
        let firstPose = pose(position: .zero)
        let secondPose = pose(position: SIMD3<Float>(0.15, 0, 0))
        var hide = StableHideMonitor(startTime: 0)

        XCTAssertEqual(hide.update(
            observation(timestamp: 1, states: hiddenCandidate(), pose: firstPose),
            now: 0.1
        ), .waiting)
        let result = hide.update(
            observation(timestamp: 2, states: hiddenCandidate(), pose: secondPose),
            now: 0.2
        )
        guard case let .hidden(referencePose) = result else {
            return XCTFail("expected stable hide")
        }

        var reveal = RealityRevealMonitor(referencePose: referencePose)
        XCTAssertFalse(reveal.update(observation(
            timestamp: 3,
            states: visibleStates(),
            pose: secondPose
        )))
        XCTAssertFalse(reveal.update(observation(
            timestamp: 4,
            states: visibleStates(),
            pose: secondPose
        )))
        XCTAssertFalse(reveal.hasMeaningfulViewpointChange)
    }
}

private func makeCorners(
    center: SIMD3<Float>,
    axes: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
) -> [SIMD3<Float>] {
    let signs: [Float] = [-1, 1]
    var corners: [SIMD3<Float>] = []
    for x in signs {
        for y in signs {
            for z in signs {
                let xOffset = axes.0 * x
                let yOffset = axes.1 * y
                let zOffset = axes.2 * z
                corners.append(center + xOffset + yOffset + zOffset)
            }
        }
    }
    return corners
}

private func pose(position: SIMD3<Float>) -> RealityCameraPose {
    RealityCameraPose(position: position, forward: SIMD3<Float>(0, 0, -1))
}

private func observation(
    timestamp: TimeInterval,
    states: [PigOcclusionSampleID: OcclusionSampleState],
    pose: RealityCameraPose?
) -> RealityOcclusionObservation {
    RealityOcclusionObservation(
        frameTimestamp: timestamp,
        samples: states,
        cameraPose: pose
    )
}

private func hiddenCandidate() -> [PigOcclusionSampleID: OcclusionSampleState] {
    states(center: .blocked, top: .blocked, bottom: .blocked, left: .blocked, right: .visible)
}

private func visibleStates() -> [PigOcclusionSampleID: OcclusionSampleState] {
    states(center: .visible, top: .visible, bottom: .visible, left: .visible, right: .visible)
}

private func revealedCandidateWithTwoBlocked() -> [PigOcclusionSampleID: OcclusionSampleState] {
    states(center: .visible, top: .visible, bottom: .visible, left: .blocked, right: .blocked)
}

private func states(
    center: OcclusionSampleState,
    top: OcclusionSampleState,
    bottom: OcclusionSampleState,
    left: OcclusionSampleState,
    right: OcclusionSampleState
) -> [PigOcclusionSampleID: OcclusionSampleState] {
    [
        .center: center,
        .top: top,
        .bottom: bottom,
        .left: left,
        .right: right,
    ]
}

private func XCTAssertVectorEqual(
    _ actual: SIMD3<Float>?,
    _ expected: SIMD3<Float>,
    accuracy: Float = 0.000_01,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let actual else {
        return XCTFail("expected vector \(expected), got nil", file: file, line: line)
    }
    XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, file: file, line: line)
}
