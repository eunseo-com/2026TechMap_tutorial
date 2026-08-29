struct RealityCallbackToken: Equatable, Sendable {
    let experienceGeneration: Int
    let realityGeneration: Int
    let hideCycleGeneration: Int
}

struct EscapeExperienceLifetime {
    private(set) var currentToken = RealityCallbackToken(
        experienceGeneration: 0,
        realityGeneration: 0,
        hideCycleGeneration: 0
    )

    func accepts(_ token: RealityCallbackToken) -> Bool {
        token == currentToken
    }

    mutating func resetExperience() {
        currentToken = RealityCallbackToken(
            experienceGeneration: currentToken.experienceGeneration + 1,
            realityGeneration: currentToken.realityGeneration + 1,
            hideCycleGeneration: currentToken.hideCycleGeneration + 1
        )
    }

    mutating func beginNewRealitySession() {
        currentToken = RealityCallbackToken(
            experienceGeneration: currentToken.experienceGeneration,
            realityGeneration: currentToken.realityGeneration + 1,
            hideCycleGeneration: currentToken.hideCycleGeneration + 1
        )
    }

    mutating func beginNewHideCycle() {
        currentToken = RealityCallbackToken(
            experienceGeneration: currentToken.experienceGeneration,
            realityGeneration: currentToken.realityGeneration,
            hideCycleGeneration: currentToken.hideCycleGeneration + 1
        )
    }
}
