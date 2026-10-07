// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ActionsBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ActionsBar", path: "Sources/ActionsBar")
    ]
)
