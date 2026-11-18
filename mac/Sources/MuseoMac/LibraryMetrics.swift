import SwiftUI

/// The library window's own measures: one sheet of paper on the dune with a margin of
/// thoughts. Everything else comes from `DuoMetrics`, `MuseSpacing` and `MuseRadius`.
nonisolated enum LibraryMetrics {
    // MARK: The sheet

    /// The margin of thoughts, left of the one hairline.
    static let margin: CGFloat = 302
    /// The margin's gutter: where its type starts and ends.
    static let gutter: CGFloat = MuseSpacing.xl
    /// How far a row's fill sits in from the margin's edges.
    static let rowInset: CGFloat = MuseSpacing.sm
    /// The row the traffic lights and the three glyphs share.
    static let chrome: CGFloat = 44
    /// The reading column, and the empty paper above its first line.
    static let measure: CGFloat = 620
    static let top: CGFloat = 108
    /// A hairline's weight.
    static let hair: CGFloat = 1
    /// The smallest the window goes: the margin and a narrow page.
    static let minWindow = CGSize(width: 860, height: 540)

    // MARK: Type

    /// The title, in Lora. Brave on purpose.
    static let title: CGFloat = 58
    static let titleTracking: CGFloat = -1.7
    /// Lora's own leading is loose at this size: pull the lines together.
    static let titleLeading: CGFloat = -6
    /// A long title steps down so it never takes the page.
    static let titleLong: CGFloat = 44
    static let titleLongTracking: CGFloat = -1.1
    static let titleLongAfter = 34
    /// The words, and the air between their lines.
    static let words: CGFloat = 21
    static let wordsLeading: CGFloat = 12
    /// A margin row's words.
    static let rowWords: CGFloat = 15
    static let rowLeading: CGFloat = 3
    /// A named note's first line, under its name.
    static let rowOpening: CGFloat = 12.5
    /// One of several picked muses, on their shared page.
    static let pickedWords: CGFloat = 17

    // MARK: Marks

    /// The amber dot on a ring recording not yet opened.
    static let dot: CGFloat = 6
    /// The small page mark before a note's line.
    static let noteMark: CGFloat = 9
    /// The search glyph.
    static let searchGlyph: CGFloat = 12
    /// The thin player line: its glyph, its hit box, the wave's height.
    static let play: CGFloat = 12
    static let playBox: CGFloat = 28
    static let wave: CGFloat = 22
    /// How much ink the part of the wave not yet played carries.
    static let waveRest: Double = 0.2

    // MARK: The actions

    /// The glass capsule top right, and one action in it.
    static let capsule: CGFloat = 40
    static let action = CGSize(width: 36, height: 34)
    static let actionSymbol: CGFloat = 14
    /// Its glyphs rest quiet and come up under the pointer. The glass itself stays.
    static let actionsRest: Double = 0.72

    // MARK: The palette

    static let palette: CGFloat = 520
    static let paletteField: CGFloat = 56
    static let paletteRow: CGFloat = 36
    static let paletteType: CGFloat = 17
    /// The most thoughts it offers for what you typed.
    static let paletteThoughts = 6
    /// The ink laid over the page behind it.
    static let veil: Double = 0.16
    /// How far above the middle it sits.
    static let paletteLift: CGFloat = 36

    // MARK: The margin's foot

    /// Room the list leaves for the ring pill, and how long it takes to run out above it.
    static let pillRoom: CGFloat = DuoMetrics.margin + DuoMetrics.bar + MuseSpacing.sm
    static let listFade: CGFloat = 56
    /// The list also softens as it slides under the search and filters.
    static let listRise: CGFloat = MuseSpacing.sm
    /// The ring popover.
    static let ringPopover: CGFloat = 300
}

/// The lines the library's pages share.
nonisolated enum LibraryWords {
    static let kept = "kept on this mac"
    static let museKeys = "⌘C copy · ⌘S save · ⌘⌫ delete · ⌘K go"
    static let noteKeys = "⌘O open · ⌘C copy · ⌘⌫ delete"
    static let pickedKeys = "⌘C copy all · ⌘⌫ delete · esc let go"
    static let search = "search everything you've said"
    static let palettePrompt = "search, or go…"
    static let paletteKeys = "↑↓ move · ↩ open · esc close"
}
