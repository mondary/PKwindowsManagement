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
    dependencies: [
        // Auto-updates (appcast + EdDSA signatures). The SPM product is the
        // statically linked variant: no framework embedding, no XPC needed.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "PKwindowsManagement",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "src/macos",
            resources: [.process("Resources")]
        )
    ]
)
