import Foundation
import FoundationModels

/// Apple's on-device model, the way museo build uses it: titles, notes, and anything your
/// own code asks. No key, no server, nothing leaves the iphone. Needs Apple Intelligence;
/// every call fails quietly without it.
///
/// ```swift
/// let answer = try await MuseAI.ask("a nicer word for busy?")
///
/// @Generable nonisolated struct Plan {            // nonisolated: the model fills it
///     @Guide(description: "two to six lowercase words") var title: String
/// }
/// let plan = try await MuseAI.generate(Plan.self, from: muse.words)
/// ```
///
/// The model is small (about 4k tokens in and out, together), has no internet, and its
/// knowledge stops at its training. It's good at rewording, sorting, pulling out dates
/// and titles, and short how-tos.
@MainActor
enum MuseAI {
    /// The house voice. Every prompt whose output someone reads starts from this.
    nonisolated static let voice = """
    you are museo, the helper inside an app for a voice ring. write all lowercase, except \
    names. short plain sentences, and the first one is the answer. no preamble, no emoji, \
    no exclamation marks. never use em dashes or en dashes: use commas, periods or colons.
    """

    /// Apple Intelligence is on and its model is ready on this iphone.
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Why the model can't run here, lowercase, or nil when it can.
    static var unavailableNote: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "needs an iphone with apple intelligence"
            case .appleIntelligenceNotEnabled: return "turn on apple intelligence in settings"
            case .modelNotReady: return "apple intelligence is still getting ready · try again soon"
            @unknown default: return "the on-device model isn't available on this iphone yet"
            }
        }
    }

    /// A plain text answer. Permissive guardrails: plain text is the one kind of answer
    /// they cover, so a sensitive muse still gets reworded. The model can still refuse in
    /// words ("i can't help with that"); `looksLikeRefusal` spots the usual ones.
    static func ask(_ prompt: String, instructions: String = voice) async throws -> String {
        try await answer(prompt, instructions: instructions, options: GenerationOptions())
    }

    /// A plain text answer under permissive guardrails (see `ask`), with your own options:
    /// greedy for titles and notes, so the same muse gives the same answer.
    static func answer(_ prompt: String, instructions: String, options: GenerationOptions) async throws -> String {
        let session = try session(instructions, guardrails: .permissiveContentTransformations)
        do {
            let response = try await session.respond(to: prompt, options: options)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MuseAIError(error)
        }
    }

    /// A typed answer: make a `@Generable nonisolated struct`, get it back filled in.
    /// Greedy, so the same muse gives the same answer.
    ///
    /// Guided generation always runs under the default guardrails: Apple's permissive mode
    /// only covers plain text answers. So a muse about something sensitive (an illness, a
    /// fight, the news) can come back `MuseAIError.declined` here. For those, ask again in
    /// plain text with `ask`, the way titles and notes do.
    static func generate<T: Generable>(_ type: T.Type, from prompt: String, instructions: String = voice) async throws -> T {
        let session = try session(instructions, guardrails: .default)
        do {
            let response = try await session.respond(to: prompt, generating: type, options: GenerationOptions(sampling: .greedy))
            return response.content
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MuseAIError(error)
        }
    }

    /// A short title for a muse: two to six words, lowercase except the names they said,
    /// in the muse's language. Nil when the model is unavailable or declines, or the muse
    /// is short enough to be its own title. A long muse is titled from its opening.
    ///
    /// Asked in plain text under permissive guardrails, so a muse about something
    /// sensitive still gets a title (`generate` would be declined).
    static func title(for words: String) async -> String? {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailable, MuseWordParts.wordCount(text) > 4 else { return nil }
        // Scripts written without spaces take about a token a character, so less fits.
        let opening = text.prefix(MuseWordParts.hasUnspacedScript(text) ? 1_200 : 3_000)
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 60)
        guard let raw = try? await answer("note: \(opening)", instructions: titleRules, options: options) else {
            return nil
        }
        return tidyTitle(raw, names: TheirNames(text))
    }

    /// Notes for a muse's words: `.brief` bullets (150 to 399 words) or the `.longThought`
    /// write-up (400 and up), on this iphone. Nil when the model is unavailable, declines or
    /// finds nothing worth keeping. Muses too long for the model's window are read in parts
    /// (`MuseNotesWriter`).
    static func notes(_ kind: MuseNotes.Kind, for words: String) async -> MuseNotes? {
        await MuseNotesWriter.write(kind, for: words)
    }

    /// Loads the model ahead of the first muse, so it doesn't pay the wait. Call at launch.
    static func prewarm() {
        #if DEBUG
        // `-museNotesProbe`: print real titles and notes for the samples, then exit.
        if MuseNotesProbe.isRequested {
            MuseNotesProbe.run()
            return
        }
        #endif
        guard isAvailable, warmSession == nil else { return }
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: voice)
        session.prewarm()
        warmSession = session
    }

    // MARK: - Private

    private static var warmSession: LanguageModelSession?

    private static let titleRules = voice + """
     you title voice notes. read the note and name what it is about the way a friend \
    would label it, in the note's own language. when it names a person, place or project, \
    put that in the title. answer with the title alone: two to six lowercase words, like: \
    calling the dentist about the crown. no quotes, no period, nothing before or after it.
    """

    private static func session(_ instructions: String, guardrails: SystemLanguageModel.Guardrails) throws -> LanguageModelSession {
        let model = SystemLanguageModel(useCase: .general, guardrails: guardrails)
        guard model.isAvailable else {
            throw MuseAIError.unavailable(unavailableNote ?? "the on-device model isn't available on this iphone yet")
        }
        return LanguageModelSession(model: model, instructions: instructions)
    }

    /// The first line, lowercase except their names, no quotes, lead in ("title:") or end
    /// punctuation, at most six words. Nil for a refusal or a sentence instead of a title.
    private static func tidyTitle(_ raw: String, names: TheirNames) -> String? {
        let firstLine = raw.split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        var text = firstLine.trimmingCharacters(in: .whitespaces)
        guard !looksLikeRefusal(text), MuseWordParts.wordCount(text) <= 12 else { return nil }
        // "title: …" or "here's a title: …".
        if let colon = text.firstIndex(of: ":"), text[..<colon].lowercased().contains("title") {
            text = String(text[text.index(after: colon)...])
        }
        let calm = names.calm(text)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}.,:;?").union(.whitespaces))
        let words = calm.split(whereSeparator: \.isWhitespace).prefix(6)
        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }

    /// A plain text answer that's the model passing on it ("i'm sorry, i can't help with
    /// that"). Permissive guardrails never throw for plain text, but the model can still
    /// refuse in words. English openings only; the usual ones.
    nonisolated static func looksLikeRefusal(_ answer: String) -> Bool {
        let opening = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
        return refusalOpenings.contains { opening.hasPrefix($0) }
    }

    nonisolated private static let refusalOpenings = [
        "i'm sorry", "i am sorry", "sorry,", "i apologize", "i can't", "i cannot", "i can not",
        "i'm unable", "i am unable", "i won't", "i'm not able", "i am not able", "as an ai",
    ]
}

