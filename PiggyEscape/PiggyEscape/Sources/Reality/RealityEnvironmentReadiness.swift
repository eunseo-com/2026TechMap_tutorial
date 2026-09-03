struct RealityScanProgress: Equatable {
    let hasMesh: Bool
    let hasClassifiedFloor: Bool

    static let empty = RealityScanProgress(
        hasMesh: false,
        hasClassifiedFloor: false
    )

    var isReady: Bool {
        hasMesh && hasClassifiedFloor
    }
}

struct RealityScanUpdate: Equatable {
    let progress: RealityScanProgress
    let becameReady: Bool
}

struct RealityScanPresentation: Equatable {
    let showsSceneUnderstanding: Bool
    let reduceMotion: Bool

    var showsAnimatedSweep: Bool {
        showsSceneUnderstanding && !reduceMotion
    }
}

struct RealityEnvironmentReadiness {
    private(set) var progress = RealityScanProgress.empty
    private var hasReportedReady = false

    var isReady: Bool {
        progress.isReady
    }

    mutating func observe(
        hasMesh: Bool,
        hasClassifiedFloor: Bool
    ) -> RealityScanUpdate? {
        let nextProgress = RealityScanProgress(
            hasMesh: progress.hasMesh || hasMesh,
            hasClassifiedFloor: progress.hasClassifiedFloor || hasClassifiedFloor
        )
        guard nextProgress != progress else { return nil }

        progress = nextProgress
        let becameReady = progress.isReady && !hasReportedReady
        if becameReady {
            hasReportedReady = true
        }
        return RealityScanUpdate(
            progress: progress,
            becameReady: becameReady
        )
    }

    @discardableResult
    mutating func observeMesh() -> Bool {
        observe(hasMesh: true, hasClassifiedFloor: false)?.becameReady ?? false
    }

    @discardableResult
    mutating func observeClassifiedFloor() -> Bool {
        observe(hasMesh: false, hasClassifiedFloor: true)?.becameReady ?? false
    }
}
