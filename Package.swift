// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "beeMon",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "beeMon",
            path: "Sources/beeMon",
            exclude: ["Info.plist"]
        )
    ]
)
