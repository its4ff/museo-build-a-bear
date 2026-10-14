import Foundation
import MuseoKit
import Observation
import OSLog
import UIKit

/// How something you said becomes a muse, end to end:
///
/// ```
/// Museo.onCapture ─▶ ingest ─▶ MuseStore.insert ─▶ words (SpeechEngine, on this iphone)
///                                                  ─▶ title (MuseAI, on this iphone)
///                                                  ─▶ notes, 150 words and up (MuseAI)
///                                     typed ─▶ addTyped ─▶ title ─▶ notes
/// ```
///
/// You rarely call it: `AppStart.start` attaches it to the ring and every finished
/// capture flows through on its own. To react to muses, use `MuseHooks` (see
/// `App/YourCode.swift`). To make muses without the ring:
///
/// ```swift
/// @Environment(MusePipeline.self) private var pipeline
/// pipeline.addTyped("remind me to call mum")
/// pipeline.loadSamples()
/// ```
///
/// A memory recording over 30 minutes lands in 30-minute parts, each its own muse until
/// its neighbor has words too; then `MuseJoiner` folds them into one (`joinParts`).
///
/// Nothing is lost on the way. A muse is saved before its words exist; one left halfway
/// (the app was closed, or iOS took its background time back) stays pending and `sweep()`
/// picks it up at the next launch or foreground.
///
/// A title the person wrote (`Muse.titleIsTheirs`) is never replaced. Samples never run the
/// model, and blank muses get no title or notes.
@MainActor
@Observable
final class MusePipeline {
    static let shared = MusePipeline()

    /// Muses being transcribed or titled right now. Cards can show a quiet "working" state.
    private(set) var working: Set<UUID> = []
    /// Muses whose notes are being written, or waiting their turn. The muse page shows
    /// "writing it up…".
    private(set) var noting: Set<UUID> = []

    /// Recordings shorter than this (seconds) are accidental presses, like the kit's own
    /// `Museo.shortestCapture` for the ring.
    nonisolated static let shortestCapture: TimeInterval = Museo.shortestCapture
    /// Recent muses still missing a title get one at the next sweep while you're looking.
    nonisolated static let titleWindow: TimeInterval = 86_400
    /// A muse that landed this recently (seconds) jumps the transcription line.
    nonisolated static let freshWindow: TimeInterval = 600
    /// Recent muses missing notes get them at the next sweep, at most this many of each.
    /// Long thoughts take the model longest.
    nonisolated static let longThoughtsPerSweep = 3
    nonisolated static let briefsPerSweep = 8

    @ObservationIgnored private let store: MuseStore
    @ObservationIgnored private let isPreview: Bool
    @ObservationIgnored private var isAttached = false
    /// Older muses waiting for words, done one at a time on the background lane.
    @ObservationIgnored private var backlog: [UUID] = []
    @ObservationIgnored private var isDrainingBacklog = false
    /// Failed muses already given their one retry this launch.
    @ObservationIgnored private var retriedFailures: Set<UUID> = []
    /// Muses whose title the model was asked for while you were looking, this launch.
    @ObservationIgnored private var titleTried: Set<UUID> = []
    /// Muses whose notes the model was asked for while you were looking, this launch.
    @ObservationIgnored private var notesTried: Set<UUID> = []
    /// Notes waiting their turn. One muse at a time, so a backlog never asks the model for
    /// many at once. `force` writes them even over notes it has.
    @ObservationIgnored private var notesQueue: [(id: UUID, force: Bool)] = []
    @ObservationIgnored private var isWritingNotes = false
    @ObservationIgnored private var backgroundTasks: [UUID: UIBackgroundTaskIdentifier] = [:]
    /// The words being worked out for each muse, so running out of background time can stop them.
    @ObservationIgnored private var listening: [UUID: Task<SpeechResult, Error>] = [:]
    /// The last pause or resume sent to the speech backlog. Each waits for the one before.
    @ObservationIgnored private var backlogPause: Task<Void, Never>?
    /// The next try for muses left pending by a passing problem (no speech model yet,
    /// offline). One at a time, further apart each time.
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryStep = 0
    /// One join at a time. A call that lands mid-join asks for another look when it ends.
    @ObservationIgnored private var isJoining = false
    @ObservationIgnored private var joinAgain = false
    /// Later parts whose join didn't land this launch (a file couldn't be read, the iphone
    /// is full). Tried again next launch.
    @ObservationIgnored private var joinFailed: Set<UUID> = []

