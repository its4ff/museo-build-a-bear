import SwiftUI

/// The ring pill at the top of the panel: the duo pill's fill, edge and mark, carrying the
/// ring's own name (the one you gave it, when you did) and one quiet word about it. The name
/// turns into a field while renaming.
struct PanelRingPill: View {
    let state: PocketRingState
    /// The name the ring advertises; nil before it's set up.
    let ringName: String?
    /// "82%", "away", "recording · 0:42".
    var detail: String?
    /// What VoiceOver says after the name: "linked, 82 percent".
    var spoken: String?
    @Binding var isRenaming: Bool

    var body: some View {
        HStack(spacing: MuseSpacing.sm - MuseSpacing.xxs / 2) {
            PocketHalftoneRing(
                size: DuoMetrics.pillMark,
                ink: onDark ? PocketColor.printSand : MuseColor.ink,
                light: light,
                dots: DuoMetrics.pillMarkDots
            )
            .accessibilityHidden(true)
            RingNameField(
                ringName: ringName,
                isEditing: $isRenaming,
                font: MuseType.label,
                ink: onDark ? MuseColor.ground : MuseColor.ink,
                accent: onDark ? MuseColor.mossTint : MuseColor.moss,
                unnamed: "your museo"
            )
            .layoutPriority(1)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.leading, MuseSpacing.sm)
        .padding(.trailing, MuseSpacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: DuoMetrics.bar)
        .background {
            PocketRingPillFill(state: state)
                .clipShape(Capsule())
                .overlay { PocketPillEdge(onDark: onDark) }
                .museElevation(.e1)
        }
        .contentShape(Capsule())
        .museAnimation(MuseMotion.smooth, value: state.name)
        .accessibilityElement(children: isRenaming ? .contain : .combine)
        .accessibilityValue(spoken ?? "")
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

    private var trailing: some View {
        HStack(spacing: MuseSpacing.xxs) {
            if case .charging = state {
                Image(systemName: "bolt.fill")
                    .museSymbol(PocketRingPillMetrics.bolt, weight: .semibold)
                    .accessibilityHidden(true)
            }
            if let detail {
                Text(detail)
            }
        }
        .font(MuseType.metaMedium)
        .monospacedDigit()
        .foregroundStyle(detailInk)
        .lineLimit(1)
        .fixedSize()
        .accessibilityHidden(spoken != nil)
    }

    private var detailInk: Color {
        switch state {
        case .away: MuseColor.ink55
        case .linked: MuseColor.mossTint
        case .memory, .charging: MuseColor.ink
        case .streaming, .bringingIn: MuseColor.ink70
        }
    }
}
