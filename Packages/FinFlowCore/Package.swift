// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FinFlowCore",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "FinFlowCore", targets: ["FinFlowCore"]),
    ],
    targets: [
        .target(
            name: "FinFlowCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
//        .testTarget(name: "FinFlowCoreTests", dependencies: ["FinFlowCore"]),
    ]
)
