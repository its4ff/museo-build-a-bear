// swift-tools-version: 6.2
import PackageDescription

// museo for mac: a menu bar app. Hold the ring, and what you say is typed into the app in
// front. Every recording also lands in a small library on this mac.
//
// The ring is museo kit, pinned like the iphone app's (0.4.0 is the first with macOS).
// `scripts/mac.sh` builds it into mac/build/museo.app and opens it. Working on the kit itself?
// `swift package --package-path mac edit museo-kit --path ../museo-kit` builds against your
// own checkout; `swift package --package-path mac unedit museo-kit` goes back.

let package = Package(
    name: "MuseoMac",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/its4ff/museo-kit.git", exact: "0.4.0"),
        // Local speech models on the Neural Engine (Parakeet, Cohere Transcribe), downloaded
        // once from the panel. Apache 2.0. ASR only: no diarization or speech output.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.18.3", traits: []),
        // Updates without a new download: checks the appcast on 4ff.com, verifies the build
        // was signed with museo's own key, and swaps the app. MIT.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "MuseoMac",
            dependencies: [
                .product(name: "MuseoKit", package: "museo-kit"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "Sparkle", package: "Sparkle"),
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
