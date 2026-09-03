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
            infoPlist: .extendingDefault(with: [
                "NSCameraUsageDescription": "피기가 현실의 물체 뒤에 숨을 수 있도록 카메라를 사용합니다.",
                "UILaunchScreen": .dictionary([:])
            ]),
            sources: ["PiggyEscape/Sources/**"],
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
