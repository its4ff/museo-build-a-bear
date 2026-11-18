import SwiftUI

/// The ring pill at the mac's size: the iphone pill's words and fill, a step smaller.
/// Fills the width it is given.
struct DuoRingPill: View {
    let state: PocketRingState
    var action: () -> Void = {}

    init(state: PocketRingState, action: @escaping () -> Void = {}) {
        self.state = state
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DuoRingPillContent(state: state)
                .frame(maxWidth: .infinity)
                .frame(height: DuoMetrics.bar)
                .background {
                    PocketRingPillFill(state: state)
                        .clipShape(Capsule())
                        .overlay { PocketPillEdge(onDark: isDark) }
                        .museElevation(.e1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.98))
        .museAnimation(MuseMotion.smooth, value: state.name)
        .accessibilityHint("opens your ring")
    }

    private var isDark: Bool {
        if case .linked = state { return true }
        return false
    }
}

/// The pill's mark and words at the mac's size: the iphone's `PocketRingPillContent`, the
/// same words for every state, set a little tighter so each fits the corner's width.
private struct DuoRingPillContent: View {
    let state: PocketRingState

    var body: some View {
        HStack(spacing: MuseSpacing.sm - MuseSpacing.xxs / 2) {
            PocketHalftoneRing(
                size: DuoMetrics.pillMark,
                ink: onDark ? PocketColor.printSand : MuseColor.ink,
                light: light,
                dots: DuoMetrics.pillMarkDots
            )
            HStack(spacing: 0) {
                middle
                Spacer(minLength: 0)
            }
            trailing
        }
        .padding(.leading, MuseSpacing.sm)
        .padding(.trailing, MuseSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var onDark: Bool {
        if case .linked = state { return true }
        return false
    }

    private var light: PocketRingLight? {
        switch state {
        case .memory: .amber
        case .streaming: .white
        default: nil
        }
    }

    @ViewBuilder
    private var middle: some View {
        if case .streaming(let words) = state {
            let parts = words.split(separator: " ")
            ViewThatFits(in: .horizontal) {
                Text(words).lineLimit(1).fixedSize()
                ForEach(Array(stride(from: min(parts.count, DuoMetrics.pillWords) - 1, through: 1, by: -1)), id: \.self) { count in
                    Text("…" + parts.suffix(count).joined(separator: " ")).lineLimit(1).fixedSize()
                }
                Text(words).lineLimit(1).truncationMode(.head)
            }
            .font(MuseType.serif)
            .foregroundStyle(MuseColor.ink)
        } else {
            Text("your museo")
                .font(MuseType.label)
                .foregroundStyle(onDark ? MuseColor.ground : MuseColor.ink)
                .lineLimit(1)
        }
    }

    private var trailing: some View {
        HStack(spacing: MuseSpacing.xxs) {
            if case .charging = state {
                Image(systemName: "bolt.fill")
                    .museSymbol(PocketRingPillMetrics.bolt, weight: .semibold)
                    .accessibilityHidden(true)
            }
            if let quiet {
                Text(quiet)
            }
        }
        .font(MuseType.metaMedium)
        .monospacedDigit()
        .foregroundStyle(quietInk)
        .lineLimit(1)
        .fixedSize()
    }

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
        case .linked: MuseColor.mossTint
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
