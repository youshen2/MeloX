// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioStreaming",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [.library(name: "AudioStreaming", targets: ["AudioStreaming"])],
    targets: [
        .target(name: "AudioStreaming"),
        .testTarget(name: "AudioStreamingTests", dependencies: ["AudioStreaming"], resources: [.copy("Fixtures")]),
    ]
)
