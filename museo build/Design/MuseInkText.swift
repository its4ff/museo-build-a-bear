import SwiftUI

// Words that arrive, typed in: the whole
// line is laid out from the first frame, so wrapping never jumps; a TextRenderer decides
// what's visible, and each letter settles in like ink (a quick fade, a breath of blur, a
// 2pt rise over 0.18s) instead of popping on. Every keystroke can be felt through
// `MuseKeyHaptics`: faint letters, a firmer start to each word, a rounded pause at a
// comma, a deep full stop.

// MARK: - Ink text

/// Text that types itself in. Use it for words that just arrived (a fresh muse on home);
/// everywhere else use plain `Text`.
///
/// - `startsTyping`: false holds the words back (their space reserved) until it turns
///   true, then they type in. Pass true to type on appear.
/// - `finishNow`: lands whatever is left at once (a tap to hurry).
/// - `typingLimit`: characters typed one by one; the rest lands in one go, so a card that
///   clips at four lines never types words nobody can see.
/// - Reduce Motion shows the words at once, silently. `onFinish` runs once in every case.
struct MuseInkText: View {
    let text: String
    let font: Font
    let color: Color
    let startsTyping: Bool
    let haptics: Bool
    let hapticStrength: Float
    let pace: Duration
    let typingLimit: Int
    let finishNow: Bool
    let onFinish: (() -> Void)?

    /// When each ink unit was typed (seconds since the reference date); infinity = not yet.
    @State private var typedAt: [Double] = []
    @State private var inking = false
    @State private var finished = false
    @State private var typing: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ text: String,
        font: Font = MuseType.serif,
        color: Color = MuseColor.ink,
        startsTyping: Bool = true,
        haptics: Bool = true,
        hapticStrength: Float = 0.6,
        pace: Duration = .seconds(0.028),
        typingLimit: Int = 320,
        finishNow: Bool = false,
        onFinish: (() -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.startsTyping = startsTyping
        self.haptics = haptics
        self.hapticStrength = hapticStrength
        self.pace = pace
        self.typingLimit = typingLimit
        self.finishNow = finishNow
        self.onFinish = onFinish
    }

    var body: some View {
        // Redrawn every frame only while letters are still settling.
        TimelineView(.animation(paused: !inking)) { timeline in
            MuseInkLine(text: text, limit: typingLimit)
                .equatable()
                .textRenderer(
                    MuseInkRenderer(
                        now: timeline.date.timeIntervalSinceReferenceDate,
                        typedAt: typedAt,
                        settle: reduceMotion ? 0 : 0.18
                    )
                )
        }
        .font(font)
        .foregroundStyle(color)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onAppear(perform: begin)
        .onChange(of: startsTyping) { _, starts in
            if starts, !finished, typing == nil { startTyping() }
        }
        .onChange(of: finishNow) { _, now in
            if now { land() }
        }
        .onChange(of: text) { _, _ in
            // New words mid-life (a retranscribe): show them, don't type them again.
            typing?.cancel()
            typing = nil
            typedAt = Array(repeating: 0, count: MuseInkUnits.split(text, limit: typingLimit).count)
            inking = false
            complete()
        }
        .onDisappear {
            typing?.cancel()
            typing = nil
        }
    }

    // MARK: Typing

    private func begin() {
        let count = MuseInkUnits.split(text, limit: typingLimit).count
        if finished, typedAt.count == count { return }
        typedAt = Array(repeating: .infinity, count: count)
        if reduceMotion {
            typedAt = Array(repeating: 0, count: count)
            complete()
        } else if finishNow {
            land()
        } else if startsTyping {
            startTyping()
        }
    }

    private func startTyping() {
        typing?.cancel()
        let units = MuseInkUnits.split(text, limit: typingLimit)
        let typedCount = MuseInkUnits.typedCount(text, limit: typingLimit)
        typedAt = Array(repeating: .infinity, count: units.count)
        inking = true
        if haptics { MuseKeyHaptics.shared.prepare() }

        typing = Task {
            var startsWord = true
            for index in 0..<typedCount {
                guard !Task.isCancelled else { return }
                let unit = units[index]
                try? await Task.sleep(for: pause(for: unit))
                guard !Task.isCancelled else { return }
                if typedAt.indices.contains(index) {
                    typedAt[index] = Date.timeIntervalSinceReferenceDate
                }
                if haptics { key(for: unit, startsWord: startsWord) }
                startsWord = unit.last?.isWhitespace ?? true
            }
            // Past the limit, the rest lands in one go.
            if typedAt.count > typedCount {
                typedAt[typedCount] = Date.timeIntervalSinceReferenceDate
            }
            complete()
            // Let the last letter settle, then stop redrawing.
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            inking = false
            typing = nil
        }
    }

