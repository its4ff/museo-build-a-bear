import AVFoundation
import CoreMedia
import Foundation
import OSLog
import Speech
import Synchronization
#if canImport(DesertAnt)
import DesertAnt
#endif

/// Turns a muse's audio into words, on this iphone. Nothing is uploaded.
///
/// ```swift
/// let result = try await SpeechEngine.shared.transcribe(wavURL, lane: .interactive)
/// print(result.text, result.words.first?.start ?? 0)
/// ```
///
/// What happens to one file, in order:
/// 1. The language is the one picked in build › speech, else this iphone's.
/// 2. Apple's `SpeechTranscriber` writes the words with timings and confidence, or
///    `DictationTranscriber` where the long-form model doesn't cover the language.
///    Your vocabulary (`AppConfig.vocabulary` + `setExtraVocabulary`) steers it.
/// 3. Voz takes over when it's chosen, downloaded and knows the language. Any Voz
///    failure falls back to Apple, so the choice can never cost a muse.
/// 4. The text gets paragraph breaks where the speaker paused after a sentence.
///
/// Word timings are the recognizer's own, from the same pass: nothing runs after it, so
/// the words land the moment the recognizer finishes.
///
/// Analyses run one at a time. `.interactive` (a muse that just arrived) always goes
/// first and preempts a running `.background` job (catch-up), which goes back in line
/// rather than failing.
///
/// Voz comes from Desert Ant Labs (free under 100k monthly devices per model,
/// attribution required, credited in build › about). Remove it and this still
/// compiles: every muse goes to Apple.
actor SpeechEngine {
    nonisolated static let shared = SpeechEngine()

    nonisolated enum Lane: Sendable {
        /// A muse that just arrived, or one someone asked for. Jumps the line.
        case interactive
        /// Catch-up work. Waits while the backlog is paused and yields to `.interactive`.
        case background
    }

    nonisolated private enum Recognizer: Sendable {
        case speech
        case dictation
    }

    nonisolated private struct Waiter {
        let id: UUID
        let key: String
        let lane: Lane
        /// Resumed with true when the job gets the engine, false when its caller gave up.
        let continuation: CheckedContinuation<Bool, Never>
    }

    nonisolated static let log = Logger(subsystem: "museo.build", category: "engine")
    /// Results kept for repeat asks of the same file, language and engine.
    nonisolated private static let recentLimit = 8

    private var running = false
    private var waiting: [Waiter] = []
    private var backlogPaused = false
    /// One job per file, language and engine. Everyone asking for the same pass shares it.
    private var inFlight: [String: Task<SpeechResult, Error>] = [:]
    /// The current try of each job. Preempting cancels this, never the job, so callers
    /// sharing the job keep waiting while it goes back in line.
    private var attempts: [String: Task<SpeechResult, Error>] = [:]
    /// The job holding the engine, so an interactive arrival can preempt it.
    private var runningKey: String?
    private var runningLane: Lane?
    /// Background jobs cancelled to make room; they re-queue instead of failing.
    private var preempted: Set<String> = []
    private var recent: [String: SpeechResult] = [:]
    private var recentOrder: [String] = []
    private var epoch = 0
    private var preparedLocaleID: String?

    init() {
        Self.keepUsageAnonymous()
    }

    // MARK: - Vocabulary

    nonisolated private static let extraVocabulary = Mutex<[String]>([])

    /// Extra words the recognizer should expect, on top of `AppConfig.vocabulary`:
    /// your app names, people, places. Replaces the last extra list. Applies from the
    /// next muse on.
    nonisolated static func setExtraVocabulary(_ words: [String]) {
        let cleaned = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        extraVocabulary.withLock { $0 = cleaned }
    }

    /// Everything the recognizer is told to expect, without repeats.
    nonisolated static var vocabulary: [String] {
        var seen = Set<String>()
        return (AppConfig.vocabulary + extraVocabulary.withLock { $0 }).filter {
            seen.insert($0.lowercased()).inserted
        }
    }

    // MARK: - Public

    /// Installs Apple's model for the language muses fall back to (the pick in build ›
    /// speech, else this iphone's) and asks iOS to keep it, so the first real muse doesn't
    /// wait. Call at launch and when the language changes. Safe to call often.
    func prepareAssets() async {
        do {
            let (locale, recognizer) = try await resolveLocale(languageHint: nil)
            if preparedLocaleID != locale.identifier {
                // Reservations are few: let any other language go first.
                for reserved in await AssetInventory.reservedLocales
                where reserved.identifier(.bcp47) != locale.identifier(.bcp47) {
                    await AssetInventory.release(reservedLocale: reserved)
                }
                // Reserved models stay on the phone when storage runs low.
                _ = try? await AssetInventory.reserve(locale: locale)
                try await ensureInstalled(modules(for: recognizer, locale: locale))
                preparedLocaleID = locale.identifier
                Self.log.info("speech model ready: \(locale.identifier(.bcp47), privacy: .public)")
            }
        } catch {
            Self.log.info("speech model prepare deferred: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Transcribes a WAV and returns its words with timings.
    ///
    /// `languageHint` (an ISO code like "es") pins the recognizer to that language and
    /// throws `.unsupportedLanguage` rather than guessing. Leave it nil to go by build ›
    /// speech (auto, or the picked language).
    ///
    /// Throws `SpeechError` (check `isRetryable`), `CancellationError` when the calling
    /// task is cancelled, or, rarely, Apple's own recognizer error (treat it as failed;
    /// run its text through `museQuiet` before showing it).
    func transcribe(_ wavURL: URL, lane: Lane, languageHint: String? = nil) async throws -> SpeechResult {
        guard let sha = await Self.fingerprint(wavURL) else {
            throw SpeechError.unreadableAudio
        }
        // The language and the engine are part of the key: switching either must not
        // hand back the other one's recent result.
        let language = languageHint ?? SpeechLanguage.chosenID ?? "auto"
        let engine = VozSpeech.isChosen && VozSpeech.isDownloaded ? "voz" : "apple"
        let key = "\(sha)|\(language)|\(engine)"
        if let hit = recent[key] { return hit }
        // The same pass is already under way (a retry tapped twice): share it.
        if let existing = inFlight[key] { return try await existing.value }

        let startedEpoch = epoch
        let job = Task {
            try await self.runRequeuing(wavURL: wavURL, key: key, lane: lane, languageHint: languageHint)
        }
        inFlight[key] = job
        defer { inFlight[key] = nil }
        let result = try await withTaskCancellationHandler {
            try await job.value
        } onCancel: {
            job.cancel()
        }
        if epoch == startedEpoch { remember(result, key: key) }
        return result
    }

    /// Holds the background lane (while capturing, or during anything that wants the
    /// Neural Engine), or lets it run again. Pausing also preempts a running background job.
    func setBacklogPaused(_ paused: Bool) {
        backlogPaused = paused
        if paused { preemptBackground() }
        resumeNext()
    }

    /// Forgets recent results, so nothing from deleted muses can be served again.
    func reset() {
        epoch += 1
        recent.removeAll()
        recentOrder.removeAll()
    }

    // MARK: - Pipeline

    /// One job: tries until it lands. A background try preempted for a fresh muse goes
    /// back in line rather than fail.
    private func runRequeuing(
        wavURL: URL,
        key: String,
        lane: Lane,
        languageHint: String?
    ) async throws -> SpeechResult {
        let queuedAt = ContinuousClock.now
        while true {
            let attempt = Task {
                try await self.run(wavURL: wavURL, key: key, lane: lane, languageHint: languageHint, queuedAt: queuedAt)
            }
            attempts[key] = attempt
            do {
                let result = try await withTaskCancellationHandler {
                    try await attempt.value
                } onCancel: {
                    attempt.cancel()
                }
                attempts[key] = nil
                // A preempt that landed too late to stop the try leaves nothing to re-queue.
                preempted.remove(key)
                return result
            } catch {
                attempts[key] = nil
                if preempted.remove(key) != nil, !Task.isCancelled {
                    Self.log.info("background job preempted, re-queued")
                    continue
                }
                throw error
            }
        }
    }

    private func run(
        wavURL: URL,
        key: String,
        lane: Lane,
        languageHint: String?,
        queuedAt: ContinuousClock.Instant
    ) async throws -> SpeechResult {
        // The gate marks this job as the running one when it lets it in, so a fresh
        // muse can preempt it from its first moment.
        try await acquire(lane, key: key)
        defer {
            runningKey = nil
            runningLane = nil
            release()
        }
        try Task.checkCancellation()

        let started = ContinuousClock.now
        guard AudioCheck.isIntact(wavURL) else { throw SpeechError.unreadableAudio }

        // A pinned language: the call's hint, or the pick in build › speech.
        let pinned = languageHint ?? SpeechLanguage.chosenID
        let wanted = pinned.flatMap { Locale(identifier: $0).language.languageCode?.identifier }

        // Voz first when it knows the pinned language, even one Apple can't do on this
        // iphone. Voz holds the whole clip in memory, so very long recordings stay with
        // Apple, which reads the file as it goes.
        let fitsVoz = (AudioCheck.duration(wavURL) ?? 0) <= VozSpeech.maxSeconds
        var triedVoz: String?
        if fitsVoz, let wanted, VozSpeech.isActive(for: wanted) {
            triedVoz = wanted
            if let result = try await Self.voz(wavURL, languageCode: wanted) { return result }
            try Task.checkCancellation()
        }

        let (locale, recognizer) = try await resolveLocale(languageHint: languageHint)
        let languageCode = locale.language.languageCode?.identifier
        if fitsVoz, let languageCode, languageCode != triedVoz, VozSpeech.isActive(for: languageCode) {
            if let result = try await Self.voz(wavURL, languageCode: languageCode) { return result }
            try Task.checkCancellation()
        }

        let modules = modules(for: recognizer, locale: locale)
        try await ensureInstalled(modules)
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: wavURL)
        } catch {
            throw SpeechError.unreadableAudio
        }
        let duration = Double(file.length) / max(file.fileFormat.sampleRate, 1)

        let analyzer = SpeechAnalyzer(
            modules: modules,
            options: SpeechAnalyzer.Options(
                priority: lane == .interactive ? .userInitiated : .utility,
                modelRetention: .lingering
            )
        )
        let context = AnalysisContext()
        context.contextualStrings[.general] = Self.vocabulary
        try? await analyzer.setContext(context)
        let built = ContinuousClock.now
        // Loads the model now rather than lazily on the first audio, so the log can tell
        // a slow load from slow listening.
        try? await analyzer.prepareToAnalyze(in: file.processingFormat)
        let prepared = ContinuousClock.now

        // Results stream while audio is still being read, so they're collected
        // concurrently or the analyzer stalls waiting to drain. The collector is its own
        // task, never awaited after a failure: if the analyzer throws, the collector is
        // cancelled and left behind rather than waited on, so a results stream that
        // never ends can't hold the engine.
        let module = modules[0]
        let collector = Task { try await Self.collectPhrases(from: module) }
        let phrases: [Phrase]
        let read: ContinuousClock.Instant
        let finished: ContinuousClock.Instant
        do {
            (phrases, read, finished) = try await withTaskCancellationHandler {
                let last = try await analyzer.analyzeSequence(from: file)
                let read = ContinuousClock.now
                if let last {
                    try await analyzer.finalizeAndFinish(through: last)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
                let finished = ContinuousClock.now
                return (try await collector.value, read, finished)
            } onCancel: {
                collector.cancel()
                Task { await analyzer.cancelAndFinishNow() }
            }
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
        try Task.checkCancellation()

        let analyzed = ContinuousClock.now
        let tokens = Self.tokens(from: phrases)
        let words = Self.words(from: tokens)
        let segments = phrases.compactMap { phrase -> TimedSegment? in
            let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TimedSegment(text: text, startMs: phrase.startMs, endMs: max(phrase.endMs, phrase.startMs))
        }
        let textModel = recognizer == .speech ? "apple-speech" : "apple-dictation"
        let confidenceWords = phrases.reduce(0) { $0 + $1.confidenceWords }
        let confidenceSum = phrases.reduce(0.0) { $0 + $1.confidenceSum }
        // All zeros reads as "not reported", never as a muse heard badly.
        let confidence = confidenceWords > 0 && confidenceSum > 0
            ? confidenceSum / Double(confidenceWords) : nil
        let result = SpeechResult(
            text: SpeechParagrapher.compose(tokens),
            words: words,
            segments: segments,
            language: languageCode,
            confidence: confidence,
            textModel: textModel,
            timingModel: textModel
        )

        // Per stage, so a slow muse says where its time went.
        Self.log.info("""
            transcribed \(String(format: "%.1f", duration), privacy: .public)s audio: \
            queued \(Self.seconds(queuedAt, started), privacy: .public)s, \
            speech \(Self.seconds(started, analyzed), privacy: .public)s \
            (setup \(Self.seconds(started, built), privacy: .public), \
            load \(Self.seconds(built, prepared), privacy: .public), \
            read \(Self.seconds(prepared, read), privacy: .public), \
            finish \(Self.seconds(read, finished), privacy: .public), \
            collect \(Self.seconds(finished, analyzed), privacy: .public)), \
            \(words.count, privacy: .public) words, \(textModel, privacy: .public), \
            \(languageCode ?? "-", privacy: .public), \
            confidence=\(confidence.map { String(format: "%.2f", $0) } ?? "-", privacy: .public), \
            lane=\(lane == .interactive ? "interactive" : "background", privacy: .public)
            """)
        return result
    }

    /// Timings and confidence ride along in the same pass.
    private func modules(for recognizer: Recognizer, locale: Locale) -> [any SpeechModule] {
        switch recognizer {
        case .speech:
            [SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )]
        case .dictation:
            [DictationTranscriber(
                locale: locale,
                contentHints: [],
                transcriptionOptions: [.punctuation],
                reportingOptions: [],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )]
        }
    }

    /// A recognizer for words while the ring streams (`LiveSpeech`): the language and model a
    /// file would get, reporting words while they're still forming. Nil when that model isn't
    /// on this iphone yet, so a hold never waits on a download.
    func liveTranscriber() async -> (any SpeechModule)? {
        guard let resolved = try? await resolveLocale(languageHint: nil) else { return nil }
        let (locale, recognizer) = resolved
        let module: any SpeechModule = switch recognizer {
        case .speech:
            SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            )
        case .dictation:
            DictationTranscriber(
                locale: locale,
                contentHints: [],
                transcriptionOptions: [.punctuation],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
        }
        do {
            guard try await AssetInventory.assetInstallationRequest(supporting: [module]) == nil else { return nil }
        } catch {
            return nil
        }
        return module
    }

    /// The language to transcribe in, and which recognizer covers it.
    ///
    /// Candidates, in order: the hint alone; or the pick from build › speech, then this
    /// iphone's language, then english; or (auto) this iphone's language, then english.
    /// For each, `SpeechTranscriber` (the long-form model) when this device has it, then
    /// `DictationTranscriber`. Language before model: dictation in the right language
    /// beats long-form in the wrong one.
    private func resolveLocale(languageHint: String?) async throws -> (Locale, Recognizer) {
        let english = Locale(identifier: "en-US")
        let candidates: [Locale]
        if let languageHint {
            candidates = [Locale(identifier: languageHint)]
        } else if let chosen = SpeechLanguage.chosenID {
            candidates = [Locale(identifier: chosen), .current, english]
        } else {
            candidates = [.current, english]
        }
        // Older devices lack the long-form model; dictation still works there.
        let longForm = SpeechTranscriber.isAvailable
        for candidate in candidates {
            if longForm, let match = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return (match, .speech)
            }
            if let match = await DictationTranscriber.supportedLocale(equivalentTo: candidate) {
                return (match, .dictation)
            }
        }
        throw SpeechError.unsupportedLanguage
    }

    /// Apple ships each language's model separately from the OS, one download per
    /// language, shared and kept current by the system. A nil request means installed.
    private func ensureInstalled(_ modules: [any SpeechModule]) async throws {
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await request.downloadAndInstall()
            }
        } catch {
            // A job stopped mid-download is cancelled, not short of a model.
            try Task.checkCancellation()
            Self.log.error("speech model install failed: \(error.localizedDescription, privacy: .public)")
            throw SpeechError.assetsUnavailable
        }
    }

    // MARK: - Helpers off the engine

    /// The audio's fingerprint, read off the engine so a long file never blocks it.
    @concurrent
    nonisolated private static func fingerprint(_ url: URL) async -> String? {
        AudioCheck.sha256(url)
    }

    /// Voz's words, or nil when it failed (the caller goes on with Apple).
    nonisolated private static func voz(_ wavURL: URL, languageCode: String) async throws -> SpeechResult? {
        do {
            return try await VozSpeech.shared.transcribe(wavURL, languageCode: languageCode)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            log.error("voz failed, using apple speech: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Desert Ant counts devices for its free tier. Keep the count, without the device
    /// model, OS and locale. (`DesertAnt.usageDisabled = true` turns it off entirely;
    /// check their licence before you do.)
    nonisolated static func keepUsageAnonymous() {
        #if canImport(DesertAnt)
        DesertAnt.sendsDeviceContext = false
        #endif
    }

    nonisolated private static func seconds(_ from: ContinuousClock.Instant, _ to: ContinuousClock.Instant) -> String {
        let span = from.duration(to: to).components
        return String(format: "%.2f", Double(span.seconds) + Double(span.attoseconds) / 1e18)
    }

    // MARK: - Gate

    /// Waits for the engine. Throws `CancellationError`, without holding the engine,
    /// when the caller gives up while still in line, so a cancelled job never waits out
    /// a paused backlog or a long muse ahead of it.
    private func acquire(_ lane: Lane, key: String) async throws {
        if lane == .interactive { preemptBackground() }
        let id = UUID()
        let granted = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                waiting.append(Waiter(id: id, key: key, lane: lane, continuation: continuation))
                resumeNext()
            }
        } onCancel: {
            Task { await self.abandon(id) }
        }
        guard granted else { throw CancellationError() }
    }

    /// Takes a cancelled job out of line. A job already given the engine is left alone;
    /// it sees the cancellation itself and releases the engine on the way out.
    private func abandon(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(returning: false)
    }

    /// Cancels the running background try, if any; its job re-queues it.
    private func preemptBackground() {
        guard runningLane == .background, let key = runningKey, let attempt = attempts[key] else { return }
        preempted.insert(key)
        attempt.cancel()
    }

    private func release() {
        running = false
        resumeNext()
    }

    private func resumeNext() {
        guard !running else { return }
        let index = waiting.firstIndex { $0.lane == .interactive }
            ?? (backlogPaused ? nil : waiting.firstIndex { $0.lane == .background })
        guard let index else { return }
        running = true
        let next = waiting.remove(at: index)
        runningKey = next.key
        runningLane = next.lane
        next.continuation.resume(returning: true)
    }

    private func remember(_ result: SpeechResult, key: String) {
        recent[key] = result
        recentOrder.removeAll { $0 == key }
        recentOrder.append(key)
        while recentOrder.count > Self.recentLimit {
            recent[recentOrder.removeFirst()] = nil
        }
    }

    // MARK: - Words

    nonisolated fileprivate struct Phrase: Sendable {
        let text: String
        let startMs: Int
        let endMs: Int
        /// The phrase cut into runs, each with the audio it covers (nil for runs the
        /// recognizer didn't time, like some punctuation).
        let runs: [(text: String, startMs: Int?, endMs: Int?)]
        /// Word confidence summed over the phrase's words, and how many words carried
        /// one, so the muse's mean weighs every word alike.
        let confidenceSum: Double
        let confidenceWords: Int
    }

    @concurrent
    nonisolated private static func collectPhrases(from module: any SpeechModule) async throws -> [Phrase] {
        var phrases: [Phrase] = []
        if let transcriber = module as? SpeechTranscriber {
            for try await result in transcriber.results where result.isFinal {
                phrases.append(phrase(text: result.text, range: result.range))
            }
        } else if let transcriber = module as? DictationTranscriber {
            for try await result in transcriber.results where result.isFinal {
                phrases.append(phrase(text: result.text, range: result.range))
            }
        }
        return phrases
    }

    nonisolated private static func phrase(text: AttributedString, range: CMTimeRange) -> Phrase {
        var runs: [(text: String, startMs: Int?, endMs: Int?)] = []
        for (timeRange, slice) in text.runs[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
            runs.append((
                text: String(text[slice].characters),
                startMs: timeRange.map { milliseconds($0.start) },
                endMs: timeRange.map { milliseconds($0.end) }
            ))
        }
        // Equal neighbours merge into one run, so a run is weighed by its words.
        var confidenceSum = 0.0
        var confidenceWords = 0
        for (confidence, slice) in text.runs[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self] {
            guard let confidence, confidence.isFinite else { continue }
            let words = String(text[slice].characters)
                .split(whereSeparator: \.isWhitespace)
                .filter { SpeechTokens.isWordBearing(String($0)) }
                .count
            confidenceSum += min(max(confidence, 0), 1) * Double(words)
            confidenceWords += words
        }
        return Phrase(
            text: String(text.characters),
            startMs: milliseconds(range.start),
            endMs: milliseconds(range.end),
            runs: runs,
            confidenceSum: confidenceSum,
            confidenceWords: confidenceWords
        )
    }

    nonisolated private static func milliseconds(_ time: CMTime) -> Int {
        let seconds = time.seconds
        return seconds.isFinite ? Int((seconds * 1_000).rounded()) : 0
    }

    /// Whitespace tokens across all phrases. A token spans every timed run it touches;
    /// untimed tokens get a time from their neighbours.
    nonisolated private static func tokens(from phrases: [Phrase]) -> [SpeechToken] {
        var tokens: [SpeechToken] = []
        for phrase in phrases {
            var text = ""
            var start: Int?
            var end: Int?
            func flush() {
                if !text.isEmpty {
                    tokens.append(SpeechToken(text: text, start: start, end: end))
                }
                text = ""
                start = nil
                end = nil
            }
            for run in phrase.runs {
                for character in run.text {
                    if character.isWhitespace {
                        flush()
                        continue
                    }
                    text.append(character)
                    if let runStart = run.startMs { start = min(start ?? runStart, runStart) }
                    if let runEnd = run.endMs { end = max(end ?? runEnd, runEnd) }
                }
            }
            flush()
        }
        SpeechToken.fillGaps(&tokens)
        return tokens
    }

    /// The word-bearing tokens as timed words, each at least 40 ms long.
    nonisolated static func words(from tokens: [SpeechToken]) -> [TimedWord] {
        tokens.filter(\.isWordBearing).map {
            TimedWord(text: $0.text, startMs: $0.startMs, endMs: max($0.endMs, $0.startMs + 40))
        }
    }
}

