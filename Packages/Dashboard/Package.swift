// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Dashboard",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Dashboard", targets: ["Dashboard"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Dashboard",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
