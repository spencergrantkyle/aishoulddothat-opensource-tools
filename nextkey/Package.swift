// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NextKey",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NextKey",
            path: "Sources/NextKey",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        )
    ]
)
