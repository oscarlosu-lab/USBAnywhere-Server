// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "USBAnywhereServerMac",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "usbanywhere-server-mac",
            targets: ["USBAnywhereServerMac"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "USBAnywhereServerMac",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .testTarget(
            name: "USBAnywhereServerMacTests",
            dependencies: ["USBAnywhereServerMac"],
            path: "Tests"
        )
    ]
)
