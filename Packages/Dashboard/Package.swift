// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Dashboard",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Dashboard", targets: ["Dashboard"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore"),
        .package(path: "../Identity")
    ],
    targets: [
        .target(
            name: "Dashboard",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore"),
                .product(name: "Identity", package: "Identity")
            ]
        )
    ]
)
