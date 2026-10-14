import SwiftUI

// The ring, drawn two ways.
//
// `MuseRingGlyph` is the inside of the one ring button: the ring seen from above, a
// closed band with its stone at 12 o'clock, and the battery (or the sync in flight)
// running clockwise from the stone along the band. A dashed outline with a hollow stone
// when the ring isn't set up, moss when linked, faint when away, clay when low, inverted
// onto moss while a muse streams in.
//
// `MuseRingMark` is the ring seen from above (a band and its stone), for marking things
// that came from the ring.

// MARK: - Gauge glyph

/// The ring with its battery on the band. `fill` is 0...1 (battery, or sync progress while
/// bringing muses in), drawn clockwise from the stone; nil draws the band's faint track
/// alone. `count` writes a number inside (muses still coming); `attention` writes a "!"
/// (something only the person can fix). Draw it on a 38pt circle filled with
/// `style.plate`. The stone sits in a small gap it cuts in the band, so it reads on any
/// plate.
struct MuseRingGlyph: View {
    nonisolated enum Style: String, CaseIterable, Sendable {
        /// Linked: a moss band on raised paper.
        case linked
        /// Away: the last reading, at half strength.
        case away
        /// Not set up, or bluetooth off: a dashed outline and a hollow stone, no band.
        case setup
        /// Streaming a muse right now: a ground band on a moss plate.
        case streaming
        /// Linked with a low battery: a clay band.
        case low

        /// The circle a button draws behind the glyph: raised paper, or moss while streaming.
        var plate: Color { self == .streaming ? MuseColor.moss : MuseColor.raised }

        /// Whether that circle carries a hairline (every plate but moss).
        var platesHairline: Bool { self != .streaming }
    }

    var fill: Double?
    var style: Style
    var count: Int?
    var attention: Bool
    var breathing: Bool
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        fill: Double?,
        style: Style,
        count: Int? = nil,
        attention: Bool = false,
        breathing: Bool = false,
        size: CGFloat = 21
    ) {
        self.fill = fill
        self.style = style
        self.count = count
        self.attention = attention
        self.breathing = breathing
        self.size = size
    }

    private var scale: CGFloat { size / 21 }
    private var band: CGFloat { 2.4 * scale }
    /// The stone at 12 o'clock, a little wider than the band.
    private var stone: CGFloat { 5.4 * scale }
    /// The gap the stone cuts in the band around itself.
    private var halo: CGFloat { stone + 2.2 * scale }
    /// How much of the turn the gap hides on each side of the stone, so the battery is
    /// laid out on the band you can see (5% still shows a short arc off the stone).
    private var lead: CGFloat { (halo / 2) / (.pi * size) }

    var body: some View {
        Group {
            if breathing && !reduceMotion {
                face.phaseAnimator([false, true]) { content, low in
                    content.opacity(low ? 0.45 : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            } else {
                face
            }
        }
        .frame(width: size, height: size)
        .animation(MuseMotion.gentle, value: fill)
        .animation(MuseMotion.smooth, value: style)
        .accessibilityHidden(true)
    }

    private var face: some View {
        ZStack {
            track
            if let bandFill {
                arc(to: lead + (1 - 2 * lead) * bandFill)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: band, lineCap: .round))
            }
            // The gap around the stone, cut through track and band alike.
            Circle()
                .frame(width: halo, height: halo)
                .offset(y: -size / 2)
                .blendMode(.destinationOut)
            stoneView
            center
        }
        .frame(width: size, height: size)
        // The band and stone reach past the frame; give the group room so the cut
        // never trims them.
        .padding(halo)
        .compositingGroup()
        .padding(-halo)
    }

    // MARK: Band

    /// The whole band, faint. Not set up: a closed dashed outline (eleven square-ended
    /// dashes, as long as their gaps, evenly spaced so one sits centred under the stone),
    /// an outline waiting to be filled rather than a spinner.
    @ViewBuilder
    private var track: some View {
        if style == .setup {
            let period = .pi * size / 11
            let dash = period / 2
            arc(to: 1)
                .stroke(
                    trackColor,
                    style: StrokeStyle(lineWidth: band, lineCap: .butt, dash: [dash, period - dash], dashPhase: dash / 2)
                )
        } else {
            arc(to: 1)
                .stroke(trackColor, lineWidth: band)
        }
    }

    /// Starts at the stone (12 o'clock) and runs clockwise.
    private func arc(to fraction: CGFloat) -> some Shape {
        Circle()
            .trim(from: 0, to: max(0, min(1, fraction)))
            .rotation(.degrees(-90))
    }

    private var bandFill: CGFloat? {
        guard style != .setup, let fill else { return nil }
        return CGFloat(max(0, min(1, fill)))
    }

    /// Faint behind a band. With no band (dashed, or no reading yet) the track is all
    /// there is, so it carries the glyph at half strength instead of vanishing.
    private var trackColor: Color {
        let alone = bandFill == nil
        switch style {
        case .linked, .low: return MuseColor.ink.opacity(alone ? 0.4 : 0.16)
        case .away: return MuseColor.ink.opacity(alone ? 0.3 : 0.12)
        case .setup: return MuseColor.ink55
        case .streaming: return MuseColor.ground.opacity(alone ? 0.7 : 0.32)
        }
    }

    private var bandColor: Color {
        switch style {
        case .linked: MuseColor.moss
        case .low: MuseColor.clay
        case .away: MuseColor.ink55.opacity(0.55)
        case .streaming: MuseColor.ground
        case .setup: Color.clear
        }
    }

    // MARK: Stone

    /// The ring's one stone, at 12 o'clock on the band. Hollow until the ring is set up.
    @ViewBuilder
    private var stoneView: some View {
        Group {
            if style == .setup {
                Circle().strokeBorder(stoneColor, lineWidth: 1.2 * scale)
            } else {
                Circle().fill(stoneColor)
            }
        }
        .frame(width: stone, height: stone)
        .offset(y: -size / 2)
    }

    private var stoneColor: Color {
        switch style {
        case .linked: MuseColor.moss
        case .low: MuseColor.ink70
        case .away, .setup: MuseColor.ink55
        case .streaming: MuseColor.ground
        }
    }

    // MARK: Inside

    @ViewBuilder
    private var center: some View {
        if let count, count > 0 {
            Text(min(count, 99), format: .number)
                .font(MuseFont.satoshi(9.5 * scale, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(inkColor)
                .contentTransition(.numericText(value: Double(count)))
                .dynamicTypeSize(.large)
                .offset(y: 2 * scale)
        } else if attention {
            Image(systemName: "exclamationmark")
                .font(MuseFont.symbol(9 * scale, weight: .heavy))
                .foregroundStyle(style == .streaming ? MuseColor.ground : MuseColor.clay)
                .offset(y: 1.5 * scale)
        }
    }

    private var inkColor: Color {
        switch style {
        case .linked, .low: MuseColor.ink
        case .away, .setup: MuseColor.ink55
        case .streaming: MuseColor.ground
        }
    }
}

// MARK: - Ring mark

/// The ring seen from above: a band with its one stone. Put it wherever a screen says
/// "the ring did this" (a muse card's origin, a "from the ring" line).
struct MuseRingMark: View {
    var size: CGFloat
    var color: Color

    init(size: CGFloat = 16, color: Color = MuseColor.ink70) {
        self.size = size
        self.color = color
    }

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .strokeBorder(color, lineWidth: max(1.4, size * 0.13))
            Circle()
                .fill(color)
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(y: -size * 0.06)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
