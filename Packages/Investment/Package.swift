// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Investment",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Investment", targets: ["Investment"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Investment",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