/// Why the on-device model didn't answer, in the house voice.
nonisolated enum MuseAIError: LocalizedError, Equatable {
    /// Apple Intelligence is off, not ready, or this iphone can't run it.
    case unavailable(String)
    /// The model's guardrails passed on this one.
    case declined
    /// Too many words for the small model.
    case tooLong
    /// Busy or rate limited, often in the background. Try again later.
    case busy
    /// A language the model doesn't speak yet.
    case language
    case failed(String)

    init(_ error: Error) {
        if let own = error as? MuseAIError {
            self = own
            return
        }
        guard let generation = error as? LanguageModelSession.GenerationError else {
            self = .failed(error.localizedDescription.museQuiet)
            return
        }
        switch generation {
        case .guardrailViolation, .refusal: self = .declined
        case .exceededContextWindowSize: self = .tooLong
        case .rateLimited, .concurrentRequests: self = .busy
        case .unsupportedLanguageOrLocale: self = .language
        case .assetsUnavailable: self = .unavailable("apple intelligence is still getting ready · try again soon")
        default: self = .failed("the on-device model couldn't answer")
        }
    }

    var errorDescription: String? {
        switch self {
        case .unavailable(let note): note
        case .declined: "the on-device model passed on this one"
        case .tooLong: "too long for the on-device model"
        case .busy: "the on-device model is busy · try again soon"
        case .language: "the on-device model doesn't speak this language yet"
        case .failed(let reason): reason
        }
    }

    /// Worth trying again later (busy, still getting ready).
    var isRetryable: Bool {
        switch self {
        case .busy, .unavailable, .failed: true
        case .declined, .tooLong, .language: false
        }
    }
}
