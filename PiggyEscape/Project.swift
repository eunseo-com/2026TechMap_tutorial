import ProjectDescription

let project = Project(
    name: "PiggyEscape",
    targets: [
        .target(
            name: "PiggyEscape",
            destinations: .iOS,
            product: .app,
            bundleId: "com.techmap.piggyescape",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["PiggyEscape/Sources/**", "PiggyEscape/Tutorials/**"],
            resources: ["PiggyEscape/Resources/**"]
        ),
        .target(
            name: "PiggyEscapeTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.techmap.piggyescape.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["PiggyEscapeTests/**"],
            dependencies: [.target(name: "PiggyEscape")]
        )
    ]
)
