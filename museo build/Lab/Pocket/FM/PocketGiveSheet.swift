#if DEBUG
import SwiftUI

/// Giving a thought to museo.fm: the thought, one sentence on what becomes public, with
/// my voice or words only, then give it or keep it mine. Sits on the sheet's own paper.
struct PocketGiveSheet: View {
    let thought: PocketThought

    @Environment(\.dismiss) private var dismiss
    @State private var withVoice = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(thought.title)
                .font(MuseType.titleSmall)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("anyone can hear this on museo.fm: the words, your city and the hour. never your name.")
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MuseSpacing.sm)

            VStack(spacing: 0) {
                choice("with my voice", isOn: withVoice) { withVoice = true }
                Rectangle()
                    .fill(MuseColor.hairline)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                choice("words only", isOn: !withVoice) { withVoice = false }
            }
            .padding(.top, MuseSpacing.md)

            if thought.origin == .memory {
                Text("someone else's voice in this one? then keep it yours.")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, MuseSpacing.xs)
            }

            VStack(spacing: MuseSpacing.xxs) {
                Button {
                    MuseHaptics.play(.soft)
                    dismiss()
                } label: {
                    Text("give it")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ground)
                        .frame(maxWidth: .infinity, minHeight: PocketRingPillMetrics.height)
                        .contentShape(Capsule())
                        .pocketMossPill()
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.98))

                MuseQuietButton("keep it mine") { dismiss() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, MuseSpacing.xl)
        }
        .padding(.horizontal, MuseSpacing.xl)
        .padding(.top, MuseSpacing.xl)
        .padding(.bottom, MuseSpacing.xs)
    }

    /// One plain row of the choice: the words, and a moss check on the one chosen.
    private func choice(_ title: String, isOn: Bool, pick: @escaping () -> Void) -> some View {
        Button {
            MuseHaptics.play(.soft)
            pick()
        } label: {
            HStack {
                Text(title)
                    .font(MuseType.label)
                    .foregroundStyle(isOn ? MuseColor.ink : MuseColor.ink70)
                Spacer()
                Image(systemName: "checkmark")
                    .museSymbol(PocketGlassMetrics.symbol - 2, weight: .medium)
                    .foregroundStyle(MuseColor.moss600)
                    .opacity(isOn ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: MuseTopChrome.hitTarget + MuseSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .museAnimation(MuseMotion.select, value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    PocketGiveSheet(thought: PocketFixtures.supper)
        .background(MuseColor.raised)
}
#endif
