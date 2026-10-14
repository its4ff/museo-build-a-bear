import Foundation

/// Model output in the house case: all lowercase, except the names they said.
///
/// Learns names from their own words. A word with a capital in the middle of a sentence,
/// and never written in lowercase, is a name: "Priya", "Lisbon", "NYC". Everything else
/// the model capitalized goes lowercase, and a name the model wrote in lowercase gets its
/// capital back. Words typed all in lowercase have no names, so the notes stay lowercase too.
///
/// ```swift
/// let names = TheirNames("notes from the call with Priya. she thinks …")
/// names.calm("The call with priya")     // "the call with Priya"
/// ```
nonisolated struct TheirNames: Sendable {
    /// Lowercased name → how they wrote it.
    private let names: [String: String]

    /// Capitalized in speech without being names.
    private static let neverNames: Set<String> = ["i", "i'm", "i'll", "i've", "i'd", "i\u{2019}m", "i\u{2019}ll", "i\u{2019}ve", "i\u{2019}d"]

    init(_ words: String) {
        var lowercase = Set<String>()
        var capitalized: [String: String] = [:]
        words.enumerateSubstrings(in: words.startIndex..<words.endIndex, options: .byWords) { word, range, _, _ in
            guard let word else { return }
            let stem = Self.possessive(word).stem
            let folded = stem.lowercased()
            guard stem != folded else {
                lowercase.insert(folded)
                return
            }
            // A capital that starts a sentence says nothing about a name.
            guard !Self.startsSentence(in: words, at: range.lowerBound) else { return }
            if capitalized[folded] == nil { capitalized[folded] = stem }
        }
        names = capitalized.filter { !lowercase.contains($0.key) && !Self.neverNames.contains($0.key) }
    }

    /// `museCalm` (no dashes, no exclamation marks), then lowercase except their names.
    func calm(_ text: String) -> String {
        let source = text.museCalm
        var out = ""
        var cursor = source.startIndex
        source.enumerateSubstrings(in: source.startIndex..<source.endIndex, options: .byWords) { word, range, _, _ in
            guard let word else { return }
            out += source[cursor..<range.lowerBound]
            out += cased(word)
            cursor = range.upperBound
        }
        out += source[cursor...]
        return out
    }

    /// They wrote this word as a name: "Priya" or "Priya's", in any case.
    func isName(_ word: String) -> Bool {
        names[Self.possessive(word).stem.lowercased()] != nil
    }

    // MARK: - Private

    private func cased(_ word: String) -> String {
        let (stem, suffix) = Self.possessive(word)
        if let name = names[stem.lowercased()] { return name + suffix.lowercased() }
        return word.lowercased()
    }

    /// "Priya's" is "Priya" with "'s".
    private static func possessive(_ word: String) -> (stem: String, suffix: String) {
        for suffix in ["'s", "\u{2019}s", "'S", "\u{2019}S"] where word.count > suffix.count && word.hasSuffix(suffix) {
            return (String(word.dropLast(suffix.count)), suffix)
        }
        return (word, "")
    }

    /// The word at `index` opens a sentence, a line or the text.
    private static func startsSentence(in text: String, at index: String.Index) -> Bool {
        var i = index
        while i > text.startIndex {
            i = text.index(before: i)
            let c = text[i]
            if c.isNewline { return true }
            if c.isWhitespace || "\"'([\u{201C}\u{2018}\u{00BF}\u{00A1}".contains(c) { continue }
            return ".?!:;\u{2026}".contains(c)
        }
        return true
    }
}
