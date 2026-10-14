import Foundation
import OSLog
#if canImport(Voz)
import Voz
#endif
#if canImport(DesertAnt)
import DesertAnt
#endif

/// Desert Ant's Voz as a second on-device recognizer, chosen in build › speech.
///
/// Voz is a Core ML build of Parakeet TDT 0.6B v3: 25 european languages, punctuated
/// text, word times on an 80 ms grid. It doesn't ship with the app: it's a one-time
/// 467 mb download into Application Support (kept out of backups, safe from cache
/// purges). The first load after the download spends about 20 seconds getting ready for
/// the Neural Engine; `prepare()` pays that up front.
///
/// Its words keep Voz's own times and go through the same paragrapher as Apple's. Voz
/// can't tell which language it's hearing,
/// so the engine only hands it muses in a language it knows (the pick in build › speech,
/// else this iphone's).
actor VozSpeech {
    nonisolated static let shared = VozSpeech()

    nonisolated private static let log = Logger(subsystem: "museo.build", category: "voz")

    /// Shown in build › speech before the download.
    nonisolated static let downloadSize = "467 mb"

    /// Voz reads a whole recording into memory; longer ones go to Apple speech.
    nonisolated static let maxSeconds: Double = 20 * 60

    /// False when the Voz product isn't linked; the engine row hides then.
    nonisolated static var isAvailable: Bool {
        #if canImport(Voz)
        true
        #else
        false
        #endif
    }

    /// `Application Support/MuseBuild/speech-models/`, kept out of iCloud backups.
    nonisolated static var directory: URL {
        var url = MuseFiles.support("speech-models")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    nonisolated static var isDownloaded: Bool {
        #if canImport(Voz)
        Voz.isDownloaded(cacheRoot: directory.path)
        #else
        false
        #endif
    }

    /// The languages Voz knows, as ISO codes.
    nonisolated static var languages: Set<String> {
        #if canImport(Voz)
        Voz.supportedLanguages
        #else
        []
        #endif
    }

    nonisolated static func supports(languageCode: String) -> Bool {
        languages.contains(languageCode)
    }

    /// Voz is the engine picked in build › speech.
    nonisolated static var isChosen: Bool {
        SpeechSettings.storedEngine == .voz
    }

    /// Whether the engine should hand a muse in this language to Voz.
    nonisolated static func isActive(for languageCode: String) -> Bool {
        isChosen && supports(languageCode: languageCode) && isDownloaded
    }

    nonisolated static var textModel: String {
        #if canImport(Voz)
        "voz-\(VozModel.revision.trimmingCharacters(in: CharacterSet(charactersIn: "v")))"
        #else
        "voz"
        #endif
    }

    #if canImport(Voz)
    private var voz: Voz?
    #endif

    init() {
        SpeechEngine.keepUsageAnonymous()
    }

    // MARK: - Download

    /// Fetches the model once. `progress` reports 0...1 from any thread.
    func download(progress: @Sendable @escaping (Double) -> Void) async throws {
        #if canImport(Voz)
        try await Voz.download(cacheRoot: Self.directory.path) { progress($0.fraction) }
        #else
        throw SpeechError.assetsUnavailable
        #endif
    }

    /// Loads the downloaded model, so the first muse doesn't wait on the one-time
    /// Neural Engine warm-up (about 20 seconds after a download, then instant).
    func prepare() async throws {
        #if canImport(Voz)
        _ = try await loaded()
        #else
        throw SpeechError.assetsUnavailable
        #endif
    }

    /// Drops the model from memory and disk.
    func remove() {
        #if canImport(Voz)
        voz = nil
        #endif
        try? FileManager.default.removeItem(at: Self.directory)
    }

    // MARK: - Transcription

    func transcribe(_ wavURL: URL, languageCode: String) async throws -> SpeechResult {
        #if canImport(Voz)
        guard Self.supports(languageCode: languageCode) else { throw SpeechError.unsupportedLanguage }
        let voz = try await loaded()
        let samples: [Float]
        do {
            samples = try AudioCheck.monoSamples(wavURL, sampleRate: voz.sampleRate)
        } catch {
            throw SpeechError.unreadableAudio
        }
        try Task.checkCancellation()
        let heard = try await voz.transcribe(samples: samples)
        try Task.checkCancellation()

        let tokens = heard.words.map {
            SpeechToken(
                text: $0.text,
                start: Int(($0.start * 1_000).rounded()),
                end: Int(($0.end * 1_000).rounded())
            )
        }
        let words = SpeechEngine.words(from: tokens)
        Self.log.info("""
            voz \(String(format: "%.1f", heard.duration), privacy: .public)s audio in \
            \(String(format: "%.1f", heard.processingTime), privacy: .public)s, \
            \(words.count, privacy: .public) words, \(languageCode, privacy: .public)
            """)
        let textModel = Self.textModel
        return SpeechResult(
            text: SpeechParagrapher.compose(tokens),
            words: words,
            segments: Self.sentences(tokens),
            language: languageCode,
            confidence: nil,
            textModel: textModel,
            timingModel: textModel
        )
        #else
        throw SpeechError.assetsUnavailable
        #endif
    }

    // MARK: - Private

    #if canImport(Voz)
    private func loaded() async throws -> Voz {
        if let voz { return voz }
        guard Self.isDownloaded else { throw SpeechError.assetsUnavailable }
        let started = Date()
        let model = try await Voz(cacheRoot: Self.directory.path)
        voz = model
        Self.log.info("voz loaded in \(String(format: "%.1f", Date().timeIntervalSince(started)), privacy: .public)s")
        return model
    }
    #endif

    /// Voz has no phrases the way Apple speech does, so segments are its sentences: a
    /// run of tokens ending in ".", "!" or "?".
    nonisolated private static func sentences(_ tokens: [SpeechToken]) -> [TimedSegment] {
        var segments: [TimedSegment] = []
        var run: [SpeechToken] = []
        func flush() {
            guard let first = run.first, let last = run.last else { return }
            segments.append(TimedSegment(
                text: run.map(\.text).joined(separator: " "),
                startMs: first.startMs,
                endMs: max(last.endMs, first.startMs)
            ))
            run = []
        }
        for token in tokens {
            run.append(token)
            if let mark = token.text.last, ".!?".contains(mark) { flush() }
        }
        flush()
        return segments
    }
}
