#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import SwiftUI

// The ring pill, ported from museo dune's `RingAccessory`: what the ring is doing, above
// the navigation on every tab. No instruction text, ever; the battery is exact.
//
// Three pieces, so both shells can use it:
// - `PocketRingPillContent`: the mark and the words. No background of its own.
// - `PocketRingPillFill`: what fills the capsule for a state. Clip it yourself.
// - `PocketRingPill`: the two together as a standalone capsule (shell b), and
//   `PocketRingAccessory`, the two together inside `.tabViewBottomAccessory` (shell a).

nonisolated enum PocketRingPillMetrics {
    /// The standalone capsule's height.
    static let height: CGFloat = 52
    /// The halftone mark.
    static let mark: CGFloat = 26
    /// The bolt beside a charging level.
    static let bolt: CGFloat = 10
    /// Cells across the mark: fine enough that the band prints three cells wide.
    static let markDots = 23
    /// How far a level's leading edge dissolves into the grain.
    static let levelSoft: CGFloat = 30
    /// The most words a streaming pill offers to fit, newest last.
    static let wordChoices = 14
}

// MARK: - Content

/// The pill's mark and words for a state, with no background: put it over
/// `PocketRingPillFill`, or straight into the system's accessory capsule with
/// `onGlass: true` (dark ink for every state, since nothing of ours is behind it).
/// `compact` keeps only the mark and the shortest words (the accessory tucked inline).
struct PocketRingPillContent: View {
    let state: PocketRingState
    var compact = false
    var onGlass = false

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            PocketHalftoneRing(
                size: PocketRingPillMetrics.mark,
                ink: markInk,
                light: markLight,
                dots: PocketRingPillMetrics.markDots
            )
            if !compact {
                middle
                Spacer(minLength: 0)
            }
            trailing
        }
        .padding(.leading, MuseSpacing.row)
        .padding(.trailing, MuseSpacing.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// The words sit on the moss.
    private var onDark: Bool {
        if onGlass { return false }
        if case .linked = state { return true }
        return false
    }

    private var markInk: Color { onDark ? PocketColor.printSand : MuseColor.ink }

    private var markLight: PocketRingLight? {
        switch state {
        case .memory: .amber
        case .streaming: .white
        default: nil
        }
    }

    @ViewBuilder
    private var middle: some View {
        if case .streaming(let words) = state {
            PocketStreamingWords(words: words)
        } else {
            Text("your museo")
                .font(MuseType.label)
                .foregroundStyle(onDark ? MuseColor.ground : MuseColor.ink)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: MuseSpacing.xxs) {
            if case .charging = state {
                Image(systemName: "bolt.fill")
                    .museSymbol(PocketRingPillMetrics.bolt, weight: .semibold)
                    .accessibilityHidden(true)
            }
            if let quiet {
                Text(quiet)
                    .contentTransition(.numericText())
            }
        }
        .font(MuseType.metaMedium)
        .monospacedDigit()
        .foregroundStyle(quietInk)
        .lineLimit(1)
        .fixedSize()
    }

    /// The quiet words at the trailing end.
    private var quiet: String? {
        switch state {
        case .away: "away"
        case .linked(let battery): "\(battery)%"
        case .memory: "recording"
        case .streaming: nil
        case .bringingIn(_, let total): "bringing in \(total)…"
        case .charging(let level): "\(level)%"
        }
    }

    private var quietInk: Color {
        switch state {
        case .away: MuseColor.ink55
        case .linked: onDark ? MuseColor.mossTint : MuseColor.ink70
        case .memory, .charging: MuseColor.ink
        case .streaming, .bringingIn: MuseColor.ink70
        }
    }

    private var spoken: String {
        switch state {
        case .away: "your museo, away"
        case .linked(let battery): "your museo, linked, \(battery) percent"
        case .memory: "your museo, recording to memory"
        case .streaming(let words): "your museo, streaming. \(words)"
        case .bringingIn(_, let total): "your museo, bringing in \(total)"
        case .charging(let level): "your museo, charging, \(level) percent"
        }
    }
}

// MARK: - Fill

/// What fills the capsule for a state, edge to edge. Not clipped: the caller clips it to
/// its capsule.
struct PocketRingPillFill: View {
    let state: PocketRingState

