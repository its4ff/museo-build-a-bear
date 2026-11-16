import Foundation
import Observation
import Speech

/// Words museo should hear right: names, places, words of your own ("museo", "Voz"). Both
/// recognizers lean toward them: parakeet through FluidAudio's vocabulary boosting (a small
/// second model checks the audio for each word), apple's through its contextual strings.
///
/// Kept in ~/Library/Application Support/museo mac/words.json. Added from the panel, several
/// at once with commas between.
@MainActor
@Observable
final class YourWords {
    static let shared = YourWords()

    private(set) var words: [String] = []

    private var fileURL: URL { MacLibrary.shared.folder.appendingPathComponent("words.json") }

    /// A few to start with: words museo itself is about.
    private static let seed = ["museo", "Voz", "Claude"]

    private init() {
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode([String].self, from: data) {
            words = saved
        } else {
            words = Self.seed
            save()
        }
    }

    // MARK: - Changing

    /// Adds each word in `text`, split at commas and new lines. A word already here (in any
    /// case) is left as it is.
    func add(_ text: String) {
        for word in Self.split(text) where !contains(word) {
            words.append(word)
        }
        save()
    }

    func remove(_ word: String) {
        words.removeAll { $0 == word }
        save()
    }

    /// Changes `old` to `new`, in place. Empty: removes it.
    func rename(_ old: String, to new: String) {
        guard let index = words.firstIndex(of: old) else { return }
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        if new.isEmpty {
            words.remove(at: index)
        } else if new.lowercased() == old.lowercased() || !contains(new) {
            words[index] = new
        } else {
            words.remove(at: index)
        }
        save()
    }

    private func contains(_ word: String) -> Bool {
        words.contains { $0.lowercased() == word.lowercased() }
    }

    nonisolated static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == "·" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(words) { try? data.write(to: fileURL, options: .atomic) }
    }

    // MARK: - Spelling

    /// `text` with each of your words written your way: "Museo" as "museo", "voz" as "Voz".
    func respell(_ text: String) -> String {
        var text = text
        for word in words {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: NSRegularExpression.escapedTemplate(for: word))
        }
        return text
    }

    // MARK: - For apple's recognizers

    /// The words as hints for a `SpeechAnalyzer`, with the names of the apps on this mac so
    /// "open figma" is heard as one. (Apple's recognizer takes a long list cheaply; parakeet's
    /// boosting gets only your words: it checks the audio for each one.)
    var appleContext: AnalysisContext {
        let context = AnalysisContext()
        context.contextualStrings = [.general: words + Self.appNames]
        return context
    }

    /// The apps' names, read once a launch.
    private static let appNames = VoiceCommands.appNames()
}
