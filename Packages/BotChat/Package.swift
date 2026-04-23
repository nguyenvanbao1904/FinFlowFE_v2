// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BotChat",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "BotChat", targets: ["BotChat"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "BotChat",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
