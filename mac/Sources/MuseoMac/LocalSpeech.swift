import FluidAudio
import Foundation
import Observation

/// Speech models that run on this mac's Neural Engine (FluidAudio), each downloaded once from
/// the panel into ~/Library/Application Support/museo mac/models.
///
/// The download is the model's files from Hugging Face; nothing is sent back. Audio and words
/// stay on this mac. While you hold, the chosen model hears the hold again every moment or so
/// (`HoldParakeet`), and the island shows its words; apple dictation fills only the first
/// moment. When you let go, it hears the whole hold once more, with your words, and those are
/// the ones typed. Memory recordings go through it too.
@MainActor
@Observable
final class LocalSpeech {
    static let shared = LocalSpeech()

    /// The one to download: parakeet ultra. Tried beside it and left out: bark clean (drops
    /// the ums, but less accurate on real holds) and phonon 2 (smaller, sloppier). A
    /// Parakeet: 0.6B on the Neural Engine, about 100x real time on an M-series mac, so a
    /// hold's words are back in a blink.
    nonisolated enum Kind: String, CaseIterable, Sendable {
        /// moondream's post-training of NVIDIA's Parakeet v3: the most accurate of the family.
        case parakeet

        var name: String {
            switch self {
            case .parakeet: "parakeet ultra"
            }
        }

        /// One line for the menu.
        var detail: String {
            switch self {
            case .parakeet: "recommended · the most accurate, 25 languages"
            }
        }

        var size: String {
            switch self {
            case .parakeet: "650 MB"
            }
        }

        var version: AsrModelVersion {
            switch self {
            case .parakeet: .ultra
            }
        }
    }

    nonisolated enum State: Equatable, Sendable {
        case missing
        case downloading(Double)
        case ready
        case failed
    }

    private(set) var states: [Kind: State] = [:]
    /// Downloaded because someone picked it: switch to it once it's here.
    var wanted: Kind?

    @ObservationIgnored private var manager: AsrManager?
    @ObservationIgnored private var loaded: Kind?
    @ObservationIgnored private var loading: (kind: Kind, task: Task<AsrManager?, Never>)?
    /// Your words, as a boosting session, and the words it was made for.
    @ObservationIgnored private var booster: (words: [String], session: VocabularyBoostingSession)?
    @ObservationIgnored private var ctcModels: CtcModels?
    /// The pass running now: one at a time, so a hold's last pass never shares the model
    /// with a pass from while you held.
    @ObservationIgnored private var turn: Task<Void, Never>?

    private var folder: URL { MacLibrary.shared.folder.appendingPathComponent("models", isDirectory: true) }

    private init() {
        for kind in Kind.allCases {
            states[kind] = AsrModels.modelsExist(at: directory(kind), version: kind.version) ? .ready : .missing
        }
    }

    /// Where FluidAudio puts a model: it keeps the files in a folder named for the model,
    /// beside the path it's given, so each model gets a folder of its own to delete.
    private func directory(_ kind: Kind) -> URL {
        folder.appendingPathComponent(kind.rawValue, isDirectory: true).appendingPathComponent("model", isDirectory: true)
    }

    func isReady(_ kind: Kind) -> Bool { states[kind] == .ready }

    /// The small model that checks the audio for your words (parakeet's CTC 110M, 98 MB). Its
    /// own folder, named as FluidAudio names it: it saves beside the path it's given but reads
    /// the vocabulary from the path itself, so the two must be the same.
    private var ctcDirectory: URL {
        folder.appendingPathComponent("words", isDirectory: true).appendingPathComponent("parakeet-ctc-110m-coreml", isDirectory: true)
    }

    // MARK: - Download and remove

    /// Fetches `kind` once. Downloading it is asking for it, so it's chosen when it lands.
    func download(_ kind: Kind) {
        if case .downloading = states[kind] { return }
        wanted = kind
        guard states[kind] != .ready else { return }
        states[kind] = .downloading(0)
        Task { await fetch(kind) }
    }

    /// The download itself. True when the model is on this mac.
    @discardableResult
    func fetch(_ kind: Kind) async -> Bool {
        print("[museo][speech] downloading \(kind.name)…")
        do {
            try await AsrModels.download(to: directory(kind), version: kind.version) { progress in
                Task { @MainActor in
                    guard case .downloading = self.states[kind] else { return }
                    self.states[kind] = .downloading(progress.fractionCompleted)
                }
            }
            // Your words need the small checking model too: fetched with it, so it's all here.
            _ = try? await CtcModels.download(to: ctcDirectory, variant: .ctc110m)
            states[kind] = .ready
            print("[museo][speech] \(kind.name) is on this mac")
            return true
        } catch {
            states[kind] = .failed
            print("[museo][speech] \(kind.name) didn't download:", error.localizedDescription)
            return false
        }
    }

