// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacClipboard",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacClipboard",
            path: "Sources/MacClipboard"
        )
    ]
)
