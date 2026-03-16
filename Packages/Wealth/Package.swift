// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Wealth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Wealth", targets: ["Wealth"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Wealth",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
