import Foundation
import MuseoKit
import Observation

/// The first run, as plain values: which step is up and what the ring has done in it.
///
/// Five beats, each one breath: hello, set up, streaming (hold), memory (double click), the
/// card. Nothing here talks to the ring or the store directly. `OnboardingRingLink` feeds
/// it ring status, ring events and muse events in the live app; lab screens build one in
/// any state with no ring at all:
///
/// ```swift
/// Onboarding(ring: .linked, actions: .preview, step: .stream,
///            stream: .listening(since: .now), drivesItself: false)
/// ```
///
/// It never asks for a permission, never makes an account, and never clears the ring.
/// Every muse made along the way is a real one and stays in the library.
@MainActor
@Observable
final class Onboarding {

    // MARK: - Steps and their states

    nonisolated enum Step: Int, CaseIterable, Sendable {
        case hello, setUp, stream, memory, card
    }

    /// Setting the ring up, read from `RingStatus`.
    nonisolated enum SetUp: Equatable, Sendable {
        /// Nothing in flight: the button to start.
        case ready
        /// iOS's accessory sheet is up.
        case choosing
        case joining
        case linked
        /// Set up before, not in reach yet.
        case away
        case bluetoothOff
        /// Setup ended without a ring, with the kit's note on why.
        case nothing(String)
    }

    /// Holding the ring: a muse streamed straight to this iphone.
    nonisolated enum Stream: Equatable, Sendable {
        case waiting
        case listening(since: Date)
        /// Let go; the muse is a beat away.
        case keeping(since: Date, endedAt: Date)
        /// It arrived. Its words may still be on their way.
        case landed(Muse)
        /// Let go and nothing came: too short to keep.
        case tooShort
        /// Only quiet came through.
        case blank
    }

    /// Double clicking: a muse saved on the ring, brought in after.
    nonisolated enum Memory: Equatable, Sendable {
        case waiting
        case recording(since: Date)
        /// Stopped; coming in from the ring.
        case bringingIn
        case landed(Muse)
        /// A sync ended and nothing new came in.
        case tooShort
        /// A streamed one came in instead.
        case wasStreamed
    }

    private(set) var step: Step
    private(set) var setUp: SetUp
    private(set) var stream: Stream
    private(set) var memory: Memory
    /// The ring as it was last seen.
    private(set) var ring: RingStatus
    /// Something is taking longer than it should (words, a sync): say so, and let them
    /// move on.
    private(set) var isSlow: Bool

    /// When the current step began. Only muses that arrive after it count.
    @ObservationIgnored private(set) var stepStartedAt = Date.now
    /// When the ring was first seen recording to itself in this step.
    @ObservationIgnored private var recordingSince: Date?
    /// When iOS's accessory sheet was last asked for.
    @ObservationIgnored private var askedForSheetAt: Date?

    @ObservationIgnored let actions: RingActions
    /// False in the lab: no timers move a staged state along.
    @ObservationIgnored let drivesItself: Bool
    @ObservationIgnored var onFinish: () -> Void

    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var recordingCheck: Task<Void, Never>?

    // MARK: Timing

    /// "linked." holds this long before the next step.
    static let linkedPause: Duration = .seconds(1)
    /// "streamed in." holds this long once the words are in, then memory comes up.
    static let livePause: Duration = .seconds(1.5)
    /// Let go and nothing arrived this long after: too short.
    static let arrivalWait: Duration = .seconds(3)
    /// The ring reports recording this long before it counts as memory (it reports a
    /// beat of recording during a streaming hold too).
    static let recordingSettle: Duration = .milliseconds(500)
    /// Words or a sync slower than this: say so and offer next.
    static let slowAfter: Duration = .seconds(6)
    /// A muse said this long before the step began still counts (clocks drift).
    static let slack: TimeInterval = 5
    /// Taps this soon after a step appears are ignored. Every step keeps its way forward in
    /// the same spot, so a second tap on the last step's button (or iOS's accessory sheet
    /// taking a beat to come up) would otherwise land on the next one: "set up your ring"
    /// then "skip for now" went straight to the card.
    static let tapSettle: TimeInterval = 0.6

    init(
        ring: RingStatus,
        actions: RingActions,
        step: Step = .hello,
        setUp: SetUp? = nil,
        stream: Stream = .waiting,
        memory: Memory = .waiting,
        isSlow: Bool = false,
        drivesItself: Bool = true,
        onFinish: @escaping () -> Void = {}
    ) {
        self.ring = ring
        self.actions = actions
        self.step = step
        self.setUp = setUp ?? Self.setUp(from: ring)
        self.stream = stream
        self.memory = memory
        self.isSlow = isSlow
        self.drivesItself = drivesItself
        self.onFinish = onFinish
    }

    // MARK: - Remembered

    private static let doneKey = "museo.onboarding.done"

    /// The first run has been seen through (or put off with "later").
    static var isDone: Bool {
        get { UserDefaults.standard.bool(forKey: doneKey) }
        set { UserDefaults.standard.set(newValue, forKey: doneKey) }
    }

