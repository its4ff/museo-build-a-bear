#if DEBUG
import Foundation
import SwiftUI

/// Page's own measures: one sheet of paper with a margin of thoughts. Everything else
/// comes from `DuoMetrics`, `MuseSpacing` and `MuseRadius`.
nonisolated enum PageMetrics {
    // MARK: The sheet

    /// The margin of thoughts, left of the one hairline.
    static let margin: CGFloat = RoomMetrics.sidebar - RoomMetrics.inset
    /// The margin's gutter: where its type starts and ends.
    static let gutter: CGFloat = MuseSpacing.xl
    /// How far a selected row's fill sits in from the margin's edges.
    static let rowInset: CGFloat = MuseSpacing.sm
    /// The reading column.
    static let measure: CGFloat = RoomMetrics.measure
    /// Empty paper above the mono line.
    static let top: CGFloat = 108
    /// A hairline's weight.
    static let hair: CGFloat = 1

    // MARK: Type

    /// The title, in Lora. Brave on purpose.
    static let title: CGFloat = 58
    static let titleTracking: CGFloat = -1.7
    /// Lora's own leading is loose at this size: pull the lines together.
    static let titleLeading: CGFloat = -6
    /// The words, and the air between their lines.
    static let words: CGFloat = 21
    static let wordsLeading: CGFloat = 12
    /// Someone else's thought on museo.fm, set large.
    static let fmWords: CGFloat = 38
    static let fmLeading: CGFloat = 8
    static let fmTracking: CGFloat = -0.8
    /// A place's sentence under its name.
    static let sentence: CGFloat = 22
    /// A margin row's words, a place's name in the margin, a line in a typeset list.
    static let rowWords: CGFloat = 15
    static let rowLeading: CGFloat = 3
    static let placeName: CGFloat = 17
    static let listLine: CGFloat = 17

    // MARK: Marks

    /// The short moss rule beside the row you are on, and the reply's rule.
    static let rule: CGFloat = 2
    /// The amber dot on a ring recording not yet opened.
    static let dot: CGFloat = RoomMetrics.dot
    /// A glyph in the margin's top row, and its hit box.
    static let glyph: CGFloat = 13
    static let glyphBox: CGFloat = 28
    /// The thin player line: its glyph and the wave's height.
    static let play: CGFloat = 12
    static let wave: CGFloat = 22
    /// How much ink the wave carries.
    static let waveInk: Double = 0.55
    /// The when column in a typeset list.
    static let when: CGFloat = 116

    // MARK: The actions

    /// The capsule top right is Room's. At rest it is faint; under the pointer it comes back.
    static let actionsRest: Double = 0.58

    // MARK: The palette

    static let palette: CGFloat = 520
    static let paletteField: CGFloat = 56
    static let paletteRow: CGFloat = 36
    /// The ink laid over the page behind it, and how far the page softens.
    static let veil: Double = 0.16
    static let veilBlur: CGFloat = 0.4
    /// How far above the middle it sits.
    static let paletteLift: CGFloat = 36
    /// The caret in its field.
    static let caret: CGFloat = 20

    // MARK: The margin's foot

    /// Where the list has faded out, above the ring pill.
    static let pillRoom: CGFloat = DuoMetrics.margin + DuoMetrics.bar + MuseSpacing.sm
    static let listFade: CGFloat = 72
}

/// Which way the margin marks the row you are on.
nonisolated enum PageMark: Hashable, Sendable {
    /// The moss gradient fill, white words.
    case moss
    /// Full ink and a short moss rule at its left, on bare paper.
    case rule
}

/// The few made-up lines Page needs beyond `PocketFixtures`. Nobody's real words.
nonisolated enum PageFixtures {
    /// One line in a place's typeset list.
    nonisolated struct Line: Identifiable, Hashable, Sendable {
        let id: String
        let when: String
        let words: String
        let ink: PocketInk
    }

    /// How a line's send went, if the place sent it: matched by its words.
    static func send(for line: Line, in place: PocketPlace) -> PocketSend? {
        place.recentSends.first { $0.title == line.words }
    }

    /// What claude holds: everything said after "for claude".
    static let claudeLines: [Line] = [
        Line(id: "a", when: "today · 9:12a", words: "for claude, book the dentist thursday", ink: .full),
        Line(id: "b", when: "yesterday · 5:02p", words: "for claude, find the heavier card stock", ink: .receding),
        Line(id: "c", when: "yesterday · 11:20a", words: "for claude, what was the name of that bakery", ink: .receding),
        Line(id: "d", when: "sunday · 4:45p", words: "for claude, how long does a heron stand still", ink: .far),
    ]

    /// The palette's two quiet groups.
    nonisolated struct Result: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        var note: String?
        /// The one clay mark: this one is public.
        var isPublic = false
        /// The keys that go there without the palette.
        var keys: String?
    }

    static let sendTo: [Result] = [
        Result(id: "claude", name: "claude", note: "an agent"),
        Result(id: "journal", name: "journal", note: "files"),
        Result(id: "fm", name: "museo.fm", note: "public", isPublic: true),
    ]

    static let goTo: [Result] = [
        Result(id: "yours", name: "your thoughts", keys: "⌘1"),
        Result(id: "places", name: "places", keys: "⌘2"),
        Result(id: "gofm", name: "museo.fm", keys: "⌘3"),
        Result(id: "words", name: "your words", keys: "⌘,"),
    ]
}
#endif
