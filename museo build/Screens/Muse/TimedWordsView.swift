import SwiftUI

/// A muse's words on its page, large, in Lora. While the muse plays each word inks in as
/// it is said; tap a word to hear it from there. Without word timings
/// (typed muses, an edited transcript, an older muse) it is plain, selectable text.
///
/// ```swift
/// TimedWordsView(muse: muse, player: player)
/// ```
///
/// Redraws only while the muse plays, and then only when a word's ink changes.
struct TimedWordsView: View {
    let muse: Muse
    let player: MuseAudioPlayer
    /// Timings to use instead of the saved ones (lab screens and previews).
    var timings: TimedTranscript?
    /// The page shows a title above the words: they stay below its size (Lora 28).
    var titled: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spoken: SpokenWords?
    /// When playback last left rest: the unspoken words ease down from full from here.
    @State private var settledFrom = Date.distantPast

    init(muse: Muse, player: MuseAudioPlayer, timings: TimedTranscript? = nil, titled: Bool = false) {
        self.muse = muse
        self.player = player
        self.timings = timings
        self.titled = titled
    }

    // MARK: Type

    /// The words' size by how much was said: short muses read like a headline.
    static func size(forCharacters count: Int) -> CGFloat {
        switch count {
        case ..<70: 30
        case ..<160: 28
        case ..<360: 24
        case ..<700: 21
        default: 19
        }
    }

    /// Past this many words the page draws one `Text` (it still inks, but a tap can't
    /// pick a word): thousands of tappable views cost more than they give.
    private static let tappableLimit = 1_200

    private var text: String { muse.words.museQuoted }
    private var size: CGFloat {
        let size = Self.size(forCharacters: muse.words.count)
        return titled ? min(size, 24) : size
    }
    private var font: Font { MuseFont.lora(size) }

    // MARK: Body