    /// Whether to show it at launch. A library that already has muses was set up before
    /// this onboarding existed, so it's marked done instead of shown.
    static func isNeeded(hasMuses: Bool) -> Bool {
        guard !isDone else { return false }
        if hasMuses {
            isDone = true
            return false
        }
        return true
    }

    // MARK: - What the person does

    /// Hello's primary: set the ring up, or straight to streaming when it already is.
    func begin() {
        switch ring.link {
        case .linked:
            go(.stream)
        case .notSetUp:
            go(.setUp)
            setUpRing()
        case .bluetoothOff, .joining, .away:
            go(.setUp)
        }
    }

    /// "set up your ring", "try again", "look for it".
    func setUpRing() {
        switch setUp {
        case .away:
            actions.lookForIt()
        case .ready, .nothing:
            setUp = .choosing
            askedForSheetAt = .now
            actions.setUp()
        case .choosing, .joining, .linked, .bluetoothOff:
            break
        }
    }

    /// The step's way forward: "next", "skip for now".
    func next() {
        guard isSettled else { return }
        switch step {
        case .hello: go(.setUp)
        // Without a linked ring, streaming and memory have nothing to show.
        case .setUp: go(ring.isLinked ? .stream : .card)
        case .stream: go(.memory)
        case .memory: go(.card)
        case .card: finish()
        }
    }

    func later() { finish() }

    func start() {
        guard isSettled else { return }
        finish()
    }

    /// The step has been up long enough that a tap is meant for it.
    private var isSettled: Bool {
        Date.now.timeIntervalSince(stepStartedAt) >= Self.tapSettle
    }

    /// A streamed muse's words finished typing in: hold "streamed in." a moment, then memory.
    func wordsShown() {
        guard drivesItself, step == .stream, case .landed(let muse) = stream,
              muse.isTranscribed, !muse.isBlank else { return }
        after(Self.livePause) { [weak self] in
            guard let self, self.step == .stream else { return }
            self.go(.memory)
        }
    }

    // MARK: - What the ring and the library do

    func ringChanged(_ status: RingStatus) {
        ring = status
        switch step {
        case .setUp:
            followSetUp(status)
        case .stream:
            // Events lead; the status catches a moment an event missed.
            if status.isLive, canStartListening {
                stream = .listening(since: status.liveSince ?? .now)
                cancelTimer()
            } else if !status.isLive, case .listening(let since) = stream {
                letGo(since: since)
            }
        case .memory:
            followRecording(status)
        case .hello, .card:
            break
        }
    }

    func ringEvent(_ event: RingEvent) {
        switch event {
        case .liveStarted(let since):
            guard step == .stream, canStartListening else { return }
            stream = .listening(since: since)
            cancelTimer()
        case .liveEnded:
            if step == .stream, case .listening(let since) = stream {
                letGo(since: since)
            } else if step == .memory, !memoryLanded {
                memory = .wasStreamed
                cancelTimer()
            }
        case .syncStarted:
            guard step == .memory else { return }
            if case .recording = memory { stoppedRecording() }
        case .syncEnded:
            guard step == .memory, memory == .bringingIn else { return }
            after(Self.arrivalWait) { [weak self] in
                guard let self, self.memory == .bringingIn, !self.ring.isSyncing else { return }
                self.memory = .tooShort
            }
        case .syncProgress:
            break
        }
    }

    func museEvent(_ event: MuseEvent) {
        switch event {
        case .arrived(let muse):
            arrived(muse)
        case .transcribed(let muse), .updated(let muse):
            refreshed(muse)
        case .removed(let id):
            if case .landed(let shown) = stream, shown.id == id { stream = .waiting }
            if case .landed(let shown) = memory, shown.id == id { memory = .waiting }
        }
    }

    // MARK: - Steps

    private func go(_ next: Step) {
        cancelTimer()
        recordingCheck?.cancel()
        recordingCheck = nil
        recordingSince = nil
        isSlow = false
        step = next
        stepStartedAt = .now
        switch next {
        case .setUp:
            followSetUp(ring)
        case .stream:
            stream = ring.isLive ? .listening(since: ring.liveSince ?? .now) : .waiting
        case .memory:
            memory = .waiting
            followRecording(ring)
        case .hello, .card:
            break
        }
    }

    private func finish() {
        cancelTimer()
        recordingCheck?.cancel()
        onFinish()
    }

    // MARK: Set up

    private static func setUp(from status: RingStatus) -> SetUp {
        switch status.link {
        case .linked: return .linked
        case .joining: return .joining
        // A ring picked in the sheet is set up before the kit starts linking it, which
        // reads as away for a moment. While the sheet is still up, that's joining.
        case .away: return status.isSettingUp ? .joining : .away
        case .bluetoothOff: return .bluetoothOff
        case .notSetUp:
            if status.isSettingUp { return .choosing }
            if let note = status.setupNote { return .nothing(note) }
            return .ready
        }
    }

