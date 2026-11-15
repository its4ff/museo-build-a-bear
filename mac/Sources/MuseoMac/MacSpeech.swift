import AVFoundation
import Foundation
import MuseoKit
import Speech

/// Words on this mac, with Apple's on-device recognizer (the same one museo build uses on the
/// iphone): a hold's words while the ring streams, and a whole recording's words once it lands.
enum MacSpeech {
    /// The language to listen in: this mac's, then english.
    static func locale() async -> Locale? {
        for candidate in [Locale.current, Locale(identifier: "en-US")] {
            if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return locale
            }
        }
        return nil
    }

    /// Fetches the speech model for this mac's language if it isn't here yet, so the first
    /// hold never waits on a download.
    static func prepare() async {
        guard let locale = await locale(), let module = await transcriber() else { return }
        // Claim the language for this app, as museo build does on the iphone. Until then
        // macOS reports the model as not installed, even when it's on the mac and works.
        _ = try? await AssetInventory.reserve(locale: locale)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                print("[museo][mac] downloading the speech model…")
                try await request.downloadAndInstall()
                print("[museo][mac] speech model ready")
            }
        } catch {
            print("[museo][mac] speech model:", error.localizedDescription)
        }
    }

    /// A recognizer for this mac's language, or nil when there's none. Finals only, for whole
    /// recordings.
    static func transcriber() async -> SpeechTranscriber? {
        guard let locale = await locale() else { return nil }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    }

    /// The same recognizer for a hold: it also reports words still forming, for the flow bar.
    /// Only the settled words are typed.
    static func holdTranscriber() async -> SpeechTranscriber? {
        guard let locale = await locale() else { return nil }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
    }

    /// What the panel says about speech: "apple speech · on this mac · english".
    static func line() async -> String {
        let language = await locale().flatMap { Locale.current.localizedString(forLanguageCode: $0.language.languageCode?.identifier ?? "") }
        return ["apple speech", "on this mac", language?.lowercased()].compactMap { $0 }.joined(separator: " · ")
    }

    /// A finished recording's words, or nil when it couldn't be read or heard.
    ///
    /// No "is the model installed" check first: macOS can say no while the model is on the
    /// mac and works. The analyzer is the real test.
    static func transcribe(_ url: URL) async -> String? {
        guard let module = await transcriber(),
              let file = try? AVAudioFile(forReading: url) else { return nil }
        let analyzer = SpeechAnalyzer(modules: [module])
        // Results stream while the file is read, so they're collected alongside it.
        let collector = Task { () -> String in
            var text = ""
            for try await result in module.results {
                text = joined(text, String(result.text.characters))
            }
            return text
        }
        do {
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await collector.value
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