// MARK: - Tokens

/// A whitespace-delimited token of recognized text with its audio span in ms.
nonisolated struct SpeechToken: Sendable {
    var text: String
    var start: Int?
    var end: Int?

    var startMs: Int { start ?? 0 }
    var endMs: Int { end ?? startMs }

    /// Has at least one letter or digit.
    var isWordBearing: Bool { SpeechTokens.isWordBearing(text) }

    /// Gives untimed tokens a time: punctuation sits at the previous word's end;
    /// untimed words are spread evenly between their timed neighbours (180 ms each
    /// when there is nothing to go by).
    static func fillGaps(_ tokens: inout [SpeechToken]) {
        var index = 0
        while index < tokens.count {
            guard tokens[index].start == nil || tokens[index].end == nil else {
                index += 1
                continue
            }
            let runStart = index
            while index < tokens.count, tokens[index].start == nil || tokens[index].end == nil {
                index += 1
            }
            let previousEnd = runStart > 0 ? tokens[runStart - 1].end : nil
            let nextStart = index < tokens.count ? tokens[index].start : nil
            let count = index - runStart
            let from = previousEnd ?? max(0, (nextStart ?? count * 180) - count * 180)
            let to = max(nextStart ?? (from + count * 180), from)
            let step = count > 0 ? (to - from) / count : 0
            for offset in 0..<count {
                let start = from + offset * step
                tokens[runStart + offset].start = start
                tokens[runStart + offset].end = start + step
            }
        }
    }
}