    /// Lands whatever is left: a few ms apart, a quarter second at most, so the rest still
    /// inks in rather than popping on together.
    private func land() {
        typing?.cancel()
        typing = nil
        let count = MuseInkUnits.split(text, limit: typingLimit).count
        if typedAt.count != count {
            typedAt = Array(repeating: .infinity, count: count)
        }
        let untyped = typedAt.indices.filter { !typedAt[$0].isFinite }
        guard !untyped.isEmpty, !reduceMotion else {
            typedAt = Array(repeating: 0, count: count)
            inking = false
            complete()
            return
        }
        let now = Date.timeIntervalSinceReferenceDate
        let step = min(0.006, 0.25 / Double(untyped.count))
        for (order, index) in untyped.enumerated() {
            typedAt[index] = now + Double(order) * step
        }
        inking = true
        complete()
        typing = Task {
            try? await Task.sleep(for: .seconds(step * Double(untyped.count) + 0.3))
            guard !Task.isCancelled else { return }
            inking = false
            typing = nil
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        onFinish?()
    }

    /// A hand types unevenly, and pauses where a voice would.
    private func pause(for unit: String) -> Duration {
        let base = Double(pace.components.seconds) + Double(pace.components.attoseconds) / 1e18
        var seconds = 0.0
        for character in unit {
            switch character {
            case " ": seconds += base * 0.7
            case ".", "!", "?": seconds += base * 3.0
            case ",", "\n": seconds += base * 2.0
            case ";", ":": seconds += base * 1.8
            case "\u{2026}": seconds += base * 2.5
            case "'", "\"", "-", "\u{2019}", "\u{201C}", "\u{201D}": seconds += base * 1.1
            default: seconds += base * Double.random(in: 0.88...1.12)
            }
        }
        return .seconds(seconds)
    }

    private func key(for unit: String, startsWord: Bool) {
        guard let last = unit.last(where: { !$0.isWhitespace }) else { return }
        let keys = MuseKeyHaptics.shared
        if ".!?".contains(last) {
            keys.key(.stop, strength: hapticStrength)
        } else if ",;:\u{2026}".contains(last) {
            keys.key(.pause, strength: hapticStrength)
        } else if startsWord {
            keys.key(.wordStart, strength: hapticStrength)
        } else {
            keys.key(.letter, strength: hapticStrength)
        }
    }
}

// MARK: - Units

/// How a line splits into ink units: one per character, or one per word for scripts
/// whose letters join or stack (arabic, hebrew, indic, thai, burmese, khmer), so their
/// shaping never breaks. Past `limit` characters the rest is one final unit.
nonisolated enum MuseInkUnits {
    static func split(_ text: String, limit: Int) -> [String] {
        let pieces = joinsLetters(text) ? words(text) : text.map(String.init)
        var units: [String] = []
        var used = 0
        var tail = ""
        for piece in pieces {
            if used < limit {
                units.append(piece)
                used += piece.count
            } else {
                tail += piece
            }
        }
        if !tail.isEmpty { units.append(tail) }
        return units
    }

    /// How many units type one by one (the rest is the tail).
    static func typedCount(_ text: String, limit: Int) -> Int {
        let pieces = joinsLetters(text) ? words(text) : text.map(String.init)
        var used = 0
        var count = 0
        for piece in pieces where used < limit {
            used += piece.count
            count += 1
        }
        return count
    }

    /// Words with their trailing whitespace.
    private static func words(_ text: String) -> [String] {
        var units: [String] = []
        var current = ""
        for character in text {
            if !character.isWhitespace, current.last?.isWhitespace == true {
                units.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { units.append(current) }
        return units
    }

    private static func joinsLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0590...0x08FF, // hebrew, arabic, syriac, thaana, nko
                 0x0900...0x0DFF, // indic
                 0x0E00...0x0EFF, // thai, lao
                 0x0F00...0x109F, // tibetan, myanmar
                 0x1780...0x18AF, // khmer, mongolian
                 0xFB1D...0xFDFF, // hebrew and arabic presentation forms
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Line

/// The full line, one run per ink unit so the renderer can time each one. Equatable, so
/// it is only rebuilt when the words change, not on every frame of ink.
nonisolated private struct MuseInkLine: View, Equatable {
    let text: String
    let limit: Int

    var body: some View {
        let pieces = MuseInkUnits.split(text, limit: limit).enumerated().map { index, unit in
            Text(verbatim: unit).customAttribute(MuseInkGlyph(index: index))
        }
        return Self.join(pieces[...])
    }

    /// Joins runs as a balanced tree, so a long line never nests hundreds deep.
    private static func join(_ pieces: ArraySlice<Text>) -> Text {
        switch pieces.count {
        case 0:
            return Text(verbatim: "")
        case 1:
            return pieces[pieces.startIndex]
        default:
            let middle = pieces.startIndex + pieces.count / 2
            return Text("\(join(pieces[..<middle]))\(join(pieces[middle...]))")
        }
    }
}

// MARK: - Renderer

/// Tags each ink unit's run with its index in the line.
nonisolated struct MuseInkGlyph: TextAttribute {
    let index: Int
}

/// Draws typed units, settling each new one in over `settle` seconds: opacity up, a little
/// blur clearing, a 2pt rise. Untyped units keep their space but aren't drawn.
nonisolated struct MuseInkRenderer: TextRenderer {
    var now: Double
    var typedAt: [Double]
    var settle: Double

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let index = run[MuseInkGlyph.self]?.index else {
                    context.draw(run)
                    continue
                }
                let typed = typedAt.indices.contains(index) ? typedAt[index] : 0
                guard typed.isFinite else { continue }
                let raw = settle > 0 ? min(max((now - typed) / settle, 0), 1) : 1
                guard raw < 1 else {
                    context.draw(run)
                    continue
                }
                let t = 1 - pow(1 - raw, 3)
                var ink = context
                ink.opacity = t
                ink.addFilter(.blur(radius: (1 - t) * 3))
                ink.translateBy(x: 0, y: (1 - t) * 2)
                ink.draw(run)
            }
        }
    }
}
