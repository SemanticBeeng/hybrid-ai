// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HybridAI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "HybridAI", targets: ["HybridAI"]),
        .executable(name: "hybrid-ai-cli", targets: ["HybridAICLI"])
    ],
    targets: [
        .target(name: "HybridAI"),
        .executableTarget(name: "HybridAICLI", dependencies: ["HybridAI"]),
        .testTarget(name: "HybridAITests", dependencies: ["HybridAI"])
    ]
)
