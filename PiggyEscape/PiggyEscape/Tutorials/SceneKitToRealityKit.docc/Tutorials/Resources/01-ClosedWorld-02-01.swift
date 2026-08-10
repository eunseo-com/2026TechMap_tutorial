import simd

enum LessonEscapeState {
    case openingNarration, readyForPigTap, walkingBehindTree, hiddenInClosedWorld
}

struct LessonEscapeMachine {
    private(set) var state: LessonEscapeState = .openingNarration

    mutating func narrationFinished() {
        guard state == .openingNarration else { return }
        state = .readyForPigTap
    }

    mutating func pigTapped() -> Bool {
        guard state == .readyForPigTap else { return false }
        state = .walkingBehindTree
        return true
    }

    mutating func pigReachedTree() {
        guard state == .walkingBehindTree else { return }
        state = .hiddenInClosedWorld
    }
}

enum LessonTreeHidePlanner {
    static func destination(
        treeCenter: SIMD3<Float>,
        treeRadius: Float,
        cameraPosition: SIMD3<Float>,
        pigRadius: Float,
        floorY: Float
    ) -> SIMD3<Float> {
        let horizontalCamera = SIMD3(
            cameraPosition.x - treeCenter.x,
            0,
            cameraPosition.z - treeCenter.z
        )
        let direction = simd_length_squared(horizontalCamera) > 0.0001
            ? simd_normalize(horizontalCamera)
            : SIMD3<Float>(0, 0, 1)
        let distance = treeRadius + pigRadius + 0.08
        return SIMD3(
            treeCenter.x - direction.x * distance,
            floorY,
            treeCenter.z - direction.z * distance
        )
    }
}
