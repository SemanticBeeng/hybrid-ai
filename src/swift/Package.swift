// swift-tools-version: 5.9
import Foundation
import PackageDescription

var products: [Product] = [
    .library(name: "HybridAI", targets: ["HybridAI"]),
    .executable(name: "hybrid-ai-cli", targets: ["HybridAICLI"])
]

var targets: [Target] = [
    .target(name: "HybridAI"),
    .executableTarget(name: "HybridAICLI", dependencies: ["HybridAI"]),
    .testTarget(name: "HybridAITests", dependencies: ["HybridAI"])
]

#if os(Linux)
if ProcessInfo.processInfo.environment["HYBRID_AI_ENABLE_GTK_UI"] == "1" {
products.append(.executable(name: "hybrid-ai-mobile-chat", targets: ["HybridAIMobileChat"]))

targets.append(contentsOf: [
    .systemLibrary(
        name: "CGTK",
        pkgConfig: "gtk4"
    ),
    .systemLibrary(
        name: "CAdwaita",
        pkgConfig: "libadwaita-1"
    ),
    .target(
        name: "CHybridAIMobileChat",
        dependencies: ["CGTK", "CAdwaita"],
        publicHeadersPath: "include"
    ),
    .executableTarget(
        name: "HybridAIMobileChat",
        dependencies: ["HybridAI", "CHybridAIMobileChat"]
    )
])
}
#endif

let package = Package(
    name: "HybridAI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: products,
    targets: targets
)
