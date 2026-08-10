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
        ),
        .testTarget(
            name: "beeMonTests",
            path: "Tests/beeMonTests"
            // No dependency on the executable target — tests are self-contained.
            // Pure Swift SPM executables cannot be linked as test dependencies.
            // All tested logic is re-implemented inline in the test file.
        )
    ]
)