    private func followSetUp(_ status: RingStatus) {
        var next = Self.setUp(from: status)
        // Right after "set up your ring" the sheet is still on its way up.
        if setUp == .choosing, next == .ready, let askedForSheetAt, Date.now.timeIntervalSince(askedForSheetAt) < 1 {
            next = .choosing
        }
        guard next != setUp else { return }
        setUp = next
        guard next == .linked, drivesItself else { return }
        MuseHaptics.play(.success)
        after(Self.linkedPause) { [weak self] in
            guard let self, self.step == .setUp, self.setUp == .linked else { return }
            self.go(.stream)
        }
    }

    // MARK: Stream

    /// Listening can start again after a miss, but not over a muse that's in.
    private var canStartListening: Bool {
        switch stream {
        case .waiting, .tooShort, .blank: return true
        case .listening, .keeping, .landed: return false
        }
    }

    private func letGo(since: Date) {
        stream = .keeping(since: since, endedAt: .now)
        // Presses under a second are dropped by the kit: nothing will come.
        after(Self.arrivalWait) { [weak self] in
            guard let self, case .keeping = self.stream else { return }
            self.stream = .tooShort
        }
    }

    // MARK: Memory

    private var memoryLanded: Bool {
        if case .landed = memory { return true }
        return false
    }

    /// Recording to the ring, held for half a second so a streaming hold's blip never counts.
    private func followRecording(_ status: RingStatus) {
        let onRing = status.isRecordingOnRing && !status.isLive
        switch memory {
        case .waiting, .wasStreamed, .tooShort:
            guard onRing else {
                recordingCheck?.cancel()
                recordingCheck = nil
                return
            }
            guard recordingCheck == nil else { return }
            let seen = Date.now
            recordingCheck = Task { [weak self] in
                try? await Task.sleep(for: Self.recordingSettle)
                guard !Task.isCancelled, let self else { return }
                self.recordingCheck = nil
                guard self.ring.isRecordingOnRing, !self.ring.isLive, !self.memoryLanded else { return }
                self.recordingSince = seen
                self.memory = .recording(since: seen)
                self.cancelTimer()
                MuseHaptics.play(.soft)
            }
        case .recording:
            if !status.isRecordingOnRing { stoppedRecording() }
        case .bringingIn, .landed:
            break
        }
    }

    private func stoppedRecording() {
        memory = .bringingIn
        // With auto sync on the kit brings it in by itself a moment later.
        if !ring.autoSync { actions.syncNow() }
        after(Self.slowAfter) { [weak self] in
            guard let self, self.memory == .bringingIn else { return }
            self.isSlow = true
        }
    }

    // MARK: Muses

    private func arrived(_ muse: Muse) {
        guard muse.origin.isRing else { return }
        let said = muse.createdAt.timeIntervalSince(stepStartedAt)
        switch step {
        case .stream:
            guard muse.origin == .stream, said >= -Self.slack, canLand(stream) else { return }
            stream = .landed(muse)
            isSlow = false
            MuseHaptics.play(.received)
            if muse.isTranscribed {
                refreshed(muse)
            } else {
                watchWords()
            }
        case .memory:
            guard !memoryLanded else { return }
            if muse.origin == .stream {
                if said >= -Self.slack {
                    memory = .wasStreamed
                    cancelTimer()
                }
                return
            }
            // Older recordings waiting on the ring come in too; only the new one shows.
            // Said after the step began, or (the ring's clock can drift) said in the last
            // few minutes while this step watched it record.
            let from = (recordingSince ?? stepStartedAt).addingTimeInterval(-30)
            let watched = memory == .bringingIn || recordingSince != nil
            guard muse.createdAt >= from || (watched && muse.createdAt >= Date.now.addingTimeInterval(-600)) else { return }
            memory = .landed(muse)
            isSlow = false
            cancelTimer()
            MuseHaptics.play(.received)
        case .hello, .setUp, .card:
            break
        }
    }

    private func canLand(_ stream: Stream) -> Bool {
        if case .landed = stream { return false }
        return true
    }

    private func refreshed(_ muse: Muse) {
        if step == .stream, case .landed(let shown) = stream, shown.id == muse.id {
            // Only the words arriving clears the slow line and its timer. A title or notes
            // landing later must leave alone the beat `wordsShown` started, or the step
            // never moves on.
            let firstWords = !shown.isTranscribed && muse.isTranscribed
            if muse.isTranscribed, muse.isBlank {
                stream = .blank
                cancelTimer()
            } else {
                stream = .landed(muse)
                if firstWords {
                    isSlow = false
                    cancelTimer()
                }
            }
        }
        // Memory has no timed beat once a muse is in (the person taps next), so a later
        // title only refreshes what shows.
        if step == .memory, case .landed(let shown) = memory, shown.id == muse.id {
            memory = .landed(muse)
        }
    }

    /// Words slower than a few seconds: say they're coming, and let them move on.
    private func watchWords() {
        after(Self.slowAfter) { [weak self] in
            guard let self, case .landed(let muse) = self.stream, !muse.isTranscribed else { return }
            self.isSlow = true
        }
    }

    // MARK: Timer

    /// One pending beat at a time; a newer one replaces it.
    private func after(_ delay: Duration, _ work: @escaping () -> Void) {
        guard drivesItself else { return }
        timer?.cancel()
        timer = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }
}
