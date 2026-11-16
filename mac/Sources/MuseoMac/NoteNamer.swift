import Foundation
import FoundationModels

/// Names a note when it ends, on this mac: Apple's on-device model with the iphone's title
/// rules (`MuseAI.title` in museo build), two to six lowercase words. Without Apple
/// Intelligence, or when the model passes, the note's first few words.
enum NoteNamer {
    static func name(for words: String) async -> String {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        if MacLibrary.wordCount(text) > 4, let named = await model(text) { return named }
        return opening(text)
    }

    /// Names a note in the background, unless you already named it.
    static func nameLater(_ id: UUID, words: String) {
        Task {
            let name = await name(for: words)
            MacLibrary.shared.nameNote(id, name, theirs: false)
        }
    }

    // MARK: - The model

    /// The iphone's `MuseAI.voice` and title rules, word for word, so a note on the mac reads
    /// like a muse on the iphone. "no dashes" is in there.
    private static let rules = """
    you are museo, the helper inside an app for a voice ring. write all lowercase, except \
    names. short plain sentences, and the first one is the answer. no preamble, no emoji, \
    no exclamation marks. never use em dashes or en dashes: use commas, periods or colons. \
    you title voice notes. read the note and name what it is about the way a friend \
    would label it, in the note's own language. when it names a person, place or project, \
    put that in the title. answer with the title alone: two to six lowercase words, like: \
    calling the dentist about the crown. no quotes, no period, nothing before or after it.
    """

    private static func model(_ text: String) async -> String? {
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        guard model.isAvailable else { return nil }
        let session = LanguageModelSession(model: model, instructions: rules)
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 60)
        guard let raw = try? await session.respond(to: "note: \(text.prefix(3_000))", options: options).content else {
            return nil
        }
        return tidy(raw)
    }

    /// The first line, without quotes, a lead in ("title:") or end punctuation, at most six
    /// words. Nil for a refusal or a sentence instead of a title.
    private static func tidy(_ raw: String) -> String? {
        var text = raw.split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? ""
        let lowered = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        guard !["i'm sorry", "i am sorry", "sorry,", "i can't", "i cannot", "i'm unable", "as an ai"].contains(where: lowered.hasPrefix),
              MacLibrary.wordCount(text) <= 12 else { return nil }
        if let colon = text.firstIndex(of: ":"), text[..<colon].lowercased().contains("title") {
            text = String(text[text.index(after: colon)...])
        }
        let words = text
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}.,:;?!").union(.whitespaces))
            .replacingOccurrences(of: "\u{2014}", with: ",")
            .replacingOccurrences(of: "\u{2013}", with: ",")
            .split(whereSeparator: \.isWhitespace)
            .prefix(6)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    /// The note's first sentence, six words at most, in lowercase like a written name.
    private static func opening(_ text: String) -> String {
        let sentence = text.split(whereSeparator: { ".?!\n".contains($0) }).first.map(String.init) ?? text
        let words = sentence.split(whereSeparator: \.isWhitespace).prefix(6).joined(separator: " ")
        return words.isEmpty ? "a note" : words.lowercased()
    }
}
