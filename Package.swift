// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScanIDCard",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ScanIDCard",
            targets: ["ScanIDCard"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ScanIDCard",
            dependencies: [],
            resources: [
                // Include resources like .xib files if necessary
                .process("ScanImageViewController.xib"),
                .process("CropperViewController.xib")
            ]),

    ]
)
