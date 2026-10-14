import Foundation
import Observation
import OSLog

/// Build › speech: the language muses are in, which on-device engine writes the words,
/// and studio sound. Saved in UserDefaults. The Voz download lives here rather than in
/// a view, so closing the page doesn't stop it.
///
/// ```swift
/// @State private var speech = SpeechSettings.shared
/// Toggle("studio sound", isOn: $speech.studioSound)
/// ```
@MainActor
@Observable
final class SpeechSettings {
    static let shared = SpeechSettings()

    nonisolated enum Engine: String, CaseIterable, Identifiable, Sendable {
        /// Apple speech: built in, every language this iphone knows, nothing to download.
        case apple
        /// Voz: a 467 mb download, 25 european languages, often more accurate in them.
        case voz

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apple: "apple"
            case .voz: "voz"
            }
        }
    }

    nonisolated enum VozState: Equatable, Sendable {
        case notDownloaded
        /// 0...1 of the download.
        case downloading(Double)
        /// Downloaded; getting ready for the Neural Engine, once, about 20 seconds.
        case preparing
        case ready
        /// Lowercase reason, ready to show.
        case failed(String)
    }

    /// The language every new muse is transcribed in (BCP 47, "es-MX"), or nil for auto:
    /// this iphone's language. Changing it fetches that language's model now, so the next
    /// muse doesn't wait. New muses only.
    var language: String? {
        didSet {
            guard language != oldValue else { return }
            SpeechLanguage.choose(language)
            Task { await SpeechEngine.shared.prepareAssets() }
        }
    }

    /// Which engine writes the words. Voz is used only once it's downloaded, and only for
    /// the languages it knows; everything else goes to Apple.
    var engine: Engine {
        didSet {
            guard engine != oldValue else { return }
            UserDefaults.standard.set(engine.rawValue, forKey: Self.engineKey)
        }
    }

    /// Where Voz stands. `downloadVoz()` and `removeVoz()` move it; set it directly only
    /// to stage a screen (lab, previews).
    var vozState: VozState

    /// A cleaner copy for listening (Desert Ant's Clear). Playback only: the words always
    /// come from the original recording. Off by default. Turning it on fetches Clear
    /// (about 9 mb, once) so the first listen doesn't wait.
    var studioSound: Bool {
        didSet {
            guard studioSound != oldValue else { return }
            UserDefaults.standard.set(studioSound, forKey: Self.studioKey)
            if studioSound { StudioSound.shared.warm() }
        }
    }

    @ObservationIgnored private var download: Task<Void, Never>?
    /// Bumped by every download and every removal, so a download that was stopped can't
    /// write its ending over whatever came after it.
    @ObservationIgnored private var downloadGeneration = 0

    nonisolated private static let engineKey = "muse.speech.engine"
    private static let studioKey = "muse.speech.studioSound"

    init() {
        language = SpeechLanguage.chosenID
        engine = Self.storedEngine
        vozState = VozSpeech.isDownloaded ? .ready : .notDownloaded
        studioSound = UserDefaults.standard.bool(forKey: Self.studioKey)
    }

    /// The saved engine, readable from any actor (the engine checks it per muse).
    nonisolated static var storedEngine: Engine {
        UserDefaults.standard.string(forKey: engineKey).flatMap(Engine.init(rawValue:)) ?? .apple
    }

    // MARK: - Voz

    /// Downloads Voz, readies it, and switches to it: asking for the download is
    /// choosing it. Safe to call twice.
    func downloadVoz() {
        guard download == nil, VozSpeech.isAvailable else { return }
        if VozSpeech.isDownloaded, vozState == .ready {
            engine = .voz
            return
        }
        vozState = .downloading(0)
        downloadGeneration += 1
        let generation = downloadGeneration
        download = Task {
            do {
                if !VozSpeech.isDownloaded {
                    try await VozSpeech.shared.download { fraction in
                        Task { @MainActor in SpeechSettings.shared.noteProgress(fraction) }
                    }
                }
                try Task.checkCancellation()
                guard generation == downloadGeneration else { return }
                vozState = .preparing
                try await VozSpeech.shared.prepare()
                try Task.checkCancellation()
                guard generation == downloadGeneration else { return }
                vozState = .ready
                engine = .voz
            } catch {
                // Stopped by `removeVoz()`, or replaced by a newer download: that one
                // owns the state now.
                guard generation == downloadGeneration else { return }
                if error is CancellationError {
                    vozState = VozSpeech.isDownloaded ? .ready : .notDownloaded
                } else {
                    vozState = .failed("the download didn't finish · try again on wi-fi")
                    SpeechEngine.log.error("voz download failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            download = nil
        }
    }

    /// Deletes Voz and goes back to Apple speech. Stops a download in progress.
    func removeVoz() {
        download?.cancel()
        download = nil
        downloadGeneration += 1
        engine = .apple
        vozState = .notDownloaded
        Task { await VozSpeech.shared.remove() }
    }

    private func noteProgress(_ fraction: Double) {
        guard case .downloading(let current) = vozState else { return }
        // Report in whole percents so the row doesn't redraw for every chunk.
        let next = (min(max(fraction, 0), 1) * 100).rounded(.down) / 100
        if next > current { vozState = .downloading(next) }
    }

    /// Re-reads disk, in case the model was removed elsewhere.
    func refresh() {
        guard download == nil else { return }
        vozState = VozSpeech.isDownloaded ? .ready : .notDownloaded
        if engine == .voz, vozState != .ready { engine = .apple }
    }

    // MARK: - Languages

    /// Every language this iphone can transcribe, by lowercase name, for a picker.
    /// Add an "auto" row (nil) yourself.
    static func availableLanguages() async -> [(id: String, name: String)] {
        await SpeechLanguage.available()
    }

    /// "english (united states)" for an id.
    static func name(for id: String) -> String {
        SpeechLanguage.name(for: id)
    }

    // MARK: - Lines for the speech section

    /// "auto · this iphone's language", or the picked language's name.
    var languageLabel: String {
        language.map(SpeechLanguage.name(for:)) ?? "auto · this iphone's language"
    }

    /// The Voz row's second line.
    var vozDetail: String {
        switch vozState {
        case .notDownloaded: "\(VozSpeech.downloadSize) · one time"
        case .downloading(let fraction): "downloading · \(Int(fraction * 100))%"
        case .preparing: "getting ready, about 20 seconds…"
        case .ready: "parakeet model by desert ant labs · 25 languages"
        case .failed(let reason): reason
        }
    }

    /// "apple · auto", "voz · spanish (mexico)".
    var summary: String {
        let engineName = engine == .voz && vozState == .ready ? "voz" : "apple"
        return "\(engineName) · \(language.map(SpeechLanguage.name(for:)) ?? "auto")"
    }
}
