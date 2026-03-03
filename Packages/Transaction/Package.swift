// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Transaction",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Transaction", targets: ["Transaction"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Transaction",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
