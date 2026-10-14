import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// The ring's two moments on the lock screen and in the Dynamic Island:
// a live capture ("listening") and bringing recordings in off the ring.
//
// The widget extension cannot see the app's `Design/` module, so it keeps a
// tiny copy of the tokens it needs below. When you change a color in
// `museo build/Design/MuseColor.swift`, change it here too.

// MARK: - Tokens (a small mirror of Design/)

/// Linen palette, mirrored from `Design/MuseColor.swift`.
private enum Linen {
    /// Lock screen card. `MuseColor.ground`.
    static let ground = Color(hex: 0xF4F1E8)
    /// Words that matter. `MuseColor.ink`.
    static let ink = Color(hex: 0x1B2118)
    /// Quieter lines. `MuseColor.ink70`.
    static let ink70 = Color(hex: 0x4E5549)
    /// Accents on linen. `MuseColor.moss600`.
    static let moss600 = Color(hex: 0x3E5A3F)
    /// Accents on the island's black, where moss600 is too dark to read. `MuseColor.moss300`.
    static let moss300 = Color(hex: 0x8FA886)
    /// The one live mark: "listening". `MuseColor.clay`.
    static let clay = Color(hex: 0xA85A3C)
    /// Bar tracks on linen. `MuseColor.hairline`.
    static let hairline = Color(hex: 0x1B2118).opacity(0.09)

    // The Dynamic Island is always black, so it reads linen on black.
    /// Island words.
    static let islandInk = ground
    /// Island quiet lines.
    static let islandInk70 = ground.opacity(0.64)
    /// Island bar tracks.
    static let islandTrack = ground.opacity(0.16)
}

/// Lora speaks, Satoshi labels. Mirrors `Design/MuseFont.swift`.
/// The widget registers both fonts through `UIAppFonts` in its Info.plist; when a
/// face is missing it falls back to the system font of the same voice.
private enum LinenType {
    private static let hasLora = UIFont(name: "Lora-Regular", size: 12) != nil
    private static let hasSatoshi = UIFont(name: "SatoshiVariable-Bold_Regular", size: 12) != nil

    static func lora(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        hasLora
            ? .custom("Lora-Regular", size: size, relativeTo: style)
            : .system(style, design: .serif)
    }

    static func satoshi(_ size: CGFloat, medium: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        guard hasSatoshi else { return .system(style, weight: medium ? .medium : .regular) }
        let name = medium ? "SatoshiVariable-Bold_Medium" : "SatoshiVariable-Bold_Regular"
        return .custom(name, size: size, relativeTo: style)
    }

    /// Small tracked label above the line, like `MuseType.eyebrow`.
    static let eyebrowTracking: CGFloat = 1.76
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Marks

/// The ring seen from above: a band with its one stone. Mirrors `MuseRingMark`.
private struct RingMark: View {
    var size: CGFloat = 13
    var color: Color

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

/// The ring icon's glyph: the ring seen from above, a faint track all the way round with
/// its stone at 12 o'clock, and a band running clockwise from the stone, filled by `fill`.
/// Mirrors `MuseRingGlyph`, here showing how much has come in. The stone leaves a small
/// gap in the track on each side, drawn by trimming rather than a blend so it reads on any
/// island or lock screen.
private struct RingGauge: View {
    var fill: Double
    var size: CGFloat = 18
    var color: Color
    var track: Color

    private var scale: CGFloat { size / 21 }
    private var lineWidth: CGFloat { max(1.8, 2.4 * scale) }
    /// The stone, a little wider than the band.
    private var stone: CGFloat { max(4, 5.4 * scale) }
    /// The band's diameter, inset so the stone stays inside the frame.
    private var diameter: CGFloat { size - stone }
    /// How much of the turn the gap hides on each side of the stone.
    private var lead: CGFloat { ((stone + 2.2 * scale) / 2) / (.pi * diameter) }
    /// The round cap reaches past the end of a trim; start the band that much later.
    private var capLead: CGFloat { (lineWidth / 2) / (.pi * diameter) }

