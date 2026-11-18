#if DEBUG
import SwiftUI

/// The notch island's three moments, top to bottom, each under its own slice of menu bar:
/// resting, holding (the words arriving) and landed (what the hold became). No captions. The island stays black,
/// like the notch it continues: the type, the ring's print and the chip carry the duo.
struct SmallIslandShot: View {
    var body: some View {
        VStack(spacing: 0) {
            band(.resting)
            band(.holding(heard: "for claude, book the dentist", hearing: "thursday"))
            band(.landed(chip: "claude", words: "book the dentist thursday", note: "sent to claude"))
        }
        .background { SmallDesk() }
        .preferredColorScheme(.light)
    }

    private func band(_ moment: SmallIsland.Moment) -> some View {
        ZStack(alignment: .top) {
            SmallMenuBar { EmptyView() }
            SmallIsland(moment: moment)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The island in one moment, hanging from the top center of what it is placed in.
struct SmallIsland: View {
    nonisolated enum Moment: Hashable, Sendable {
        /// The ring is linked and nothing is being said.
        case resting
        /// A hold: the settled words, and the ones still forming.
        case holding(heard: String, hearing: String)
        /// Let go: who it went to, what was said, and where it went.
        case landed(chip: String, words: String, note: String)
    }

    let moment: Moment

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                mark
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: SmallMetrics.notch.width)
                rightEar
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, MuseSpacing.md)
            .frame(height: SmallMetrics.notch.height)
            if hasLine {
                line
                    .padding(.horizontal, MuseSpacing.lg)
                    .frame(height: SmallMetrics.islandLine - MuseSpacing.xs, alignment: .center)
                    .padding(.bottom, MuseSpacing.xs)
            }
        }
        .frame(width: width - SmallMetrics.islandTop * 2)
        .padding(.horizontal, SmallMetrics.islandTop)
        .background(SmallColor.notch, in: NotchShape(top: SmallMetrics.islandTop, bottom: hasLine ? SmallMetrics.islandBottom : SmallMetrics.islandRestBottom))
        .museElevation(.e2)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
    }

    private var hasLine: Bool { moment != .resting }

    private var width: CGFloat {
        let ear = hasLine ? SmallMetrics.wideEar : SmallMetrics.restEar
        return SmallMetrics.notch.width + ear * 2 + SmallMetrics.islandTop * 2
    }

    // MARK: - Ears

    /// The kit's halftone ring in pale ink; its white light shows while you hold.
    private var mark: some View {
        PocketHalftoneRing(
            size: SmallMetrics.islandMark,
            ink: SmallColor.pale,
            light: isHolding ? .white : nil,
            dots: SmallMetrics.islandMarkDots
        )
        .frame(width: SmallMetrics.islandMark, height: SmallMetrics.islandMark)
    }

    private var isHolding: Bool {
        if case .holding = moment { return true }
        return false
    }

    @ViewBuilder
    private var rightEar: some View {
        switch moment {
        case .resting:
            EmptyView()
        case .holding:
            // Five bars, louder in the middle: the voice, as today.
            HStack(spacing: SmallMetrics.voiceGap) {
                ForEach(Array(Self.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(SmallColor.pale.opacity(0.9))
                        .frame(width: SmallMetrics.voiceBar, height: SmallMetrics.voiceBar + SmallMetrics.voiceReach * level)
                }
            }
        case .landed(_, _, let note):
            HStack(spacing: MuseSpacing.xxs + MuseSpacing.xxs / 2) {
                Image(systemName: "checkmark")
                    .museSymbol(SmallMetrics.chevron, weight: .semibold)
                    .foregroundStyle(MuseColor.orbHighlight)
                Text(note)
                    .font(MuseType.captionMedium)
                    .foregroundStyle(SmallColor.pale.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private static let levels: [CGFloat] = [0.3, 0.72, 1, 0.55, 0.38]

    // MARK: - The line

    @ViewBuilder
    private var line: some View {
        switch moment {
        case .resting:
            EmptyView()
        case .holding(let heard, let hearing):
            Text(smallInk(heard, SmallColor.pale, then: " " + hearing, SmallColor.pale.opacity(SmallMetrics.forming)))
                .font(MuseFont.lora(SmallMetrics.islandWords))
                .lineLimit(1)
                .truncationMode(.head)
        case .landed(let chip, let words, _):
            HStack(spacing: MuseSpacing.xs + MuseSpacing.xxs / 2) {
                Text(chip)
                    .font(MuseType.captionMedium)
                    .foregroundStyle(SmallColor.pale)
                    .padding(.horizontal, MuseSpacing.xs)
                    .frame(height: SmallMetrics.chipHeight)
                    .background(SmallColor.pale.opacity(0.12), in: Capsule(style: .circular))
                    .overlay { Capsule(style: .circular).strokeBorder(SmallColor.pale.opacity(0.4), lineWidth: 1) }
                    .fixedSize()
                Text(words)
                    .font(MuseFont.lora(SmallMetrics.islandWords))
                    .foregroundStyle(SmallColor.pale)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
    }

    private var spoken: String {
        switch moment {
        case .resting: "museo, ring linked"
        case .holding(let heard, let hearing): "streaming. \(heard) \(hearing)"
        case .landed(let chip, let words, let note): "\(note). \(chip), \(words)"
        }
    }
}
#endif
