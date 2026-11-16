import AVFoundation
import Foundation
import MuseoKit
import Speech

/// Words on this mac. Apple's on-device recognizers (the same ones museo build uses on the
/// iphone) hear a hold while the ring streams, for the island, and are a choice for the words
/// themselves: apple dictation (the default until a model is downloaded: quick, punctuated,
/// more languages) and apple speech (the long-form model). The models downloaded from the
/// panel (`LocalSpeech`) hear the whole hold again when you let go, and every recording.
enum MacSpeech {
    nonisolated enum Model: String, CaseIterable, Sendable {
        case parakeet
        case dictation
        case speech

        /// What the panel and each muse call it.
        var name: String {
            switch self {
            case .speech: "apple speech"
            case .dictation: "apple dictation"
            default: local?.name ?? rawValue
            }
        }

        /// The downloaded model this is, or nil for apple's.
        var local: LocalSpeech.Kind? { LocalSpeech.Kind(rawValue: rawValue) }

        init(_ kind: LocalSpeech.Kind) { self = Model(rawValue: kind.rawValue) ?? .dictation }
    }

    /// The model in use: dictation until someone picks speech. Switching applies from the
    /// next hold.
    static var model: Model {
        get { UserDefaults.standard.string(forKey: modelKey).flatMap(Model.init(rawValue:)) ?? .dictation }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modelKey) }
    }

    private static let modelKey = "museo.mac.speechModel"

    /// The model that really hears: the chosen one, or apple dictation while a chosen
    /// download isn't on this mac.
    static var inUse: Model {
        if let kind = model.local, !LocalSpeech.shared.isReady(kind) { return .dictation }
        return model
    }

    /// The language to listen in: this mac's, then english, as the chosen model has it.
    static func locale() async -> Locale? {
        for candidate in [Locale.current, Locale(identifier: "en-US")] {
            let found = switch model {
            case .speech: await SpeechTranscriber.supportedLocale(equivalentTo: candidate)
            default: await DictationTranscriber.supportedLocale(equivalentTo: candidate)
            }
            if let found { return found }
        }
        return nil
    }

    /// Fetches the model for this mac's language if it isn't here yet, so the first hold
    /// never waits on a download, and loads a downloaded one. Run again after switching.
    static func prepare() async {
        LocalSpeech.shared.warm()
        guard let locale = await locale(), let module = await transcriber() else { return }
        // Claim the language for this app, as museo build does on the iphone. Until then
        // macOS reports the model as not installed, even when it's on the mac and works.
        _ = try? await AssetInventory.reserve(locale: locale)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                print("[museo][mac] downloading \(model.name)…")
                try await request.downloadAndInstall()
                print("[museo][mac] \(model.name) ready")
            }
        } catch {
            print("[museo][mac] speech model:", error.localizedDescription)
        }
    }

    /// A recognizer for whole recordings: finals only.
    static func transcriber() async -> (any SpeechModule)? {
        await module(live: false)
    }

    /// A recognizer for a hold: it also reports words still forming, for the island. Only
    /// the settled words are typed.
    static func holdTranscriber() async -> (any SpeechModule)? {
        await module(live: true)
    }

    private static func module(live: Bool) async -> (any SpeechModule)? {
        guard let locale = await locale() else { return nil }
        switch model {
        case .speech:
            return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: live ? [.volatileResults] : [], attributeOptions: [])
        default:
            // Dictation for a downloaded model too: it's the one that hears a hold as it forms,
            // and the one to fall back on.
            return DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [.punctuation], reportingOptions: live ? [.volatileResults] : [], attributeOptions: [])
        }
    }

    /// Either recognizer's results as text, and whether each piece is settled.
    static func results(of module: any SpeechModule) -> AsyncThrowingStream<(text: String, isFinal: Bool), any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if let transcriber = module as? SpeechTranscriber {
                        for try await result in transcriber.results {
                            continuation.yield((String(result.text.characters), result.isFinal))
                        }
                    } else if let transcriber = module as? DictationTranscriber {
                        for try await result in transcriber.results {
                            continuation.yield((String(result.text.characters), result.isFinal))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The language the panel shows beside the model: "english".
    static func language() async -> String? {
        await locale().flatMap { Locale.current.localizedString(forLanguageCode: $0.language.languageCode?.identifier ?? "") }?.lowercased()
    }

    /// A finished recording's words, or nil when it couldn't be read or heard.
    ///
    /// No "is the model installed" check first: macOS can say no while the model is on the
    /// mac and works. The analyzer is the real test.
    static func transcribe(_ url: URL) async -> String? {
        if model.local != nil, let words = await LocalSpeech.shared.words(of: url) { return YourWords.shared.respell(words) }
        guard let module = await transcriber(),
              let file = try? AVAudioFile(forReading: url) else { return nil }
        let analyzer = SpeechAnalyzer(modules: [module])
        try? await analyzer.setContext(YourWords.shared.appleContext)
        // Results stream while the file is read, so they're collected alongside it.
        let collector = Task { () -> String in
            var text = ""
            for try await piece in results(of: module) where piece.isFinal {
                text = joined(text, piece.text)
            }
            return text
        }
        do {
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return YourWords.shared.respell(try await collector.value)
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            return nil
        }
    }

    /// Settled pieces, one space between them.
    static func joined(_ text: String, _ piece: String) -> String {
        let piece = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !piece.isEmpty else { return text }
        return text.isEmpty ? piece : text + " " + piece
    }
}