    var body: some View {
        let fraction = CGFloat(min(max(fill, 0), 1))
        let start = lead + capLead
        ZStack {
            arc(from: lead, to: 1 - lead)
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            if fraction > 0 {
                arc(from: start, to: start + (1 - 2 * start) * fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            Circle()
                .fill(color)
                .frame(width: stone, height: stone)
                .offset(y: -diameter / 2)
        }
        .frame(width: diameter, height: diameter)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Starts at the stone (12 o'clock) and runs clockwise.
    private func arc(from: CGFloat, to: CGFloat) -> some Shape {
        Circle()
            .trim(from: from, to: max(from, to))
            .rotation(.degrees(-90))
    }
}

/// A 4pt capsule bar: moss on a quiet track.
private struct LinenBar: View {
    var fraction: Double
    var color: Color
    var track: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// One spoken element for a mark that is otherwise decoration.
    func spoken(_ label: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
    }
}

/// Small tracked label with its mark, the first line of every activity.
private struct Eyebrow: View {
    let text: String
    let color: Color
    var markSize: CGFloat = 13
    var size: CGFloat = 11.5

    var body: some View {
        HStack(spacing: 7) {
            RingMark(size: markSize, color: color)
            Text(text)
                .font(LinenType.satoshi(size, medium: true, relativeTo: .caption))
                .tracking(LinenType.eyebrowTracking)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}


// MARK: - Capture

/// Counts up from when the ring started listening.
private struct CaptureClock: View {
    let startedAt: Date
    let font: Font
    let color: Color
    var maxWidth: CGFloat

    var body: some View {
        Text(timerInterval: startedAt...startedAt.addingTimeInterval(12 * 3_600), countsDown: false)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .frame(maxWidth: maxWidth, alignment: .trailing)
    }
}

/// Lock screen while the ring streams: "listening", the line, and a clock counting up.
private struct CaptureLockScreen: View {
    let startedAt: Date

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "listening", color: Linen.clay)
                Text("your ring is listening")
                    .font(LinenType.lora(19, relativeTo: .title3))
                    .foregroundStyle(Linen.ink)
                Text("from the ring · words land in a moment")
                    .font(LinenType.satoshi(13, relativeTo: .footnote))
                    .foregroundStyle(Linen.ink70)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            CaptureClock(
                startedAt: startedAt,
                font: LinenType.lora(28, relativeTo: .title),
                color: Linen.ink,
                maxWidth: 104
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Expanded island, bottom: the line and where it comes from, linen on black.
private struct CaptureIslandLine: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("your ring is listening")
                .font(LinenType.lora(17, relativeTo: .body))
                .foregroundStyle(Linen.islandInk)
            Text("from the ring · words land in a moment")
                .font(LinenType.satoshi(13, relativeTo: .footnote))
                .foregroundStyle(Linen.islandInk70)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sync

/// What the sync activity says, from `done` of `total`.
/// While a recording is in flight it reads "bringing in 2 of 5" (the one coming in now),
/// and once `done == total` it reads "all 5 are in".
private struct SyncCopy {
    let done: Int
    let total: Int

    init(done: Int, total: Int) {
        self.total = max(total, 1)
        self.done = min(max(done, 0), self.total)
    }

    var isFinished: Bool { done >= total }
    var fraction: Double { Double(done) / Double(total) }
    /// The recording coming in right now, 1-based.
    var current: Int { min(done + 1, total) }

    var line: String {
        switch (isFinished, total) {
        case (true, 1): "your recording is in"
        case (true, _): "all \(total) are in"
        case (false, 1): "bringing in a recording"
        case (false, _): "bringing in \(current) of \(total)"
        }
    }

    var meta: String {
        isFinished ? "words land in a moment" : "keep your ring near this iphone"
    }

    /// The island's short count.
    var count: String { "\(current) of \(total)" }
}

/// Lock screen while recordings come in off the ring: the count and a moss bar.
private struct SyncLockScreen: View {
    let copy: SyncCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "from the ring", color: Linen.moss600)
                Text(copy.line)
                    .font(LinenType.lora(19, relativeTo: .title3))
                    .foregroundStyle(Linen.ink)
                    .contentTransition(.numericText())
                Text(copy.meta)
                    .font(LinenType.satoshi(13, relativeTo: .footnote))
                    .foregroundStyle(Linen.ink70)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            LinenBar(fraction: copy.fraction, color: Linen.moss600, track: Linen.hairline)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// The island's count, or a check once everything is in.
private struct SyncIslandCount: View {
    let copy: SyncCopy
    let font: Font
    var checkSize: CGFloat = 15

    var body: some View {
        if copy.isFinished {
            Image(systemName: "checkmark")
                .font(LinenType.satoshi(checkSize, medium: true))
                .foregroundStyle(Linen.moss300)
                .spoken(copy.line)
        } else {
            Text(copy.count)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(Linen.islandInk)
                .contentTransition(.numericText())
                .spoken(copy.line)
        }
    }
}

/// Expanded island, bottom: a hint while it works (the count sits top right),
/// the result once everything is in, then the bar. Linen on black.
private struct SyncIslandLine: View {
    let copy: SyncCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if copy.isFinished {
                    Text(copy.line)
                        .font(LinenType.lora(17, relativeTo: .body))
                        .foregroundStyle(Linen.islandInk)
                } else {
                    Text(copy.meta)
                        .font(LinenType.satoshi(13, relativeTo: .footnote))
                        .foregroundStyle(Linen.islandInk70)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            LinenBar(fraction: copy.fraction, color: Linen.moss300, track: Linen.islandTrack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

// MARK: - Activities

struct MuseCaptureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MuseCaptureActivityAttributes.self) { context in
            CaptureLockScreen(startedAt: context.attributes.startedAt)
                .activityBackgroundTint(Linen.ground)
                .activitySystemActionForegroundColor(Linen.ink70)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Eyebrow(text: "listening", color: Linen.clay, markSize: 14, size: 12)
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CaptureClock(
                        startedAt: context.attributes.startedAt,
                        font: LinenType.lora(22, relativeTo: .title2),
                        color: Linen.islandInk,
                        maxWidth: 96
                    )
                    .padding(.trailing, 6)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CaptureIslandLine()
                }
            } compactLeading: {
                RingMark(size: 13, color: Linen.clay)
                    .padding(.leading, 2)
                    .spoken("listening")
            } compactTrailing: {
                CaptureClock(
                    startedAt: context.attributes.startedAt,
                    font: LinenType.lora(14, relativeTo: .footnote),
                    color: Linen.islandInk,
                    maxWidth: 46
                )
                .padding(.trailing, 2)
            } minimal: {
                RingMark(size: 13, color: Linen.clay)
                    .spoken("listening")
            }
            .keylineTint(Linen.clay)
        }
    }
}

struct MuseSyncLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MuseSyncActivityAttributes.self) { context in
            SyncLockScreen(copy: SyncCopy(done: context.state.done, total: context.state.total))
                .activityBackgroundTint(Linen.ground)
                .activitySystemActionForegroundColor(Linen.ink70)
        } dynamicIsland: { context in
            let copy = SyncCopy(done: context.state.done, total: context.state.total)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Eyebrow(text: "from the ring", color: Linen.moss300, markSize: 14, size: 12)
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SyncIslandCount(copy: copy, font: LinenType.lora(20, relativeTo: .title3))
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SyncIslandLine(copy: copy)
                }
            } compactLeading: {
                RingGauge(fill: copy.fraction, size: 17, color: Linen.moss300, track: Linen.islandTrack)
                    .padding(.leading, 2)
                    .spoken(copy.line)
            } compactTrailing: {
                SyncIslandCount(copy: copy, font: LinenType.satoshi(13, medium: true, relativeTo: .footnote), checkSize: 12)
                    .padding(.trailing, 2)
            } minimal: {
                RingGauge(fill: copy.fraction, size: 16, color: Linen.moss300, track: Linen.islandTrack)
                    .spoken(copy.line)
            }
            .keylineTint(Linen.moss300)
        }
    }
}

// MARK: - Previews (open the canvas to see every state)

#Preview("listening · lock screen", as: .content, using: MuseCaptureActivityAttributes(startedAt: .now.addingTimeInterval(-12))) {
    MuseCaptureLiveActivity()
} contentStates: {
    MuseCaptureActivityAttributes.ContentState()
}

#Preview("listening · island", as: .dynamicIsland(.expanded), using: MuseCaptureActivityAttributes(startedAt: .now.addingTimeInterval(-12))) {
    MuseCaptureLiveActivity()
} contentStates: {
    MuseCaptureActivityAttributes.ContentState()
}

#Preview("listening · compact", as: .dynamicIsland(.compact), using: MuseCaptureActivityAttributes(startedAt: .now.addingTimeInterval(-12))) {
    MuseCaptureLiveActivity()
} contentStates: {
    MuseCaptureActivityAttributes.ContentState()
}

#Preview("bringing in · lock screen", as: .content, using: MuseSyncActivityAttributes(startedAt: .now)) {
    MuseSyncLiveActivity()
} contentStates: {
    MuseSyncActivityAttributes.ContentState(done: 1, total: 5)
    MuseSyncActivityAttributes.ContentState(done: 5, total: 5)
}

#Preview("bringing in · island", as: .dynamicIsland(.expanded), using: MuseSyncActivityAttributes(startedAt: .now)) {
    MuseSyncLiveActivity()
} contentStates: {
    MuseSyncActivityAttributes.ContentState(done: 1, total: 5)
    MuseSyncActivityAttributes.ContentState(done: 5, total: 5)
}

#Preview("bringing in · compact", as: .dynamicIsland(.compact), using: MuseSyncActivityAttributes(startedAt: .now)) {
    MuseSyncLiveActivity()
} contentStates: {
    MuseSyncActivityAttributes.ContentState(done: 2, total: 5)
}
