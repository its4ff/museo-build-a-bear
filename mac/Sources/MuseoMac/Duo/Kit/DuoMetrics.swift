import SwiftUI

/// The mac's measures for the duo. Pointer sized: a step under the iphone's finger sizes,
/// the same proportions. Every team reads these instead of writing its own numbers.
nonisolated enum DuoMetrics {
    // MARK: The window

    /// The main window, in points (today's library window).
    static let window = CGSize(width: 1080, height: 720)
    /// From the window's edge to the corner and to search.
    static let margin: CGFloat = MuseSpacing.lg
    /// The top strip the three window dots sit in; content may run under it.
    static let chromeHeight: CGFloat = 38
    /// One window dot, and the gap between two.
    static let chromeDot: CGFloat = 12
    static let chromeGap: CGFloat = MuseSpacing.xs
    /// How much ink a quiet window dot carries.
    static let chromeInk: Double = 0.18

    // MARK: The corner

    /// The pill's, the cluster's and a glass circle's height (the iphone's is 52).
    static let bar: CGFloat = 42
    /// The pill's halftone mark, its cells across, and the most streaming words it offers.
    static let pillMark: CGFloat = 22
    static let pillMarkDots = 21
    static let pillWords = 14
    /// The corner's one width: the pill and the cluster share it.
    static let cornerWidth: CGFloat = 252
    /// Between the pill and the cluster.
    static let cornerGap: CGFloat = MuseSpacing.xs
    /// The whole corner's height: pill, gap, cluster.
    static let cornerHeight: CGFloat = bar * 2 + cornerGap
    /// Room a page leaves at its foot so its last row clears the corner.
    static let cornerRoom: CGFloat = cornerHeight + margin * 2
    /// Around the cluster's buttons.
    static let clusterInset: CGFloat = MuseSpacing.xxs
    /// A place's glyph, and a symbol inside any glass control.
    static let symbol: CGFloat = 15

    // MARK: The fade at the window's foot

    /// Solid dune up to here, measured from the bottom.
    static let fadeSolid: CGFloat = margin + bar
    /// Then gone by here.
    static let fadeEnd: CGFloat = cornerRoom + MuseSpacing.section

    // MARK: Rows and tiles

    /// A thought row's title, in Lora.
    static let rowTitle: CGFloat = 16
    /// A tile's height in a mac grid, and its title.
    static let tileHeight: CGFloat = 132
    static let tileTitle: CGFloat = 18
    /// The foot's dot.
    static let footDot: CGFloat = 6

    // MARK: The listen capsule

    static let wave: CGFloat = 22
    static let waveDot: CGFloat = 2.5
    static let waveGap: CGFloat = 2.5
    /// The play glyph.
    static let play: CGFloat = 14
}
