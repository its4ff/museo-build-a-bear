import Foundation

/// What the library adds up to over a stretch of time: words, time talking, how they came in,
/// and the words said most. Counted from the muses on this mac each time it's shown.
nonisolated struct LibraryStats: Sendable {
    /// The stretch: today, this calendar week, or everything.
    nonisolated enum Span: CaseIterable, Hashable, Sendable {
        case today, week, all

        var title: String {
            switch self {
            case .today: "today"
            case .week: "this week"
            case .all: "all time"
            }
        }

        func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
            switch self {
            case .today: calendar.isDate(date, inSameDayAs: now)
            case .week: calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) ?? false
            case .all: true
            }
        }
    }

    /// A word or a command and how many times.
    nonisolated struct Count: Hashable, Sendable {
        var name: String
        var count: Int
    }

    /// Typing speed for "saved over typing": a steady typist's, so it reads as about.
    static let typingWordsPerMinute = 40.0

    var words = 0
    var talking: TimeInterval = 0
    var muses = 0
    var streamed = 0
    var fromRing = 0
    var topWords: [Count] = []
    /// How long typing these words would take, less the time saying them, muse by muse: a
    /// long ring recording with few words in it doesn't take away from the others.
    var savedOverTyping: TimeInterval = 0

    init(_ all: [MacMuse], span: Span, top: Int = 5, now: Date = .now) {
        var counts: [String: Int] = [:]
        // Notes are written, not said: their spoken parts are counted as the holds they were.
        for muse in all where !muse.isNote && span.contains(muse.createdAt, now: now) {
            muses += 1
            talking += muse.duration
            if muse.isFromRing { fromRing += 1 } else { streamed += 1 }
            guard let said = muse.words, !said.isEmpty else { continue }
            let count = MacLibrary.wordCount(said)
            words += count
            savedOverTyping += max(0, Double(count) / Self.typingWordsPerMinute * 60 - muse.duration)
            for word in Self.plainWords(said) where word.count >= 3 && !Self.common.contains(word) {
                counts[word, default: 0] += 1
            }
        }
        topWords = counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(top)
            .map { Count(name: $0.key, count: $0.value) }
    }

    /// The streamed share of muses, 0 to 1.
    var streamedShare: Double {
        muses == 0 ? 0 : Double(streamed) / Double(muses)
    }

    /// Something the words add up to: "about 4 pages", "about a short novel".
    var likeness: String? {
        switch words {
        case 90_000...: "about a whole novel"
        case 40_000...: "about a short novel"
        case 7_500...: "about a short story"
        case 1_500...: "about a long essay"
        case 500...: "about \(words / 250) pages"
        case 250...: "about a page"
        default: nil
        }
    }

    // MARK: - Words

    /// Lowercase words, apostrophes kept inside ("don't"), everything else a break.
    static func plainWords(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split { !$0.isLetter && $0 != "'" }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { !$0.isEmpty }
    }

    /// Words everyone says: left out of "you say a lot", so what's left is yours.
    static let common: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can", "had", "her", "was", "one",
        "our", "out", "get", "has", "him", "his", "how", "its", "may", "new", "now", "old", "see", "two",
        "way", "who", "did", "say", "she", "too", "use", "yes", "yeah", "okay", "this", "that", "with",
        "have", "from", "they", "will", "would", "there", "their", "what", "about", "which", "when", "make",
        "like", "just", "know", "take", "into", "your", "some", "could", "them", "than", "then", "look",
        "only", "come", "over", "also", "back", "after", "first", "well", "even", "want", "because",
        "these", "give", "most", "very", "been", "were", "said", "each", "does", "doing", "done", "going",
        "gonna", "wanna", "got", "here", "where", "why", "much", "more", "really", "thing", "things",
        "something", "think", "let", "let's", "it's", "i'm", "don't", "that's", "can't", "i've", "i'll",
        "you're", "we're", "they're", "there's", "what's", "didn't", "doesn't", "isn't", "wasn't", "won't",
        "should", "need", "right", "maybe", "kind", "sort", "lot", "um", "uh", "mean", "able", "being",
        "still", "other", "through", "while", "same", "own", "such", "those", "again", "off", "down",
        "every", "make", "made", "put", "thank", "thanks", "hey", "hello", "yep", "nope", "sure",
    ]
}

extension TimeInterval {
    /// "6h 41m", "42m", "35s": a stat's time, short.
    var museStatTime: String {
        let seconds = Int(self.rounded())
        if seconds < 60 { return "\(seconds)s" }
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