    var body: some View {
        let text = text
        Group {
            if let spoken, spoken.text == text {
                timed(spoken)
            } else {
                plain(text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: player.isAtRest) { _, atRest in
            if !atRest { settledFrom = .now }
        }
        .onAppear {
            // The words landed while it played (transcribed again): settle in from full.
            if !player.isAtRest { settledFrom = .now }
        }
        .task(id: LoadKey(id: muse.id, text: text, injected: timings?.updatedAt)) {
            let loaded = await SpokenWords.load(
                id: muse.id,
                transcript: muse.words,
                text: text,
                injected: timings
            )
            guard !Task.isCancelled else { return }
            spoken = loaded
        }
    }

    private func timed(_ spoken: SpokenWords) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !player.isPlaying)) { context in
            inked(spoken, alphas: alphas(for: spoken, at: context.date))
        }
        // One element for VoiceOver: the words, read whole, with a way to hear them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(muse.words)
        .accessibilityAction(named: "play from the start") {
            guard player.canPlay else { return }
            player.play(from: 0)
        }
    }

    @ViewBuilder
    private func inked(_ spoken: SpokenWords, alphas: [Double]?) -> some View {
        if spoken.words.count <= Self.tappableLimit {
            let onTap: ((SpokenWords.Word) -> Void)? = player.canPlay ? { play(from: $0) } : nil
            WordFlowText(spoken: spoken, alphas: alphas, size: size, font: font, onTap: onTap)
                .equatable()
        } else {
            Text(spoken.attributed(alphas: alphas))
                .font(font)
                .lineSpacing(size * Self.lineSpacingRatio)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func plain(_ text: String) -> some View {
        Text(text)
            .font(font)
            .lineSpacing(size * Self.lineSpacingRatio)
            .foregroundStyle(MuseColor.ink)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Ink

    /// Space between words and lines, as fractions of the type size.
    fileprivate static let wordSpacingRatio: CGFloat = 0.25
    fileprivate static let lineSpacingRatio: CGFloat = 0.14

    /// How long the unspoken words take to fade down when playback starts from rest.
    private static let settleSeconds = 0.22

    /// Each word's ink right now, or nil at rest (every word full).
    private func alphas(for spoken: SpokenWords, at date: Date) -> [Double]? {
        guard !player.isAtRest else { return nil }
        let ms = Int(player.elapsed * 1000)
        let settle = player.isPlaying && !reduceMotion
            ? min(1, max(0, date.timeIntervalSince(settledFrom)) / Self.settleSeconds)
            : 1
        return spoken.words.map {
            SpokenWords.alpha(startMs: $0.startMs, endMs: $0.endMs, ms: ms, settle: settle, stepped: reduceMotion)
        }
    }

    /// From the word's onset, a beat early, playing.
    private func play(from word: SpokenWords.Word) {
        MuseHaptics.play(.selection)
        let lead = SpokenWords.leadMs
        player.play(from: max(0, Double(word.startMs - lead)) / 1000)
    }

    private struct LoadKey: Equatable {
        let id: UUID
        let text: String
        let injected: Date?
    }
}

// MARK: - Timing

/// The displayed text cut into words, each with when it was said and what follows it
/// (a space, a line break, a paragraph).
nonisolated struct SpokenWords: Sendable, Equatable {
    nonisolated struct Word: Sendable, Equatable {
        let text: String
        let startMs: Int
        let endMs: Int
        /// Line breaks after this word in the transcript: 0 flows on, 1 starts a new line,
        /// 2 or more leaves a paragraph gap.
        let breaks: Int
    }

    let text: String
    let words: [Word]

    // How the words ink in as they're said, so the page reads at the speaker's pace.

    /// Unspoken words stay faintly present, so you see the shape of the thought.
    static let ghostAlpha = 0.16
    /// Words light a little before their onset: perception lags audio.
    static let leadMs = 60
    static let revealMinMs = 160
    static let revealMaxMs = 280

    static func revealMs(startMs: Int, endMs: Int) -> Int {
        min(max((endMs - startMs) / 2, revealMinMs), revealMaxMs)
    }

    /// Faint before the word, full once it has landed (`1 - (1 - t)^3`). `settle` (0...1)
    /// eases the unspoken words down from full as playback starts. `stepped` (Reduce
    /// Motion) lights each word at once instead of easing it in.
    static func alpha(startMs: Int, endMs: Int, ms: Int, settle: Double, stepped: Bool) -> Double {
        let lead = Double(leadMs)
        let reveal = Double(revealMs(startMs: startMs, endMs: endMs))
        let t = min(max((Double(ms) - (Double(startMs) - lead)) / reveal, 0), 1)
        let lit = stepped ? (t > 0 ? 1 : 0) : 1 - pow(1 - t, 3)
        let target = ghostAlpha + (1 - ghostAlpha) * lit
        let alpha = 1 + (target - 1) * settle
        // Rounded so a frame where nothing visibly changed doesn't redraw the words.
        return (alpha * 100).rounded() / 100
    }

    /// Nil when the muse has no timings or they no longer describe its words (it was
    /// transcribed again, or edited): the page then shows plain text. Off the main actor:
    /// it reads a file and walks every word.
    @concurrent
    static func load(id: UUID, transcript: String, text: String, injected: TimedTranscript?) async -> SpokenWords? {
        guard let timed = injected ?? TimedTranscriptStore.load(id),
              timed.transcript.trimmingCharacters(in: .whitespacesAndNewlines) == transcript
        else { return nil }
        return make(text: text, timings: timed)
    }

    /// Projects `timings` onto the whitespace tokens of `text` (quotes ride on the first
    /// and last word, so the tokens match one for one).
    static func make(text: String, timings: TimedTranscript) -> SpokenWords? {
        var tokens: [(text: String, breaks: Int)] = []
        var current = ""
        var newlines = 0
        for character in text {
            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append((current, 0))
                    current = ""
                    newlines = 0
                }
                if character.isNewline {
                    newlines += 1
                    if let last = tokens.indices.last { tokens[last].breaks = newlines }
                }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append((current, 0)) }
        guard let timed = SpeechTokens.project(timings.words, onto: tokens.map(\.text)) else { return nil }
        let words = zip(tokens, timed).map { token, time in
            Word(text: token.text, startMs: time.startMs, endMs: time.endMs, breaks: token.breaks)
        }
        return SpokenWords(text: text, words: words)
    }

    /// One `Text` for long muses: runs of words at the same ink share a piece, so a frame
    /// costs a handful of pieces (spoken, lighting, still to come), not one per word.
    func attributed(alphas: [Double]?) -> AttributedString {
        var result = AttributedString()
        var run = ""
        var runAlpha = alphas?.first ?? 1
        func flush() {
            guard !run.isEmpty else { return }
            var piece = AttributedString(run)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = MuseColor.ink.opacity(runAlpha)
            result += piece
            run = ""
        }
        for (index, word) in words.enumerated() {
            let alpha = alphas?[index] ?? 1
            if alpha != runAlpha {
                flush()
                runAlpha = alpha
            }
            run += word.text
            if index < words.count - 1 {
                run += word.breaks == 0 ? " " : String(repeating: "\n", count: min(word.breaks, 2))
            }
        }
        flush()
        return result
    }
}

// MARK: - Words

/// The laid-out words at one moment. Equatable on each word's ink, so the 30 fps tick
/// only redraws while a word is lighting.
private struct WordFlowText: View, Equatable {
    let spoken: SpokenWords
    /// Each word's ink, 0...1; nil at rest (every word full).
    let alphas: [Double]?
    let size: CGFloat
    let font: Font
    let onTap: ((SpokenWords.Word) -> Void)?
    /// Whether a tap does anything; compared instead of the closure.
    let tappable: Bool

    init(spoken: SpokenWords, alphas: [Double]?, size: CGFloat, font: Font, onTap: ((SpokenWords.Word) -> Void)?) {
        self.spoken = spoken
        self.alphas = alphas
        self.size = size
        self.font = font
        self.onTap = onTap
        tappable = onTap != nil
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.alphas == rhs.alphas && lhs.size == rhs.size && lhs.tappable == rhs.tappable
            && lhs.spoken == rhs.spoken
    }

    var body: some View {
        let wordGap = size * TimedWordsView.wordSpacingRatio
        let lineGap = size * TimedWordsView.lineSpacingRatio
        WordFlow(paragraphGap: size * 0.45) {
            ForEach(spoken.words.indices, id: \.self) { index in
                let word = spoken.words[index]
                Text(word.text)
                    .font(font)
                    .foregroundStyle(MuseColor.ink.opacity(alphas?[index] ?? 1))
                    // Half the gaps as padding on every side, so the hit areas tile
                    // without holes and the words keep their spacing.
                    .padding(.horizontal, wordGap / 2)
                    .padding(.vertical, lineGap / 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap?(word)
                    }
                    .layoutValue(key: WordBreaks.self, value: word.breaks)
            }
        }
        .padding(.horizontal, -wordGap / 2)
        .padding(.vertical, -lineGap / 2)
    }
}

/// Line breaks after this word in the transcript.
nonisolated private struct WordBreaks: LayoutValueKey {
    static let defaultValue = 0
}

/// Words left to right, wrapping like text, one view per word so each can be tapped.
/// Keeps the transcript's own line breaks and paragraphs (`MuseFlowLayout` can't).
nonisolated private struct WordFlow: Layout {
    /// Extra space before a new paragraph.
    var paragraphGap: CGFloat

    /// The last arrangement, so placing reuses what sizing measured (a long muse is
    /// hundreds of words). SwiftUI drops it whenever the words change.
    struct Cache {
        var width: CGFloat?
        var frames: [CGRect] = []
        var height: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 360
        let arranged = arranged(width: width, subviews: subviews, cache: &cache)
        return CGSize(width: width, height: arranged.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let arranged = arranged(width: bounds.width, subviews: subviews, cache: &cache)
        for (index, frame) in arranged.frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arranged(width: CGFloat, subviews: Subviews, cache: inout Cache) -> (frames: [CGRect], height: CGFloat) {
        if cache.width == width, cache.frames.count == subviews.count {
            return (cache.frames, cache.height)
        }
        let fresh = arrange(width: width, subviews: subviews)
        cache = Cache(width: width, frames: fresh.frames, height: fresh.height)
        return fresh
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var breaksBefore = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width {
                // A token longer than the line (a link) wraps inside itself.
                size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            }
            if breaksBefore > 0 || (x > 0 && x + size.width > width) {
                y += lineHeight + (breaksBefore > 1 ? paragraphGap : 0)
                x = 0
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width
            lineHeight = max(lineHeight, size.height)
            breaksBefore = subview[WordBreaks.self]
        }
        return (frames, y + lineHeight)
    }
}

// MARK: - Fixtures

extension TimedWordsView {
    /// Evenly spaced timings for `text` over `duration` seconds, for lab screens and
    /// previews where no engine has timed the words.
    static func sampleTimings(for text: String, duration: TimeInterval) -> TimedTranscript {
        let tokens = SpeechTokens.split(text).filter(SpeechTokens.isWordBearing)
        let step = tokens.isEmpty ? 0 : Int(duration * 1000) / tokens.count
        let words = tokens.enumerated().map { index, token in
            TimedWord(text: token, startMs: index * step, endMs: index * step + max(step - 40, 1))
        }
        return TimedTranscript(
            version: TimedTranscript.currentVersion,
            transcript: text,
            words: words,
            segments: [],
            language: "en",
            textModel: "sample",
            timingModel: "even",
            updatedAt: .distantPast
        )
    }
}

// MARK: - Preview

#Preview("timed words · playing") {
    let text = "remind me to call mum back about the shop sign. and the kettle sound, keep that one for the record."
    let muse = Muse(
        createdAt: .now.addingTimeInterval(-180),
        duration: 9,
        origin: .stream,
        transcript: text,
        transcriptionState: .complete
    )
    ScrollView {
        TimedWordsView(
            muse: muse,
            player: .preview(duration: 9),
            timings: TimedWordsView.sampleTimings(for: text, duration: 9)
        )
        .padding(.horizontal, MuseSpacing.page)
        .padding(.vertical, MuseSpacing.xl)
    }
    .background { MuseBackground() }
}
