import SwiftUI

/// The muse page's one control: a white capsule floating in reach of the thumb, with the
/// muse's own voiceprint inside. The glyph plays and pauses; a touch on the bars moves
/// through the muse and plays from there. Redraws only while it plays.
///
/// ```swift
/// .safeAreaBar(edge: .bottom) { ListenCapsule(audioURL: url, player: player) }
/// ```
struct ListenCapsule: View {
    /// The recording the bars are drawn from. Nil draws a sample shape (lab, previews).
    let audioURL: URL?
    let player: MuseAudioPlayer

    /// How many bars the voiceprint folds into.
    nonisolated static let barCount = 30
    /// Wide enough for 30 bars, narrow enough to float.
    private static let width: CGFloat = 284
    /// A 44pt glyph with a little air above and below.
    private static let height: CGFloat = MuseTopChrome.hitTarget + MuseSpacing.card
    private static let barSpacing: CGFloat = 2.5
    private static let barsHeight: CGFloat = 30
    /// Room for "12:34" without the bars shifting as it counts down.
    private static let timeWidth: CGFloat = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var levels: [Float] = Array(repeating: 0, count: ListenCapsule.barCount)
    /// Where a finger on the bars is, 0...1. Gesture state, so a drag the system cancels
    /// (a call, the sheet closing) can't leave the capsule stuck mid-scrub.
    @GestureState private var scrub: Double?
    @State private var barsWidth: CGFloat = 1

    init(audioURL: URL?, player: MuseAudioPlayer) {
        self.audioURL = audioURL
        self.player = player
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !player.isPlaying || scrub != nil)) { _ in
            let duration = max(player.duration, 0.1)
            // Nil is rest: every bar the same soft moss.
            let fraction: Double? = scrub ?? (player.isAtRest ? nil : player.elapsed / duration)
            HStack(spacing: MuseSpacing.xs) {
                playButton
                bars(fraction: fraction)
                Text(remaining(fraction: fraction, duration: duration).museDuration)
                    .font(MuseFont.satoshi(14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
                    .lineLimit(1)
                    // The capsule keeps its size; the time grows only so far inside it.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(minWidth: Self.timeWidth, alignment: .trailing)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("time left")
                    .accessibilityValue(remaining(fraction: fraction, duration: duration).museDuration)
            }
            // The glyph's 44pt circle sits centered in the capsule's rounded end.
            .padding(.leading, (Self.height - MuseTopChrome.hitTarget) / 2)
            .padding(.trailing, MuseSpacing.lg)
            .frame(width: Self.width, height: Self.height)
        }
        .museStock(.composer, in: Capsule())
        .task(id: audioURL) {
            let read = if let audioURL { await Self.voiceprint(audioURL) } else { Self.sampleLevels }
            withAnimation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion)) {
                levels = read
            }
        }
    }

    // MARK: Pieces

    private var playButton: some View {
        Button {
            MuseHaptics.play(player.isPlaying ? .light : .soft)
            player.toggle()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(MuseFont.symbol(17, weight: .bold))
                .foregroundStyle(MuseColor.moss700)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.86))
        .disabled(!player.canPlay)
        .accessibilityLabel(player.isPlaying ? "pause" : "play")
    }

    private func bars(fraction: Double?) -> some View {
        HStack(alignment: .center, spacing: Self.barSpacing) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(color(for: index, fraction: fraction))
                    .frame(height: 4 + CGFloat(pow(Double(levels[index]), 0.7)) * 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.barsHeight)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barsWidth = max($0, 1) }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($scrub) { value, scrub, _ in
                    let next = min(max(value.location.x / barsWidth, 0), 1)
                    // A light click each time the finger crosses into another bar.
                    if let previous = scrub, bar(at: previous) != bar(at: next) {
                        MuseHaptics.play(.selection)
                    }
                    scrub = next
                }
                .onEnded { value in
                    let target = min(max(value.location.x / barsWidth, 0), 1)
                    MuseHaptics.play(.soft)
                    player.play(from: target * player.duration)
                }
        )
        .accessibilityElement()
        .accessibilityLabel("playback position")
        .accessibilityValue("\(Int(((fraction ?? 0) * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 0.1 : -0.1
            player.seek(toFraction: (fraction ?? 0) + step)
        }
    }

    private func bar(at fraction: Double) -> Int {
        min(Int(fraction * Double(Self.barCount)), Self.barCount - 1)
    }

    /// Heard bars in moss, the rest faint; at rest all of them a soft moss.
    private func color(for index: Int, fraction: Double?) -> Color {
        guard let fraction else { return MuseColor.moss700.opacity(0.75) }
        return (Double(index) + 0.5) / Double(levels.count) <= fraction
            ? MuseColor.moss700
            : MuseColor.ink.opacity(0.22)
    }

    private func remaining(fraction: Double?, duration: TimeInterval) -> TimeInterval {
        guard let fraction else { return player.duration }
        return max(duration * (1 - fraction), 0)
    }

    /// A speaking shape for previews: phrases that swell and fall, a breath between.
    static let sampleLevels: [Float] = (0..<barCount).map { index in
        let phrase = sin(Double(index) / Double(barCount) * .pi * 3.2)
        let syllable = sin(Double(index) * 2.3) * 0.25
        return Float(min(max(abs(phrase) * 0.8 + syllable + 0.12, 0.05), 1))
    }

    /// The voiceprint, read off the main actor (cached per file).
    @concurrent
    nonisolated private static func voiceprint(_ url: URL) async -> [Float] {
        Voiceprint.bars(for: url, count: barCount)
    }
}

// MARK: - Studio sound

/// "raw · clean" above the capsule when studio sound is on (build › speech). Picking
/// clean makes a cleaner copy the first time ("cleaning…") and plays it from the same
/// spot. `onNote` gets a quiet line when the copy can't be made.
struct StudioSoundPicker: View {
    let player: MuseAudioPlayer
    var onNote: (String) -> Void = { _ in }

    @State private var pick: MuseAudioPlayer.Sound = .raw

    init(player: MuseAudioPlayer, onNote: @escaping (String) -> Void = { _ in }) {
        self.player = player
        self.onNote = onNote
    }

    var body: some View {
        MuseSegmented(
            selection: $pick,
            options: [
                (.raw, "raw"),
                (.clean, player.isCleaning ? "cleaning…" : "clean"),
            ]
        )
        .musePill(.chrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("studio sound")
        .onAppear { pick = player.sound }
        // The player goes back to raw on its own (a new muse loads): follow it, so the
        // picker never says clean over the original.
        .onChange(of: player.sound) { _, sound in
            if pick != sound { pick = sound }
        }
        // Tied to the picker: leaving the page drops a copy still cleaning.
        .task(id: pick) {
            guard let note = await player.choose(pick), !Task.isCancelled else { return }
            pick = player.sound
            MuseHaptics.play(.warning)
            onNote(note)
        }
    }
}

// MARK: - Preview

#Preview("listen capsule") {
    VStack(spacing: MuseSpacing.lg) {
        StudioSoundPicker(player: .preview(duration: 12, elapsed: 4, playing: false))
        ListenCapsule(audioURL: nil, player: .preview(duration: 12, elapsed: 4, playing: true))
        ListenCapsule(audioURL: nil, player: .preview(duration: 12, playing: false))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { MuseBackground() }
}
