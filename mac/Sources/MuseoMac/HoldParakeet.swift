import Foundation

/// Parakeet's words while you hold: the downloaded model hears the hold again every moment or
/// so, so the island shows the words that will be typed, not apple dictation's guess at them.
///
/// It paces itself. The next pass starts only after the last one ends, and waits a little
/// longer on a slower mac, so it never piles up: an M4 gets about two passes a second, an M1
/// fewer. Each pass hears at most the last stretch of the hold (`longest`); before that, the
/// words are settled at a quiet moment and kept. When you let go, `LocalSpeech` hears the
/// whole hold once more, with your words, and that is what's typed.
@MainActor
final class HoldParakeet {
    private let onWords: (HoldSpeech.Words) -> Void
    /// The whole hold so far, 16 kHz.
    private var audio: [Int16] = []
    /// Where the stretch still being heard begins, and the words settled before it.
    private var start = 0
    private var settled = ""
    private var passes: Task<Void, Never>?
    private var stopped = false
    private var count = 0

    private static let rate = 16_000
    /// Wait for this much of the hold before the first pass: soon enough that a short command
    /// ("new line") gets a pass while you still hold.
    private static let first = rate / 2
    /// The most one pass hears. Past it, the words up to a quiet moment settle.
    private static let longest = rate * 20
    /// The last words of a pass can still change as more comes in: shown faint.
    private static let forming = 3

    private init(onWords: @escaping (HoldSpeech.Words) -> Void) {
        self.onWords = onWords
    }

    /// Starts for a hold, or nil when no downloaded model is loaded (apple's words carry the
    /// island then, as before).
    static func begin(onWords: @escaping (HoldSpeech.Words) -> Void) -> HoldParakeet? {
        guard LocalSpeech.shared.canHearWhileHolding else { return nil }
        return HoldParakeet(onWords: onWords)
    }

    /// The next stretch of the hold, in order.
    func feed(_ samples: [Int16]) {
        guard !stopped else { return }
        audio.append(contentsOf: samples)
        if passes == nil, audio.count >= Self.first {
            passes = Task { await run() }
        }
    }

    /// The hold ended (or another began): no more passes. One already running finishes first,
    /// and the hold's last pass waits for it.
    func stop() {
        guard !stopped else { return }
        stopped = true
        passes?.cancel()
        if count > 0 { print("[museo][speech] while holding: \(count) passes") }
    }

    // MARK: - Passes

    private func run() async {
        while !stopped {
            let began = Date.now
            if audio.count - start > Self.longest {
                await settle()
            } else {
                await hearLatest()
            }
            guard !stopped else { return }
            // Never faster than the mac keeps up: rest at least as long as the pass took.
            let took = Date.now.timeIntervalSince(began)
            try? await Task.sleep(for: .seconds(max(0.4, took * 1.5)))
        }
    }

    /// Hears the stretch since the last settled moment and shows it, its last words faint.
    private func hearLatest() async {
        guard let text = await LocalSpeech.shared.quickWords(of: audio[start...]), !stopped else { return }
        count += 1
        let words = text.split(whereSeparator: \.isWhitespace)
        let firm = words.dropLast(Self.forming).joined(separator: " ")
        let soft = words.suffix(Self.forming).joined(separator: " ")
        guard !firm.isEmpty || !soft.isEmpty || !settled.isEmpty else { return }
        onWords(HoldSpeech.Words(heard: MacSpeech.joined(settled, firm), hearing: soft))
    }

    /// A long hold: the words up to a quiet moment a few seconds back are heard once more
    /// and kept, and passes start from there.
    private func settle() async {
        let cut = quietMoment(from: audio.count - Self.rate * 8, to: audio.count - Self.rate * 3)
        guard let text = await LocalSpeech.shared.quickWords(of: audio[start..<cut]), !stopped else { return }
        count += 1
        settled = MacSpeech.joined(settled, text)
        start = cut
        onWords(HoldSpeech.Words(heard: settled, hearing: ""))
    }

    /// The quietest tenth of a second between two points: a gap between words, most likely,
    /// so no word is cut in two.
    private func quietMoment(from: Int, to: Int) -> Int {
        let frame = Self.rate / 10
        var best = to
        var quietest = Int.max
        var at = max(from, start + Self.rate * 5)
        while at + frame <= to {
            var loudness = 0
            for sample in audio[at..<(at + frame)] { loudness += abs(Int(sample)) }
            if loudness < quietest {
                quietest = loudness
                best = at + frame / 2
            }
            at += frame
        }
        return best
    }
}