    /// Deletes `kind`'s files from this mac.
    func remove(_ kind: Kind) {
        if loaded == kind {
            manager = nil
            loaded = nil
        }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(kind.rawValue, isDirectory: true))
        // The checking model for your words goes with it: nothing else uses it.
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("words", isDirectory: true))
        ctcModels = nil
        booster = nil
        states[kind] = .missing
        if wanted == kind { wanted = nil }
        print("[museo][speech] removed \(kind.name)")
    }

    // MARK: - Hearing

    /// Loads the chosen model (and your words) ahead of the first hold, so that one isn't slow.
    func warm() {
        Task {
            guard await ready() != nil else { return }
            _ = await boosting()
        }
    }

    /// A hold's words: its 16 kHz samples, from the ring. Nil when no local model is chosen
    /// and here, or it couldn't hear them.
    func words(of samples: [Int16]) async -> String? {
        guard !samples.isEmpty else { return nil }
        return await hear(samples.map { Float($0) / 32_768 })
    }

    /// A finished recording's words, or nil as above.
    func words(of url: URL) async -> String? {
        guard await ready() != nil else { return nil }
        do {
            let audio = try AudioConverter().resampleAudioFile(url)
            return await hear(audio)
        } catch {
            print("[museo][speech] couldn't read a recording:", error.localizedDescription)
            return nil
        }
    }

    /// The chosen model is loaded and can hear a hold while it happens.
    var canHearWhileHolding: Bool {
        guard let kind = MacSpeech.model.local else { return false }
        return loaded == kind && manager != nil
    }

    /// A quick pass while you hold: the model alone, without the check for your words, so it
    /// keeps up. Nil when the model isn't loaded yet (it never waits for a load).
    func quickWords(of samples: ArraySlice<Int16>) async -> String? {
        guard canHearWhileHolding, let manager, let kind = loaded, !samples.isEmpty else { return nil }
        let audio = samples.map { Float($0) / 32_768 }
        return await inTurn {
            var state = TdtDecoderState.make(decoderLayers: kind.version.decoderLayers)
            let text = try? await manager.transcribe(audio, decoderState: &state).text
            return text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Runs `work` after the pass before it.
    private func inTurn<T>(_ work: @escaping () async -> T) async -> T {
        let before = turn
        let mine = Task { () -> T in
            await before?.value
            return await work()
        }
        turn = Task { _ = await mine.value }
        return await mine.value
    }

    /// 16 kHz audio to words, leaning toward your words.
    private func hear(_ audio: [Float]) async -> String? {
        guard let manager = await ready(), let kind = loaded else { return nil }
        return await inTurn { await self.hear(audio, manager: manager, kind: kind) }
    }

    private func hear(_ audio: [Float], manager: AsrManager, kind: Kind) async -> String? {
        var state = TdtDecoderState.make(decoderLayers: kind.version.decoderLayers)
        let started = Date.now
        do {
            let result = try await manager.transcribe(audio, decoderState: &state)
            var text = result.text
            if let booster = await boosting(), let timings = result.tokenTimings,
               let boosted = await booster.rescore(text: text, tokenTimings: timings, audioSamples: audio), boosted.wasModified {
                print("[museo][speech] your words: \(boosted.replacements.count) fixed")
                text = boosted.text
            }
            print("[museo][speech] \(kind.name): \(String(format: "%.2f", Date.now.timeIntervalSince(started)))s for \(String(format: "%.1f", Double(audio.count) / 16_000))s")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[museo][speech] \(kind.name) couldn't hear it:", error.localizedDescription)
            return nil
        }
    }

    /// How alike a heard word and one of your words must look to swap them ("vos" and "Voz").
    private static let wordsSimilarity: Float = 0.6

    /// Your words as a boosting session, made again when they change. Nil with no words, or
    /// before the checking model is here (it's fetched now, for next time).
    private func boosting() async -> VocabularyBoostingSession? {
        let words = YourWords.shared.words
        guard !words.isEmpty else { return nil }
        if let booster, booster.words == words { return booster.session }
        do {
            if ctcModels == nil {
                // Fetches it the first time; after that it finds it here and returns.
                try await CtcModels.download(to: ctcDirectory, variant: .ctc110m)
                ctcModels = try await CtcModels.load(from: ctcDirectory, variant: .ctc110m)
            }
            guard let ctcModels else { return nil }
            let vocabulary = CustomVocabularyContext(terms: words.map { CustomVocabularyTerm(text: $0) })
            // Dictation: a wrong swap ("smooth" for "museo") is worse than a miss. So no
            // guessing from the audio alone, and a word has to look like the term too.
            let session = try await VocabularyBoostingSession(
                vocabulary: vocabulary,
                ctcModels: ctcModels,
                config: VocabularyRescorer.Config(spotterRescueEnabled: false),
                thresholds: .init(cbw: 0, minSimilarity: Self.wordsSimilarity)
            )
            booster = (words, session)
            print("[museo][speech] your words: \(words.count) ready")
            return session
        } catch {
            print("[museo][speech] your words aren't ready:", error.localizedDescription)
            return nil
        }
    }

    /// The chosen model, loaded; nil when the choice is apple's or it isn't downloaded.
    private func ready() async -> AsrManager? {
        guard let kind = MacSpeech.model.local, isReady(kind) else { return nil }
        if loaded == kind, let manager { return manager }
        if let loading, loading.kind == kind { return await loading.task.value }
        let task = Task { () -> AsrManager? in
            do {
                let models = try await AsrModels.load(from: directory(kind), version: kind.version)
                let manager = AsrManager()
                try await manager.loadModels(models)
                return manager
            } catch {
                print("[museo][speech] couldn't load \(kind.name):", error.localizedDescription)
                return nil
            }
        }
        loading = (kind, task)
        let manager = await task.value
        loading = nil
        if let manager {
            self.manager = manager
            loaded = kind
            print("[museo][speech] \(kind.name) loaded")
        }
        return manager
    }
}
