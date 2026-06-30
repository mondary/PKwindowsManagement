// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PKwindowsManagement",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PKwindowsManagement", targets: ["PKwindowsManagement"])
    ],
    targets: [
        .executableTarget(
            name: "PKwindowsManagement",
            path: "Sources/PKwindowsManagement",
            resources: [.process("Resources")]
        )
    ]
)