// MARK: - Paragraphs

/// Rebuilds display text from recognized tokens, starting a new paragraph where the
/// speaker ends a sentence and pauses. Only the whitespace between words changes, so
/// the text and its timings stay one to one.
nonisolated enum SpeechParagrapher {
    /// A clear pause after a sentence starts a new paragraph.
    static let paragraphPauseMs = 1_200
    /// Long paragraphs break on a shorter pause.
    static let longParagraphPauseMs = 700
    static let longParagraphWords = 60
    /// Very long paragraphs break at the next sentence end regardless.
    static let maxParagraphWords = 120
    /// Short notes stay one paragraph.
    static let minimumWordsToSplit = 25
    /// Don't strand a one-line paragraph.
    static let minimumParagraphWords = 6

    static func compose(_ tokens: [SpeechToken]) -> String {
        let wordCount = tokens.filter(\.isWordBearing).count
        guard wordCount >= minimumWordsToSplit else {
            return tokens.map(\.text).joined(separator: " ")
        }

        var output = ""
        var paragraphWords = 0
        for (index, token) in tokens.enumerated() {
            if index > 0 {
                let previous = tokens[index - 1]
                let gap = token.startMs - previous.endMs
                let breaks = token.isWordBearing
                    && SpeechTokens.endsSentence(previous.text)
                    && paragraphWords >= minimumParagraphWords
                    && (gap >= paragraphPauseMs
                        || (paragraphWords >= longParagraphWords && gap >= longParagraphPauseMs)
                        || paragraphWords >= maxParagraphWords)
                if breaks {
                    output += "\n\n"
                    paragraphWords = 0
                } else {
                    output += " "
                }
            }
            output += token.text
            if token.isWordBearing { paragraphWords += 1 }
        }
        return output
    }
}
