// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Planning",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Planning", targets: ["Planning"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Planning",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
