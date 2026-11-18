#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import SwiftUI

/// The colors the pocket mock needs that `MuseColor` doesn't carry yet (museo dune has them
/// as tokens). Each is mixed from house tokens, so there are no literal components here;
/// the one exception is `chargeGreen`, which leans on the system green for its freshness.
/// If these ship, they move into `MuseColor` with dune's exact values.
nonisolated enum PocketColor {
    // MARK: The dune's pools

    /// Top left.
    static let duneSage = MuseColor.moss300.mix(with: MuseColor.mossTint, by: 0.25)
    /// Top right.
    static let duneSand = MuseColor.ochre.mix(with: MuseColor.ochreTint, by: 0.5)
    /// Bottom right.
    static let duneOchre = MuseColor.ochre
    /// Bottom left.
    static let duneMoss = MuseColor.moss300.mix(with: MuseColor.moss600, by: 0.3)
    /// The grain's dark specks.
    static let duneUmber = MuseColor.ochreInk.mix(with: MuseColor.ink, by: 0.4)
    /// The grain's light specks.
    static let duneCream = MuseColor.composer.mix(with: MuseColor.ochreTint, by: 0.45)

    // MARK: The ring pill's fills

    /// Memory: where the amber sweep starts.
    static let pillAmber = MuseColor.ringAmber.mix(with: MuseColor.ochreTint, by: 0.18, in: .device)
    /// Memory: where it ends.
    static let pillAmberGlow = MuseColor.ringAmber.mix(with: MuseColor.ochreTint, by: 0.6, in: .device)
    /// Streaming, and the capsule under a level fill: warm off-white.
    static let pillPaper = MuseColor.composer.mix(with: MuseColor.raised, by: 0.6)
    /// Charging: a fresh green behind ink.
    static let chargeGreen = MuseColor.mossTint.mix(with: Color.green, by: 0.24)
    /// Bringing in: the moss that rises.
    static let bringMoss = MuseColor.mossTint.mix(with: MuseColor.moss300, by: 0.45)

    // MARK: Glass

    /// The warm tint a glass tile carries, so it reads as paper the dune shows through.
    static let tileTint = MuseColor.raised.opacity(0.42)
    /// The light edge on glass and on the moss pill.
    static let glassEdge = MuseColor.composer.opacity(0.6)
    /// The halftone ring's ink on the moss.
    static let printSand = MuseColor.ground.mix(with: MuseColor.ochreTint, by: 0.5)
}
#endif
