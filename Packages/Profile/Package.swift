// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Profile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Profile", targets: ["Profile"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore"),
        .package(path: "../Identity")
    ],
    targets: [
        .target(
            name: "Profile",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore"),
                .product(name: "Identity", package: "Identity")
            ]
        )
    ]
)
