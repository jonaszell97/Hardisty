// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hardisty",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Hardisty",
            targets: ["Hardisty"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jonaszell97/Keystone.git", from: "0.1.0"),
        .package(url: "https://github.com/jonaszell97/Uncharted.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "Hardisty",
            dependencies: ["Keystone", "Uncharted"]),
        .testTarget(
            name: "HardistyTests",
            dependencies: ["Hardisty", "Keystone", "Uncharted"]),
    ]
)