    nonisolated private static let log = Logger(subsystem: "museo.build", category: "pipeline")
    private static let unreadableNote = "this recording can't be read."
    private static let unknownNote = "the words didn't come through. try again in a moment."
    /// How long a sample "transcribes" on retry: about one pulse of the card's skeleton.
    private static let sampleReplay: Duration = .milliseconds(1_800)
    /// Waits between tries for a muse held back by a passing problem, while you're looking.
    private static let retryDelays: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]

    convenience init() {
        self.init(store: .shared, isPreview: false)
    }

    private init(store: MuseStore, isPreview: Bool) {
        self.store = store
        self.isPreview = isPreview
    }

    /// A pipeline for lab screens and previews. It adds muses to `store` but never
    /// transcribes or titles, and never touches the ring.
    static func preview(_ store: MuseStore, working: Set<UUID> = [], noting: Set<UUID> = []) -> MusePipeline {
        let pipeline = MusePipeline(store: store, isPreview: true)
        pipeline.working = working
        pipeline.noting = noting
        return pipeline
    }

    // MARK: - The ring

    /// Takes every finished ring recording from the kit (`Museo.onCapture`) and steps the
    /// speech catch-up aside while a muse streams. Called once at launch by `AppStart.start`.
    func attach() {
        guard !isPreview, !isAttached else { return }
        isAttached = true
        Museo.onCapture { [weak self] capture, seenBefore in
            self?.ingest(capture, seenBefore: seenBefore) ?? false
        }
        Museo.onEvent { [weak self] event in
            switch event {
            case .liveStarted: self?.pauseBacklog(true)
            case .liveEnded: self?.pauseBacklog(false)
            default: break
            }
        }
        removeDuplicateImports()
        #if DEBUG
        // `-museJoinProbe`: fold two made-up parts of one ring recording, check, then exit.
        if MuseJoinProbe.isRequested { MuseJoinProbe.run(self) }
        #endif
    }

    /// One finished ring recording becomes a muse: saved first, then its words. Returns
    /// true once it's safe on this iphone, and only then does the kit let the ring retire
    /// its copy. A recording brought in before (`seenBefore`, or one a muse already holds)
    /// never becomes a second muse; one whose muse you deleted never comes back.
    private func ingest(_ capture: CompletedCapture, seenBefore: Bool) -> Bool {
        // muses.json couldn't be read yet (the ring woke the app before the iphone was
        // unlocked): try again, and until it can be, take nothing. The ring keeps a memory
        // recording; the kit holds a streamed one and offers it again.
        store.reloadIfNeeded()
        guard store.isWritable else {
            Self.log.error("muses.json not readable yet; leaving \(capture.fileName, privacy: .public) with the kit")
            return false
        }
        // Downloaded again: the download wrote over the same file names, so the muse that
        // has them keeps them. When that muse was deleted, this copy goes too. (The kit
        // names every recording uniquely, undated ones included, so a name is the recording.)
        let owner = store.muses.first { muse in
            muse.sourceFileName == capture.fileName
                || (capture.wavFileName != nil && muse.audioFileName == capture.wavFileName)
        }
        if owner != nil || seenBefore {
            Self.log.info("already brought in · \(capture.fileName, privacy: .public)")
            // The files a muse holds stay. A part folded into a longer muse kept its .ops
            // name but not its wav, so a second download of it leaves the wav to go.
            discardFiles(of: capture)
            return store.flush()
        }
        if store.muse(id: capture.id) == nil {
            store.insert(Muse(
                id: capture.id,
                createdAt: capture.startedAt,
                endedAt: capture.endedAt,
                duration: capture.duration,
                origin: MuseOrigin(capture.source),
                audioFileName: capture.wavFileName,
                sourceFileName: capture.fileName,
                arrivedAt: .now,
                // Which of the ring's 30-minute files it is, so a long recording's parts join.
                ringParts: capture.source == .offline
                    ? capture.offlineSyncKey.flatMap {
                        RingParts(syncKey: $0, startedAt: capture.startedAt, duration: capture.duration)
                    }
                    : nil
            ))
        }
        // When muses.json can't be written (the iphone is full), the copy stays on the ring
        // and the next sync brings it in again.
        guard store.flush() else {
            Self.log.error("muses.json not saved; leaving the ring copy for the next sync")
            return false
        }
        Task { await process(capture.id, lane: .interactive) }
        return true
    }

    /// Before the ledger, a recording the kit forgot came in twice: two muses, one audio
    /// file. The first to arrive stays; a copy goes (the shared file stays with it), but only
    /// when its words are the same or one has none yet. Different words under one name
    /// (two undated recordings an older kit named alike) are two recordings, and both stay.
    private func removeDuplicateImports() {
        var first: [String: Muse] = [:]
        for muse in store.muses.sorted(by: { $0.arrivedAt < $1.arrivedAt }) where muse.origin == .offline {
            guard let name = muse.sourceFileName else { continue }
            guard let kept = first[name] else {
                first[name] = muse
                continue
            }
            guard kept.words.isEmpty || muse.words.isEmpty || kept.words == muse.words else { continue }
            Self.log.info("removed a second copy of \(name, privacy: .public)")
            store.remove(muse.id)
        }
    }

    // MARK: - Without the ring

    /// Typed words become a `.typed` muse: complete at once, then titled like any muse.
    /// Returns its id, or nil for empty text.
    @discardableResult
    func addTyped(_ text: String) -> UUID? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        let muse = Muse(
            createdAt: .now,
            duration: 0,
            origin: .typed,
            transcript: words,
            transcriptionState: .complete,
            textModel: "typed",
            arrivedAt: .now
        )
        store.insert(muse)
        guard !isPreview else { return muse.id }
        Task { await finish(muse.id) }
        return muse.id
    }

    /// Puts the nine sample muses on the home (replacing any already there). The newest
    /// one arrives now, so its words type in.
    func loadSamples() {
        removeSamples()
        var samples = SampleMuses.make(now: .now)
        if let newest = samples.indices.max(by: { samples[$0].createdAt < samples[$1].createdAt }) {
            samples[newest].arrivedAt = .now
        }
        for muse in samples { store.insert(muse) }
    }

    /// Takes the sample muses off the home. Your own muses stay.
    func removeSamples() {
        for muse in store.muses where muse.origin == .sample {
            store.remove(muse.id)
        }
    }

    // MARK: - Again

    /// Writes this muse's notes again from its words, first in line (the muse page's "write
    /// the notes again"). Does nothing for a muse too short for notes, or while they're being
    /// written. A sample shows the motions and keeps its notes (see `replayNotes`).
    func writeNotes(_ id: UUID) {
        guard !isPreview, !noting.contains(id), let muse = store.muse(id: id), muse.expectedNotes != nil else { return }
        if muse.origin == .sample {
            replayNotes(id)
            return
        }
        queueNotes(id, force: true, first: true)
    }

    /// Asks the model for a title again, for a muse whose title they just cleared
    /// (`MuseStore.setTitle("", for:)`). Leaves a title that's theirs, a blank muse and a
    /// sample alone.
    func retitle(_ id: UUID) {
        guard !isPreview, !working.contains(id), let muse = store.muse(id: id),
              muse.isTranscribed, !muse.isBlank, !muse.titleIsTheirs, muse.origin != .sample else { return }
        working.insert(id)
        Task {
            await addTitle(to: muse)
            working.remove(id)
            joinPartsSoon(after: id)
        }
    }

    /// Transcribes a muse again from its audio, first in line. For "transcribe again" on the
    /// muse page and "retry" on a failed card. Typed muses have no audio and are left alone;
    /// a sample shows the motions (see `replay`).
    func retranscribe(_ id: UUID) {
        guard !isPreview, !working.contains(id), let muse = store.muse(id: id) else { return }
        if muse.origin == .sample {
            replay(muse)
            return
        }
        guard muse.audioURL != nil else { return }
        backlog.removeAll { $0 == id }
        store.update(id) { muse in
            muse.transcriptionState = .pending
            muse.transcriptionError = nil
        }
        Task { await process(id, lane: .interactive) }
    }

    /// Launch and every foreground: takes recordings still waiting in the kit, picks up
    /// muses left without words (fresh ones first in line, older ones on the background
    /// lane), gives each failed muse one retry per launch, then asks for the titles and notes
    /// the model couldn't give while the app was in the background.
    func sweep() async {
        guard !isPreview else { return }
        #if DEBUG
        // The probes have the model, and the muses they make, to themselves.
        if MuseNotesProbe.isRequested || MuseJoinProbe.isRequested { return }
        #endif
        Museo.takeWaitingCaptures()

        let now = Date.now
        var fresh: [Muse] = []
        var older: [Muse] = []
        for muse in store.muses where !working.contains(muse.id) && !backlog.contains(muse.id) {
            guard Self.hasAudio(muse.origin) else {
                // A sample caught mid-retry when museo build closed goes back to how it was.
                if muse.origin == .sample, muse.transcriptionState == .transcribing {
                    fail(muse.id, Self.unreadableNote)
                }
                continue
            }
            switch muse.transcriptionState {
            case .complete:
                continue
            case .pending, .transcribing:
                guard muse.audioURL != nil else {
                    fail(muse.id, Self.unreadableNote)
                    continue
                }
            case .failed:
                guard muse.audioURL != nil, retriedFailures.insert(muse.id).inserted else { continue }
            }
            if muse.isFresh(within: Self.freshWindow, now: now) {
                fresh.append(muse)
            } else {
                older.append(muse)
            }
        }
        for muse in fresh.sorted(by: { $0.arrivedAt < $1.arrivedAt }) {
            Task { await process(muse.id, lane: .interactive) }
        }
        queueBacklog(older.sorted { $0.createdAt > $1.createdAt }.map(\.id))

        await joinParts()
        await catchUpTitles(now: now)
        catchUpNotes(now: now)
    }

    /// Called when museo build leaves the screen: tries waiting for the speech model stop
    /// (coming back sweeps anyway) and start again from the shortest wait.
    func enteredBackground() {
        retryTask?.cancel()
        retryTask = nil
        retryStep = 0
    }

    // MARK: - Words, title and notes

    /// One muse, start to finish. Safe to call twice: a muse already working, or already
    /// complete, is left alone. Runs inside a background task so a muse that lands while
    /// museo build is in the background still gets its words. Notes follow on their own
    /// lane (`queueNotes`), so the card stops working once it has words and a title.
    private func process(_ id: UUID, lane: SpeechEngine.Lane) async {
        guard !isPreview, !working.contains(id),
              let muse = store.muse(id: id), muse.transcriptionState != .complete else { return }
        // Its words landed once before ("transcribe again"): new words get their notes
        // written again, and a new title unless the title is theirs.
        let isRedo = muse.transcript != nil
        let oldWords = muse.words
        working.insert(id)
        beginBackgroundWork(id)
        defer {
            working.remove(id)
            endBackgroundWork(id)
            joinPartsSoon(after: id)
        }

        store.update(id) { muse in
            muse.transcriptionState = .transcribing
            muse.transcriptionError = nil
        }
        guard let url = muse.audioURL, await Self.isIntact(url) else {
            fail(id, Self.unreadableNote)
            return
        }

        // Its own task, so running out of background time can stop it (`outOfTime`).
        let job = Task { try await SpeechEngine.shared.transcribe(url, lane: lane) }
        listening[id] = job
        let outcome = await job.result
        listening[id] = nil
        let result: SpeechResult
        switch outcome {
        case .success(let heard):
            result = heard
        case .failure(let error):
            // Stopped on purpose: whatever the recognizer threw on the way out, it waits.
            settle(id, after: job.isCancelled ? CancellationError() : error)
            return
        }

        await Self.saveTimings(result, for: id)
        let blank = Muse.isBlankTranscript(result.text)
        let landed = store.update(id) { muse in
            muse.transcript = result.text
            muse.language = result.language
            muse.wordConfidence = result.confidence
            muse.textModel = result.textModel
            muse.isBlank = blank
            if blank {
                // A blank muse gets no title or notes. A title they wrote stays.
                if !muse.titleIsTheirs { muse.title = nil }
                muse.notes = nil
            }
            muse.transcriptionState = .complete
            muse.transcriptionError = nil
        }
        guard let landed else {
            // Deleted while it was being heard: don't leave its timings behind.
            TimedTranscriptStore.delete(id)
            return
        }
        // Words are landing again: the next passing problem starts from the shortest wait.
        retryStep = 0
        // A part of a long recording whose neighbor has its words is about to join: the
        // whole gets a title and notes then.
        guard !blank, !waitsToJoin(landed) else { return }
        // The same words again need neither a new title nor new notes.
        let wordsChanged = landed.words != oldWords
        if !isRedo || wordsChanged || landed.title == nil {
            await addTitle(to: landed)
        }
        queueNotes(id, force: isRedo && wordsChanged)
    }

    /// The title and notes for a muse whose words are already in (typed muses).
    private func finish(_ id: UUID) async {
        guard !working.contains(id), let muse = store.muse(id: id), muse.isTranscribed, !muse.isBlank else { return }
        working.insert(id)
        beginBackgroundWork(id)
        defer {
            working.remove(id)
            endBackgroundWork(id)
        }
        await addTitle(to: muse)
        queueNotes(id)
    }

    /// The model's title, unless the title is theirs. Samples never run the model.
    private func addTitle(to muse: Muse) async {
        guard muse.origin != .sample, !muse.titleIsTheirs else { return }
        // The model often won't answer in the background. Only a try made while you're
        // looking counts, so a muse that landed in your pocket is titled at the next sweep.
        if Self.isActive { titleTried.insert(muse.id) }
        let words = muse.words
        guard let title = await MuseAI.title(for: words) else { return }
        store.update(muse.id) { muse in
            // They may have named it while the model thought, or new words may have landed
            // (those get their own title).
            guard !muse.titleIsTheirs, !muse.isBlank, muse.words == words else { return }
            muse.title = title
        }
    }

    /// Titles for recent muses that landed while the model couldn't answer.
    private func catchUpTitles(now: Date) async {
        guard Self.isActive, MuseAI.isAvailable else { return }
        let untitled = store.muses.filter { muse in
            muse.isTranscribed && !muse.isBlank && muse.title == nil && !muse.titleIsTheirs
                && muse.origin != .sample
                && muse.isFresh(within: Self.titleWindow, now: now)
                && !titleTried.contains(muse.id) && !working.contains(muse.id)
                && !waitsToJoin(muse)
        }
        for muse in untitled {
            guard Self.isActive else { return }
            // A sweep that overlapped this one (launch, then the first foreground) may
            // have titled it, or started on it, while this one waited.
            guard !working.contains(muse.id), !titleTried.contains(muse.id),
                  let current = store.muse(id: muse.id), current.title == nil,
                  !current.titleIsTheirs, !current.isBlank else { continue }
            working.insert(muse.id)
            await addTitle(to: current)
            working.remove(muse.id)
            joinPartsSoon(after: muse.id)
        }
    }

    // MARK: - Notes

    /// Puts a muse in line for notes (`addNotes`) when it should have them. Already in line,
    /// it keeps its place unless `first`; `force` sticks either way. Forced for a muse whose
    /// new words are too short for notes, the old notes go.
    private func queueNotes(_ id: UUID, force: Bool = false, first: Bool = false) {
        guard !isPreview, let muse = store.muse(id: id), muse.origin != .sample else { return }
        guard muse.expectedNotes != nil else {
            if force, muse.notes != nil { store.update(id) { $0.notes = nil } }
            return
        }
        guard force || muse.notes == nil else { return }
        var force = force
        if let index = notesQueue.firstIndex(where: { $0.id == id }) {
            force = force || notesQueue[index].force
            if first {
                notesQueue.remove(at: index)
            } else {
                notesQueue[index].force = force
                return
            }
        }
        if first {
            notesQueue.insert((id, force), at: 0)
        } else {
            notesQueue.append((id, force))
        }
        noting.insert(id)
        drainNotes()
    }

    /// Writes the line of notes one muse at a time, under background time of its own, so
    /// notes that start as you lock the phone still have a moment to land.
    private func drainNotes() {
        guard !isWritingNotes, !notesQueue.isEmpty else { return }
        isWritingNotes = true
        let token = UUID()
        beginBackgroundWork(token, name: "muse.notes")
        Task {
            while !notesQueue.isEmpty {
                let job = notesQueue.removeFirst()
                await addNotes(to: job.id, force: job.force)
                if !notesQueue.contains(where: { $0.id == job.id }) {
                    noting.remove(job.id)
                    joinPartsSoon(after: job.id)
                }
            }
            isWritingNotes = false
            endBackgroundWork(token)
        }
    }

    /// Notes for a muse long enough to have them (`Muse.expectedNotes`), on this iphone.
    /// `force` writes them again over notes it has; a muse whose new words are too short for
    /// notes then loses the old ones. Samples never run the model; blank muses get none.
    private func addNotes(to id: UUID, force: Bool) async {
        // Not transcribed: it's being heard again, and its new words queue their own notes.
        guard let muse = store.muse(id: id), muse.origin != .sample, muse.isTranscribed else { return }
        guard let kind = muse.expectedNotes else {
            if force, muse.notes != nil { store.update(id) { $0.notes = nil } }
            return
        }
        guard force || muse.notes == nil else { return }
        // Like titles: only a try made while you're looking counts, so a muse that landed
        // in your pocket gets its notes at the next sweep.
        if Self.isActive { notesTried.insert(id) }
        let words = muse.words
        let notes = await MuseAI.notes(kind, for: words)
        // New words landed while the model wrote: these notes are for the old ones, and
        // the new words queued their own.
        guard let notes, store.muse(id: id)?.words == words else { return }
        store.update(id) { $0.notes = notes }
    }

    /// Notes for recent muses that should have them and don't (they landed while the model
    /// couldn't answer): newest first, a few per sweep, while you're looking.
    private func catchUpNotes(now: Date) {
        guard Self.isActive, MuseAI.isAvailable else { return }
        var longThoughts = 0
        var briefs = 0
        for muse in store.muses where muse.notes == nil && muse.origin != .sample
            && muse.isFresh(within: Self.titleWindow, now: now)
            && !notesTried.contains(muse.id) && !noting.contains(muse.id) && !working.contains(muse.id)
            && !waitsToJoin(muse) {
            switch muse.expectedNotes {
            case .longThought? where longThoughts < Self.longThoughtsPerSweep:
                longThoughts += 1
            case .brief? where briefs < Self.briefsPerSweep:
                briefs += 1
            default:
                continue
            }
            queueNotes(muse.id)
        }
    }

    /// Samples never run the model, but "write the notes again" on one still answers: a
    /// moment of writing, then the same notes.
    private func replayNotes(_ id: UUID) {
        noting.insert(id)
        Task {
            try? await Task.sleep(for: Self.sampleReplay)
            noting.remove(id)
        }
    }

    /// Where a muse goes when its words didn't land.
    private func settle(_ id: UUID, after error: Error) {
        if error is CancellationError {
            store.update(id) { $0.transcriptionState = .pending }
            return
        }
        if let speech = error as? SpeechError {
            // One line for an unreadable file, wherever it was found out.
            let note: String
            if case .unreadableAudio = speech {
                note = Self.unreadableNote
            } else {
                note = (speech.errorDescription ?? Self.unknownNote).museQuiet
            }
            Self.log.info("words didn't land (\(String(describing: speech), privacy: .public)) for \(id, privacy: .public)")
            if speech.isRetryable {
                // Stays pending, with the reason on its card. Tried again in a while if
                // you're still here, and at the next foreground either way.
                store.update(id) { muse in
                    muse.transcriptionState = .pending
                    muse.transcriptionError = note
                }
                scheduleRetry()
            } else {
                fail(id, note)
            }
            return
        }
        Self.log.error("recognizer failed for \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        fail(id, Self.unknownNote)
    }

    /// One try later for muses held back by a passing problem (the speech model not on
    /// this iphone yet and no internet to fetch it): after 30 seconds, then 2 minutes,
    /// then every 10, while museo build is open. `sweep` does the trying.
    private func scheduleRetry() {
        guard !isPreview, retryTask == nil else { return }
        let delay = Self.retryDelays[min(retryStep, Self.retryDelays.count - 1)]
        retryStep += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.retryTask = nil
            guard Self.isActive else { return }
            await self.sweep()
        }
    }

    private func fail(_ id: UUID, _ note: String) {
        store.update(id) { muse in
            muse.transcriptionState = .failed
            muse.transcriptionError = note
        }
    }

    /// Samples carry no audio, so "retry" on one can't hear anything. It still answers the
    /// tap: a moment of transcribing, then the sample goes back to how it was, so the
    /// failed card never has a button that does nothing.
    private func replay(_ sample: Muse) {
        working.insert(sample.id)
        store.update(sample.id) { muse in
            muse.transcriptionState = .transcribing
            muse.transcriptionError = nil
        }
        Task {
            try? await Task.sleep(for: Self.sampleReplay)
            store.update(sample.id) { muse in
                muse.transcriptionState = sample.transcriptionState
                muse.transcriptionError = sample.transcriptionError
            }
            working.remove(sample.id)
        }
    }

    // MARK: - Long recordings

    /// Folds the parts of long memory recordings into one muse (`MuseJoiner`), one pair at a
    /// time, once both have their words and neither is busy (being heard, titled or noted).
    /// Then the whole gets a title (unless theirs) and notes. Runs when a part's words, title
    /// or notes land, and at every sweep. Returns when there's nothing left to join.
    func joinParts() async {
        guard !isPreview else { return }
        guard !isJoining else {
            joinAgain = true
            return
        }
        isJoining = true
        defer { isJoining = false }
        MuseJoiner.sweepStrays()
        repeat {
            joinAgain = false
            var landed: [UUID] = []
            while let pair = MuseJoiner.nextPair(in: store.muses, skipping: joinFailed, isFree: { [self] id in
                !working.contains(id) && !noting.contains(id)
            }) {
                let ids = [pair.earlier.id, pair.later.id]
                // Busy while they join: nothing hears, titles or notes them meanwhile.
                working.formUnion(ids)
                beginBackgroundWork(pair.earlier.id, name: "muse.join")
                let joined = await MuseJoiner.join(pair.earlier, pair.later, in: store)
                endBackgroundWork(pair.earlier.id)
                working.subtract(ids)
                if let joined {
                    if !landed.contains(joined.id) { landed.append(joined.id) }
                } else {
                    // They stay two muses this launch, and each gets what it waited for.
                    joinFailed.insert(pair.later.id)
                    landed.append(contentsOf: ids.filter { !landed.contains($0) })
                }
            }
            for id in landed { await titleAndNotes(id) }
        } while joinAgain
    }

    private func joinPartsSoon(after id: UUID) {
        guard !isPreview, store.muse(id: id)?.ringParts != nil else { return }
        Task { await joinParts() }
    }

    /// A part with its words whose neighbor has words too: the join is coming. A pair whose
    /// join didn't land this launch isn't waiting.
    private func waitsToJoin(_ muse: Muse) -> Bool {
        MuseJoiner.neighbors(of: muse, in: store.muses).contains { pair in
            pair.earlier.isTranscribed && pair.later.isTranscribed && !joinFailed.contains(pair.later.id)
        }
    }

    /// A title (when it has none and the title isn't theirs) and notes, for a muse whose
    /// words just changed under it by a join, unless another join is on its way.
    private func titleAndNotes(_ id: UUID) async {
        guard let muse = store.muse(id: id), muse.isTranscribed, !muse.isBlank, muse.origin != .sample,
              !working.contains(id), !waitsToJoin(muse) else { return }
        if muse.title == nil, !muse.titleIsTheirs {
            working.insert(id)
            await addTitle(to: muse)
            working.remove(id)
        }
        queueNotes(id)
    }

    // MARK: - Backlog

    private func queueBacklog(_ ids: [UUID]) {
        for id in ids where !backlog.contains(id) {
            backlog.append(id)
        }
        guard !isDrainingBacklog, !backlog.isEmpty else { return }
        isDrainingBacklog = true
        Task {
            while !backlog.isEmpty {
                let id = backlog.removeFirst()
                await process(id, lane: .background)
            }
            isDrainingBacklog = false
        }
    }

    /// Holds catch-up while the ring streams, so a streamed muse never waits behind an old one.
    /// Sent in order: a quick tap's pause and resume must never land backwards and hold
    /// the backlog until the next take.
    private func pauseBacklog(_ paused: Bool) {
        let previous = backlogPause
        backlogPause = Task {
            await previous?.value
            await SpeechEngine.shared.setBacklogPaused(paused)
        }
    }

    // MARK: - Helpers

    /// A capture's files, except any a muse holds.
    private func discardFiles(of capture: CompletedCapture) {
        let held = Set(store.muses.flatMap { [$0.audioFileName, $0.sourceFileName].compactMap { $0 } })
        for name in [capture.wavFileName, capture.fileName].compactMap({ $0 }) where !held.contains(name) {
            try? FileManager.default.removeItem(at: MuseFiles.audio.appendingPathComponent(name))
        }
    }

    /// Origins whose words come from audio. Typed muses and samples have none to hear.
    private static func hasAudio(_ origin: MuseOrigin) -> Bool {
        switch origin {
        case .stream, .offline: true
        case .typed, .sample: false
        }
    }

    private static var isActive: Bool {
        UIApplication.shared.applicationState == .active
    }

    /// Background time under `id` (a muse's, or a token of its own for the notes lane).
    private func beginBackgroundWork(_ id: UUID, name: String = "muse.transcribe") {
        guard backgroundTasks[id] == nil else { return }
        let task = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.outOfTime(id)
        }
        if task != .invalid { backgroundTasks[id] = task }
    }

    /// iOS wants its background time back. The words stop where they are and the muse goes
    /// back to pending (a pass frozen halfway would come back as a failure). Catch-up stops
    /// too, rather than start muse after muse with no time left. The next sweep finishes both.
    private func outOfTime(_ id: UUID) {
        listening[id]?.cancel()
        backlog.removeAll()
        endBackgroundWork(id)
    }

    private func endBackgroundWork(_ id: UUID) {
        guard let task = backgroundTasks.removeValue(forKey: id) else { return }
        UIApplication.shared.endBackgroundTask(task)
    }

    /// Reads the header off the main actor.
    @concurrent
    nonisolated private static func isIntact(_ url: URL) async -> Bool {
        AudioCheck.isIntact(url)
    }

    /// Writes the word timings off the main actor.
    @concurrent
    nonisolated private static func saveTimings(_ result: SpeechResult, for id: UUID) async {
        TimedTranscriptStore.save(result, for: id)
    }
}
