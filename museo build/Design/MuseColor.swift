import SwiftUI

// The linen palette.
//
// Five rules:
// 1. Linen. Every surface shares one warm hue; ink is a green-black, never neutral.
// 2. Green has three jobs: the orb, primary actions, and accents (counts, status dots, tags).
//    Never a content card.
// 3. Clay is consequence: delete, failed, nearly full. At most one clay mark per screen.
// 4. Lora speaks (their words, titles), Satoshi labels (buttons, times, counts).
// 5. Grain on the page wash only. Light mode only.
//
// Reach for a token by role, never by hex. If a color you need is missing, the screen
// probably wants a different surface, not a new color.

/// Every color in the app. Use these, never raw hex or RGB initializers.
nonisolated enum MuseColor {

    // MARK: - Ground and surfaces

    /// Page ground. Also the label color on moss (primary buttons, counts).
    static let ground = rgb(0xF4F1E8)
    /// Top of the page wash.
    static let groundWash = rgb(0xF8F6EF)
    /// Bottom of the page wash; drawers and deep wells.
    static let groundDeep = rgb(0xEDE9DB)
    /// Cards, tiles, chrome circles and pills.
    static let raised = rgb(0xFBF9F4)
    /// The composer and sheets: the only pure white.
    static let composer = Color.white
    /// Inset fields and rows inside a card; code blocks.
    static let inset = rgb(0xEEEADD)
    /// Moss wash: tags, tinted buttons, hint cards, app icon squares.
    static let mossTint = rgb(0xE4EADE)
    /// Khaki shelf: fill-only chips (`musePill(.chip)`).
    static let shelf = rgb(0xE7E2D2)

    // MARK: - Ink

    /// Titles and body text.
    static let ink = rgb(0x1B2118)
    /// Secondary text and SF Symbols.
    static let ink70 = rgb(0x4E5549)
    /// Meta, labels, eyebrows, chevrons, placeholders.
    static let ink55 = rgb(0x676E61)
    /// 0.75pt borders on every raised surface.
    static let hairline = ink.opacity(0.09)
    /// Dividers between rows inside a card.
    static let divider = ink.opacity(0.045)

    // MARK: - Moss (affordance, never a content fill)

    /// Deepest moss: gradient ends, the orb's shadow side.
    static let moss900 = rgb(0x16211A)
    /// Primary fill: selected pills, counts, switches that are on.
    static let moss700 = rgb(0x2E432F)
    /// The moss to reach for first. Same as `moss700`.
    static let moss = moss700
    /// Accent text, status dots, tinted button labels.
    static let moss600 = rgb(0x3E5A3F)
    /// Light moss: tracks and quiet marks. Never a fill behind text.
    static let moss300 = rgb(0x8FA886)

    // MARK: - Clay and ochre (consequence and time)

    /// Delete, remove, failed, nearly full, low battery. One per screen.
    static let clay = rgb(0xA85A3C)
    /// Ground for a clay badge.
    static let clayTint = rgb(0xF3E4DA)
    /// A small marker for "new" or "fresh off the ring". A dot, never a fill.
    static let ochre = rgb(0xC98A4B)
    /// Text on an unsure confidence tag (`MuseConfidenceTag`), dark enough to read on its tint.
    static let ochreInk = rgb(0x8A5E2E)
    /// Ground for an unsure confidence tag. The sure end is `mossTint`.
    static let ochreTint = rgb(0xF4E6D3)

    // MARK: - Orb ramps (only `MuseOrb` uses these)

    static let orbHighlight = rgb(0xA8BF9E)
    static let orbMid = rgb(0x6C8C67)
    static let orbDeep = rgb(0x3B5A3C)
    static let orbLinenHighlight = rgb(0xFFFDF8)
    static let orbLinenMid = rgb(0xF6F1E4)
    static let orbLinenDeep = rgb(0xE2DAC6)
    static let orbLinenShade = rgb(0xBEB49C)
    /// The warm shade under the linen orb.
    static let orbLinenInset = rgb(0x605842)

    // MARK: - The ring's lights

    /// The ring's amber light (recording to itself), the orange the booklet prints. White is
    /// `composer`.
    static let ringAmber = rgb(0xF57829)

    // MARK: - Gradients

    /// Primary buttons: moss 600 into deep forest at 165 degrees.
    static let primaryGradient = LinearGradient(
        colors: [moss600, rgb(0x1E2D20)],
        startPoint: UnitPoint(x: 0.18, y: 0),
        endPoint: UnitPoint(x: 0.82, y: 1)
    )

    /// Voice and hero moss surfaces: a softer forest, ending in moss 900.
    static let softForestGradient = LinearGradient(
        colors: [rgb(0x43603F), rgb(0x2A3F2B), moss900],
        startPoint: UnitPoint(x: 0.18, y: 0),
        endPoint: UnitPoint(x: 0.82, y: 1)
    )

    // MARK: - Helper

    /// sRGB from a 0xRRGGBB literal. The only place hex lives.
    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
