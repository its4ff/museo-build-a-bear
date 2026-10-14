import Foundation

/// Cuts a long muse into parts for the on-device model, at paragraph and sentence breaks so
/// no line is cut in half. `MuseNotesWriter` uses it when a muse is too long for one call.
///
/// ```swift
/// let parts = MuseWordParts.split(muse.words, around: 800)   // about 700 to 900 words each
/// let kept = MuseWordParts.spread(parts, keeping: 8)         // first, last, evenly between
/// ```
nonisolated enum MuseWordParts {
    /// Parts in order, each about `target` words (seven eighths to nine eighths of it) where
    /// the sentences allow. A paragraph break ends a part once it's long enough. A sentence
    /// longer than a part (speech without punctuation) is cut between words.
    static func split(_ text: String, around target: Int) -> [String] {
        let target = max(target, 40)
        let enough = target * 7 / 8
        let most = target * 9 / 8
        var parts: [String] = []
        var current = ""
        var count = 0

        func close() {
            let part = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { parts.append(part) }
            current = ""
            count = 0
        }

        for paragraph in text.components(separatedBy: .newlines) {
            let sentences = sentences(of: paragraph)
            guard !sentences.isEmpty else { continue }
            if !current.isEmpty { current += "\n\n" }
            for sentence in sentences {
                let words = wordRanges(of: sentence)
                if words.count > most {
                    close()
                    // Cut between words, each piece running up to where the next one starts,
                    // so nothing between words (punctuation, spaces) is lost.
                    for start in stride(from: 0, to: words.count, by: target) {
                        let from = start == 0 ? sentence.startIndex : words[start].lowerBound
                        let next = start + target
                        let to = next < words.count ? words[next].lowerBound : sentence.endIndex
                        let piece = sentence[from..<to].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !piece.isEmpty { parts.append(piece) }
                    }
                    continue
                }
                if count + words.count > most { close() }
                // No space after 。！？: Chinese and Japanese run their sentences together.
                if let last = current.last, !last.isNewline, !fullWidthEnders.contains(last) { current += " " }
                current += sentence
                count += words.count
            }
            if count >= enough { close() }
        }
        close()

        // A scrap at the end rides with the part before it rather than standing alone.
        if parts.count > 1, let last = parts.last, wordCount(last) < target / 4 {
            parts.removeLast()
            parts[parts.count - 1] += "\n\n" + last
        }
        return parts
    }

    /// At most `limit` parts: the first, the last and evenly spaced ones between, each with
    /// its place in the whole (0 based), in order.
    static func spread(_ parts: [String], keeping limit: Int) -> [(index: Int, text: String)] {
        guard parts.count > limit, limit > 1 else {
            return parts.enumerated().map { ($0.offset, $0.element) }
        }
        let step = Double(parts.count - 1) / Double(limit - 1)
        var picked: [Int] = []
        for slot in 0..<limit {
            let index = Int((Double(slot) * step).rounded())
            if picked.last != index { picked.append(index) }
        }
        return picked.map { ($0, parts[$0]) }
    }

    /// How many words. Text with spaces between words is split on them (fast, and views
    /// read it); Chinese, Japanese, Thai and the other scripts written without spaces are
    /// counted by the word tokenizer, so "我明天去北京开会" is several words, not one.
    static func wordCount(_ text: String) -> Int {
        guard hasUnspacedScript(text) else {
            return text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    /// The text has a character from a script written without spaces between words.
    static func hasUnspacedScript(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isUnspaced)
    }

    /// Thai, Lao, Myanmar, Khmer, Japanese kana, Chinese and Japanese characters (and
    /// their full width punctuation): scripts that don't put spaces between words.
    static func isUnspaced(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0E00...0x0EFF,       // Thai, Lao
             0x1000...0x109F,       // Myanmar
             0x1780...0x17FF,       // Khmer
             0x3000...0x30FF,       // CJK punctuation, hiragana, katakana
             0x3400...0x4DBF,       // CJK extension A
             0x4E00...0x9FFF,       // CJK unified ideographs
             0xF900...0xFAFF,       // CJK compatibility ideographs
             0xFF01...0xFF9F,       // full width forms, half width katakana
             0x20000...0x3134F:     // CJK extensions B and up
            return true
        default:
            return false
        }
    }

    // MARK: - Private

    /// Where each word of one sentence is: split on spaces, or by the word tokenizer for
    /// scripts written without them (see `wordCount`).
    private static func wordRanges(of sentence: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        guard hasUnspacedScript(sentence) else {
            var start: String.Index?
            for index in sentence.indices {
                if sentence[index].isWhitespace {
                    if let open = start { ranges.append(open..<index) }
                    start = nil
                } else if start == nil {
                    start = index
                }
            }
            if let open = start { ranges.append(open..<sentence.endIndex) }
            return ranges
        }
        sentence.enumerateSubstrings(in: sentence.startIndex..<sentence.endIndex, options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            ranges.append(range)
        }
        return ranges
    }

    /// Sentences end at end punctuation followed by a space, and at full width end marks
    /// (。！？) right away, since Chinese and Japanese put no space after them. Not
    /// `.bySentences`: it won't break before a lowercase letter, and lowercase speech is
    /// common here. A cut after "dr." costs nothing; a cut mid-sentence would.
    private static func sentences(of paragraph: String) -> [String] {
        var out: [String] = []
        var current = ""
        var previous: Character?

        func close() {
            let sentence = current.trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty { out.append(sentence) }
            current = ""
        }

        for character in paragraph {
            if character.isWhitespace, let previous, enders.contains(previous) {
                close()
            } else {
                current.append(character)
                if fullWidthEnders.contains(character) { close() }
            }
            previous = character
        }
        close()
        return out
    }

    private static let enders: Set<Character> = [".", "?", "!", "\u{2026}", "\u{3002}", "\u{FF01}", "\u{FF1F}"]
    /// End marks that end a sentence with no space after them: 。！？ and the half width 。
    private static let fullWidthEnders: Set<Character> = ["\u{3002}", "\u{FF01}", "\u{FF1F}", "\u{FF61}"]
}
