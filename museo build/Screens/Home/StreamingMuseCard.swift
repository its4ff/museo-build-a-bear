import SwiftUI
import MuseoKit

/// The card at the top of the home while the ring streams a muse in (press and hold).
///
/// Listening: a linen orb, "listening", a clock counting up from when the take began, and
/// their words forming under it as they speak (`LiveWords`, when this iphone has the speech
/// model). Once you let go it holds for a moment as "sending", the clock stopped, until
/// the muse itself lands in its place (the home swaps them in one movement).
struct StreamingMuseCard: View {
    /// When the take began (`RingStatus.liveSince`).
    let since: Date
    /// When the take ended. Nil while still listening.
    var endedAt: Date?
    /// Words the recognizer has settled on, and the ones still forming (`LiveWords`).
    var heard: String = ""
    var hearing: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isListening: Bool { endedAt == nil }
    private var hasWords: Bool { !heard.isEmpty || !hearing.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            header
            if hasWords {
                words
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: isListening)
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: hasWords)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isListening ? "listening, from the ring" : "sending, words in a moment")
        .accessibilityValue(hasWords ? Text(verbatim: [heard, hearing].filter { !$0.isEmpty }.joined(separator: " ")) : spokenTime)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: MuseSpacing.md) {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                MuseEyebrow(isListening ? "listening" : "sending", color: MuseColor.moss600)
                    .contentTransition(.opacity)
                clock
                HStack(spacing: MuseSpacing.xxs + 2) {
                    MuseRingMark(size: 10, color: MuseColor.ink55)
                    Text(isListening ? "from the ring" : "from the ring · words in a moment")
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                        .contentTransition(.opacity)
                }
            }
            Spacer(minLength: MuseSpacing.sm)
            MuseOrb(mode: isListening ? .listening : .thinking, size: MuseOrb.Size.chat)
        }
    }

    /// Their words as they say them, in Lora: settled in ink, still forming in a lighter ink.
    /// The newest stay in view; older lines give way at the top.
    private var words: some View {
        let gap = heard.isEmpty || hearing.isEmpty ? "" : " "
        return Text("\(Text(heard).foregroundStyle(MuseColor.ink))\(gap)\(Text(hearing).foregroundStyle(MuseColor.ink55))")
            .font(MuseType.serif)
            .lineSpacing(MuseType.serifLineSpacing)
            .lineLimit(4)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// How long the take has run, for VoiceOver: a running clock, or where it stopped.
    private var spokenTime: Text {
        if let endedAt {
            Text(verbatim: max(0, endedAt.timeIntervalSince(since)).museDuration)
        } else {
            Text(since, style: .timer)
        }
    }

    /// Counts up while listening; stops where the take ended.
    private var clock: some View {
        Text(timerInterval: since...Date.distantFuture, pauseTime: endedAt, countsDown: false)
            .font(MuseType.title)
            .tracking(MuseType.titleTracking)
            .monospacedDigit()
            .foregroundStyle(MuseColor.ink)
            .lineLimit(1)
    }
}

#Preview("streaming card") {
    VStack(spacing: MuseSpacing.sm) {
        StreamingMuseCard(since: Date(timeIntervalSinceNow: -7))
        StreamingMuseCard(
            since: Date(timeIntervalSinceNow: -4),
            heard: "the light on the canal at six is",
            hearing: "the green we want for"
        )
        StreamingMuseCard(since: Date(timeIntervalSinceNow: -19), endedAt: Date(timeIntervalSinceNow: -1))
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseBackground() }
}
