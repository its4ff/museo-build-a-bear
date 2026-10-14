import Foundation

/// What "copy" and "share" put out for a muse. Plain text, the same everywhere: the home's
/// menu, the muse page, your own code.
///
/// ```
/// copy words      their words, tidied: one paragraph per line, no header
/// copy notes      the notes as plain text (MuseNotes.plainText), no header
/// share words     "call mum about sunday · wed oct 8 · 9:41a" + blank line + the words
/// share notes     the same header + blank line + the notes
/// share audio     the muse's wav (Muse.audioURL)
/// ```
nonisolated extension Muse {
    /// Their words for copying: line endings tidied, spaces collapsed, one blank line
    /// between paragraphs. Nil when there are none (still transcribing, blank, failed).
    var copyWords: String? {
        guard isTranscribed, !isBlank else { return nil }
        let lines = words
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n\n")
    }

    /// The notes for copying, or nil when this muse has none.
    var copyNotes: String? {
        guard let text = notes?.plainText.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    /// "call mum about sunday · wed oct 8 · 9:41a": the first line of anything shared.
    var shareHeader: String {
        "\(shareTitle) · \(shareStamp)"
    }

    /// The header, a blank line, then the words. Nil without words.
    var shareWords: String? {
        copyWords.map { "\(shareHeader)\n\n\($0)" }
    }

    /// The header, a blank line, then the notes. Nil without notes.
    var shareNotes: String? {
        copyNotes.map { "\(shareHeader)\n\n\($0)" }
    }

    /// The subject line a share sheet offers (mail, notes): the title.
    var shareSubject: String { shareTitle }

    /// The title as it is: the model's is already lowercase except names, and one they
    /// wrote keeps its case. Without one, the first line of their words, its first letter
    /// lowercase unless it starts with a name they said ("Priya called" stays).
    private var shareTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let line = displayTitle
        guard let first = line.first, first.isUppercase else { return line }
        var firstWord: String?
        line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: .byWords) { word, _, _, stop in
            firstWord = word
            stop = true
        }
        if let firstWord, TheirNames(words).isName(firstWord) { return line }
        return first.lowercased() + line.dropFirst()
    }

    /// "wed oct 8 · 9:41a".
    private var shareStamp: String {
        let day = createdAt.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day())
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
        return "\(day) · \(createdAt.museClock)"
    }
}
