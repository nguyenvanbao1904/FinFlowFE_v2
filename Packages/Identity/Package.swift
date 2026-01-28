// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Identity",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Identity", targets: ["Identity"]),
    ],
    dependencies: [
        // Chỉ đường cho Identity tìm sang FinFlowCore
        .package(path: "../FinFlowCore"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.1.0"),
    ],
    targets: [
        .target(
            name: "Identity",
            dependencies: [
                // Khai báo Identity phụ thuộc vào FinFlowCore
                .product(name: "FinFlowCore", package: "FinFlowCore"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
                
            ]
        )
    ]
)
