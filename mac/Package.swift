// swift-tools-version: 6.2
import PackageDescription

// museo for mac (experiment): a menu bar app. Hold the ring, and what you say is typed into
// the app in front. Every recording also lands in a small library on this mac.
//
// Builds against your local ../museo-kit on its `mac` branch, the one with macOS support.
// `scripts/mac.sh` builds it into mac/build/museo.app and opens it.

let package = Package(
    name: "MuseoMac",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(path: "../../museo-kit"),
    ],
    targets: [
        .executableTarget(
            name: "MuseoMac",
            dependencies: [
                .product(name: "MuseoKit", package: "museo-kit"),
            ],
            path: "Sources/MuseoMac",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
