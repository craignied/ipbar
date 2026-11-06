// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ipbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ipbar", path: "Sources/ipbar")
    ]
)