    var body: some View {
        ZStack {
            switch state {
            case .away:
                PocketPaperFill().transition(.opacity)
            case .linked:
                PocketMoss().transition(.opacity)
            case .memory:
                PocketAmberFill().transition(.opacity)
            case .streaming:
                PocketOffWhiteFill().transition(.opacity)
            case .bringingIn(let done, let total):
                PocketPillLevel(level: total > 0 ? Double(done) / Double(total) : 0, color: PocketColor.bringMoss)
                    .transition(.opacity)
            case .charging(let level):
                PocketPillLevel(level: Double(level) / 100, color: PocketColor.chargeGreen)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Their words as they arrive, newest in view. When they outgrow the pill the oldest
/// leave a whole word at a time, behind an ellipsis: never half a word.
private struct PocketStreamingWords: View {
    let words: String

    var body: some View {
        let parts = words.split(separator: " ")
        let most = min(parts.count, PocketRingPillMetrics.wordChoices)
        ViewThatFits(in: .horizontal) {
            line(words)
            ForEach(Array(stride(from: most - 1, through: 1, by: -1)), id: \.self) { count in
                line("…" + parts.suffix(count).joined(separator: " "))
            }
            // One word longer than the pill: let the system cut it.
            Text(words)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .font(MuseType.serif)
        .foregroundStyle(MuseColor.ink)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .fixedSize()
    }
}

/// A level from the leading edge (moss rising while recordings come in, green to the
/// battery while it charges) over off-white. Its leading edge has no line: the color thins
/// out and breaks into the grain's own specks, as a dithered print would.
private struct PocketPillLevel: View {
    let level: Double
    let color: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let at = min(max(level, 0.06), 1)
            let soft = Double(PocketRingPillMetrics.levelSoft / width)
            LinearGradient(
                colors: [color, color.opacity(0.82)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask {
                ZStack {
                    ramp(solidTo: at - soft, clearAt: at + soft * 0.35)
                    if !reduceTransparency && at < 1 {
                        // The specks carry the color a little further than the wash does.
                        PocketGrain.stippleDark
                            .resizable(resizingMode: .tile)
                            .interpolation(.none)
                            .mask { ramp(solidTo: at - soft * 0.5, clearAt: at + soft * 1.3) }
                    }
                }
            }
        }
        .background(PocketColor.pillPaper)
        .pocketFillGrain()
        .museAnimation(MuseMotion.gentle, value: level)
    }

    private func ramp(solidTo: Double, clearAt: Double) -> some View {
        let solid = min(max(solidTo, 0), 1)
        // A full level stays full to the trailing edge.
        let clear = level >= 1 ? 1 : min(max(clearAt, solid), 1)
        return LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: level >= 1 ? 1 : solid),
                .init(color: .clear, location: clear),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Standalone

/// The ring pill as its own capsule: the fill, the content, a light inner edge and its
/// lift. Fills the width it is given; `compact` hugs the mark and the shortest words.
/// Give it an `action` to make it a button (it opens the ring sheet).
struct PocketRingPill: View {
    let state: PocketRingState
    var compact = false
    var action: (() -> Void)?

    init(state: PocketRingState, compact: Bool = false, action: (() -> Void)? = nil) {
        self.state = state
        self.compact = compact
        self.action = action
    }

    var body: some View {
        if let action {
            Button {
                MuseHaptics.play(.soft)
                action()
            } label: {
                face
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))
            .accessibilityHint("opens your ring")
        } else {
            face
        }
    }

    private var face: some View {
        PocketRingPillContent(state: state, compact: compact)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: PocketRingPillMetrics.height)
            .background {
                PocketRingPillFill(state: state)
                    .clipShape(Capsule())
                    .overlay { PocketPillEdge(onDark: isDark) }
                    .museElevation(.e1)
            }
            .contentShape(Capsule())
            .museAnimation(MuseMotion.smooth, value: state.name)
    }

    private var isDark: Bool {
        if case .linked = state { return true }
        return false
    }
}

// MARK: - In the tab view's accessory

/// The ring pill for `.tabViewBottomAccessory { PocketRingAccessory(state:) { … } }`. The
/// system draws and sizes the capsule; this fills it edge to edge and goes compact when
/// the bar tucks it inline.
struct PocketRingAccessory: View {
    let state: PocketRingState
    var action: () -> Void = {}

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    init(state: PocketRingState, action: @escaping () -> Void = {}) {
        self.state = state
        self.action = action
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            PocketRingPillContent(state: state, compact: placement == .inline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    PocketRingPillFill(state: state)
                        .clipShape(Capsule())
                        .ignoresSafeArea()
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .museAnimation(MuseMotion.smooth, value: state.name)
        .accessibilityHint("opens your ring")
    }
}
#endif
