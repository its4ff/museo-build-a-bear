import Foundation

/// A muse's words with their timings, saved next to the muse as a small JSON sidecar.
///
/// `Muse.transcript` holds the text; this holds when each word was said, so the muse
/// page can light words as they play and a tap on a word can seek to it.
///
/// ```swift
/// if let timed = TimedTranscriptStore.load(muse.id) {
///     for word in timed.words { print(word.text, word.start) }
/// }
/// ```
nonisolated struct TimedTranscript: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    /// The text exactly as the engine composed it (paragraph breaks included).
    var transcript: String
    /// One per word-bearing token of `transcript`, in order.
    var words: [TimedWord]
    var segments: [TimedSegment]
    var language: String?
    var textModel: String
    var timingModel: String
    var updatedAt: Date
}

nonisolated extension TimedTranscript {
    init(_ result: SpeechResult, at date: Date = .now) {
        self.init(
            version: Self.currentVersion,
            transcript: result.text,
            words: result.words,
            segments: result.segments,
            language: result.language,
            textModel: result.textModel,
            timingModel: result.timingModel,
            updatedAt: date
        )
    }

    /// Every whitespace token of `text` (punctuation-only ones too) with a time, or nil
    /// when `text` no longer matches these words (it was edited). Pass the muse's
    /// current transcript; it defaults to the one saved here.
    func tokens(for text: String? = nil) -> [TimedWord]? {
        SpeechTokens.project(words, onto: SpeechTokens.split(text ?? transcript))
    }
}

/// Where word timings live: `Application Support/MuseBuild/timings/<uuid>.json`.
nonisolated enum TimedTranscriptStore {
    static var directory: URL { MuseFiles.support("timings") }

    private static func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    /// Saves the timings for a muse. A result with no words removes any old sidecar
    /// instead, so a retranscribed blank muse never shows stale timings.
    static func save(_ result: SpeechResult, for id: UUID) {
        guard !result.words.isEmpty else {
            delete(id)
            return
        }
        save(TimedTranscript(result), for: id)
    }

    static func save(_ transcript: TimedTranscript, for id: UUID) {
        guard let data = try? JSONEncoder().encode(transcript) else { return }
        try? data.write(to: url(for: id), options: .atomic)
    }

    static func load(_ id: UUID) -> TimedTranscript? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return try? JSONDecoder().decode(TimedTranscript.self, from: data)
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor private static var cleanup: MuseHooks.Token?

    /// Deletes a muse's timings when the muse is deleted. Called once at launch; safe
    /// to call again.
    @MainActor
    static func installCleanup() {
        guard cleanup == nil else { return }
        cleanup = MuseHooks.onRemoved { id in
            delete(id)
        }
    }
}

// MARK: - Tokens

/// The one tokenizer word timings share: whitespace-delimited tokens, where a token is
/// a "word" when it holds a letter or digit. `TimedTranscript.words` has one entry per
/// word; captions draw every token.
nonisolated enum SpeechTokens {
    static func split(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func isWordBearing(_ token: String) -> Bool {
        token.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains)
    }

    /// The token ends a sentence: ".", "?", "!" or "…", ignoring closing quotes.
    static func endsSentence(_ token: String) -> Bool {
        var tail = Substring(token)
        while let last = tail.last, "\"')]\u{201D}\u{2019}".contains(last) { tail.removeLast() }
        guard let last = tail.last else { return false }
        return ".?!\u{2026}".contains(last)
    }

    /// One timing per token, or nil when `words` doesn't hold exactly one entry per
    /// word-bearing token. Punctuation-only tokens take the time of the word they
    /// introduce, or of the last word when nothing follows.
    static func project(_ words: [TimedWord], onto tokens: [String]) -> [TimedWord]? {
        let bearing = tokens.filter(isWordBearing).count
        guard bearing == words.count, !words.isEmpty else { return nil }
        var projected: [TimedWord] = []
        projected.reserveCapacity(tokens.count)
        var next = 0
        for token in tokens {
            if isWordBearing(token) {
                let word = words[next]
                next += 1
                projected.append(TimedWord(text: token, startMs: word.startMs, endMs: word.endMs))
            } else {
                let anchor = next < words.count ? words[next] : words[words.count - 1]
                projected.append(TimedWord(text: token, startMs: anchor.startMs, endMs: anchor.endMs))
            }
        }
        return projected
    }
}
