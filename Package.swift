// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "CoreGuard",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "CoreGuard",
            targets: ["CoreGuard"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CoreGuard",
            dependencies: [],
            path: "Sources",
            exclude: [
                "Info.plist",
                "CoreGuard.entitlements"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
                .linkedFramework("Combine")
            ]),
        .testTarget(
            name: "CoreGuardTests",
            dependencies: ["CoreGuard"],
            path: "Tests")
    ]
)
