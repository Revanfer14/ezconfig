// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ezconfig",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        ),
        .package(
            url: "https://github.com/tuist/XcodeProj",
            from: "8.16.0"
        ),
        .package(
            url: "https://github.com/kylef/PathKit",
            from: "1.0.1"
        ),
    ],
    targets: [
        .target(
            name: "ezconfigKit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "PathKit", package: "PathKit"),
            ]
        ),
            .executableTarget(
                name: "ezconfig",
                dependencies: ["ezconfigKit"]
            ),
        .testTarget(
            name: "ezconfigTests",
            dependencies: ["ezconfigKit"]
        ),
    ]
)
