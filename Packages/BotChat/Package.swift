// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BotChat",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "BotChat", targets: ["BotChat"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
    ],
    targets: [
        .target(
            name: "BotChat",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ]
        )
    ]
)
