#if DEBUG
import SwiftUI

/// Someone's thought on museo.fm, opened like one of yours: their words, the city and the
/// hour, their voice if they gave it. One of yours can be taken back. Nothing else.
struct PocketFMThoughtPage: View {
    let thought: PocketFMThought

    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var asksTakeBack = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PocketGlassCircle("chevron.left", label: "back") { dismiss() }
                    .padding(.horizontal, PocketGrid.gutter)

                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    PocketBalanced {
                        Text(thought.words)
                            .font(MuseType.title)
                            .tracking(MuseType.titleTracking)
                            .lineSpacing(MuseType.serifLineSpacing)
                            .foregroundStyle(MuseColor.ink)
                    }
                    Text(thought.foot)
                        .font(MuseType.body)
                        .monospacedDigit()
                        .foregroundStyle(MuseColor.ink55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PocketFMMetrics.inset)
                .padding(.top, PocketFMMetrics.air)
                .accessibilityElement(children: .combine)

                if thought.isYours {
                    takeItBack
                        .padding(.horizontal, PocketFMMetrics.inset)
                        .padding(.top, MuseSpacing.section)
                }
            }
            .padding(.top, PocketChrome.top)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .pocketChromeFade()
        .safeAreaInset(edge: .bottom) {
            if thought.hasVoice {
                listen
                    .padding(.bottom, MuseSpacing.sm)
            }
        }
        .background { PocketGround() }
        .pocketPushedPage()
        .confirmationDialog("take this one back?", isPresented: $asksTakeBack, titleVisibility: .visible) {
            Button("take it back", role: .destructive) { dismiss() }
            Button("leave it here", role: .cancel) {}
        } message: {
            Text("it leaves museo.fm. it stays in your library.")
        }
    }

    // MARK: - Pieces

    /// The screen's one clay mark.
    private var takeItBack: some View {
        Button {
            MuseHaptics.play(.soft)
            asksTakeBack = true
        } label: {
            Text("take it back")
                .font(MuseType.label)
                .foregroundStyle(MuseColor.clay)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.97))
    }

    /// Their voice: a glass capsule floating at the foot of the page.
    private var listen: some View {
        Button {
            MuseHaptics.play(.soft)
            isPlaying.toggle()
        } label: {
            HStack(spacing: MuseSpacing.sm) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .museSymbol(PocketGlassMetrics.symbol, weight: .medium)
                    .foregroundStyle(MuseColor.ink70)
                PocketFMWaveform(seed: thought.id, progress: isPlaying ? PocketFMMetrics.heard : 0)
                    .frame(width: Self.wave, height: PocketFMMetrics.waveHeight)
                    .museAnimation(MuseMotion.gentle, value: isPlaying)
            }
            .padding(.horizontal, MuseSpacing.lg)
            .frame(minHeight: PocketRingPillMetrics.height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pocketControlGlass()
        .accessibilityLabel(isPlaying ? "pause" : "listen")
    }

    /// The capsule's waveform width: a short phrase, not a scrubber.
    private static let wave: CGFloat = 132
}

#Preview {
    NavigationStack {
        PocketFMThoughtPage(thought: PocketFixtures.fmThoughts[0])
    }
}
#endif
