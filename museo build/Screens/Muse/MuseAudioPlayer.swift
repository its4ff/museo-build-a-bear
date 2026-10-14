import AVFoundation
import Foundation
import Observation

/// Plays one muse's audio on the muse page. Each page owns one:
///
/// ```swift
/// @State private var player = MuseAudioPlayer()
/// …
/// .task(id: muse.audioFileName) { player.load(muse.audioURL, duration: muse.duration) }
/// .onDisappear { player.stop() }
/// ```
///
/// - Levels every recording to the same listening loudness (`Loudness`, measured once off
///   the main actor) through an `AVAudioEngine` graph: player, gain, a peak limiter. Gain
///   can go up as well as down, which `AVAudioPlayer.volume` can't.
/// - Takes the audio session (`.playback`, `.spokenAudio`) when it plays and hands it back
///   with `.notifyOthersOnDeactivation` when it stops or finishes, so music you paused
///   comes back on its own.
/// - Pauses on a call, Siri or headphones coming out. Never resumes on its own.
/// - `elapsed` is read on demand, never published per frame: put a
///   `TimelineView(.animation(paused: !player.isPlaying))` around what follows it.
/// - Studio sound (`choose(.clean)`) swaps in `StudioSound`'s cleaner copy at the same
///   spot. The words and their timings always come from the original.
@MainActor
@Observable
final class MuseAudioPlayer {

    /// Which file you hear: the recording as it is, or studio sound's cleaner copy.
    nonisolated enum Sound: String, CaseIterable, Hashable, Sendable {
        case raw
        case clean
    }

    // MARK: - State you can read

    /// Playing right now. False while paused, at rest and after it finishes.
    private(set) var isPlaying = false
    /// Length in seconds: the muse's own until the file is read, then the file's.
    private(set) var duration: TimeInterval = 0
    /// There is audio to play.
    private(set) var canPlay = false
    /// The file you hear.
    private(set) var sound: Sound = .raw
    /// Studio sound is making its copy ("cleaning…").
    private(set) var isCleaning = false
    /// The gain this recording plays at, in dB (from `Loudness`). 0 until measured.
    private(set) var gainDb: Float = 0

    /// Nothing has played yet, or it finished or stopped: the words show whole.
    var isAtRest: Bool { !engaged }

    /// Seconds into the recording you are hearing now. Read on demand; cheap.
    var elapsed: TimeInterval {
        guard engaged else { return 0 }
        guard isPlaying else { return clamp(pausedAt) }
        if isPreview {
            let run = pausedAt + Date().timeIntervalSince(resumedAt ?? .now)
            return duration > 0 ? run.truncatingRemainder(dividingBy: duration) : 0
        }
        if let rendered = graph?.renderedSeconds() {
            // What the engine has rendered, less the trip to your ears (AirPods add a
            // lot), never before where this stretch started.
            return clamp(max(offset + rendered - heardDelay, pausedAt))
        }
        return clamp(pausedAt + Date().timeIntervalSince(resumedAt ?? .now))
    }

    /// 0...1 through the recording.
    var progress: Double {
        duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
    }

    /// Seconds left.
    var remaining: TimeInterval {
        max(duration - elapsed, 0)
    }

    // MARK: - Position bookkeeping (observed, changes only on play, pause and seek)

    /// A stretch of the file is scheduled: playing or paused.
    private var engaged = false
    /// Where the scheduled stretch starts in the file, seconds.
    private var offset: TimeInterval = 0
    /// Where it paused, or where it resumed from while playing.
    private var pausedAt: TimeInterval = 0
    /// When it last started playing (fallback clock, and the preview's clock).
    private var resumedAt: Date?

    // MARK: - Engine (not observed)

    @ObservationIgnored private var graph: Graph?
    @ObservationIgnored private var file: AVAudioFile?
    @ObservationIgnored private var originalURL: URL?
    @ObservationIgnored private var sourceURL: URL?
    @ObservationIgnored private var requestedSound: Sound = .raw
    /// Changed every time a stretch is scheduled or dropped, so a late completion from an
    /// old stretch can't end the new one.
    @ObservationIgnored private var token = UUID()
    /// The engine stopped under a pause (a call); resume schedules again from `pausedAt`.
    @ObservationIgnored private var needsReschedule = false
    @ObservationIgnored private var sessionIsOurs = false
    @ObservationIgnored private var heardDelay: TimeInterval = 0
    @ObservationIgnored private var measureTask: Task<Void, Never>?
    /// Session observers go in on first play, so making a player (a page's `@State`
    /// initializer runs every time its parent redraws) costs nothing.
    @ObservationIgnored private var isObservingSession = false
    private let observers = NotificationTokens()
    private let isPreview: Bool

    init() {
        isPreview = false
    }

    private init(previewDuration: TimeInterval, elapsed: TimeInterval, playing: Bool) {
        isPreview = true
        duration = previewDuration
        canPlay = previewDuration > 0
        engaged = playing || elapsed > 0
        isPlaying = playing
        pausedAt = elapsed
        resumedAt = playing ? .now : nil
    }

    /// A player with no audio behind it, for lab screens and previews: it keeps time (and
    /// loops) so timed words ink in as if the muse were playing.
    static func preview(duration: TimeInterval, elapsed: TimeInterval = 0, playing: Bool = true) -> MuseAudioPlayer {
        MuseAudioPlayer(previewDuration: duration, elapsed: elapsed, playing: playing)
    }

    // MARK: - Loading

    /// Gets ready to play `url` (nil: nothing to play). `duration` is shown until the file
    /// has been read. Stops whatever was playing.
    func load(_ url: URL?, duration hint: TimeInterval = 0) {
        guard !isPreview else { return }
        guard url != originalURL || !canPlay else { return }
        stop()
        measureTask?.cancel()
        originalURL = url
        sourceURL = url
        sound = .raw
        requestedSound = .raw
        isCleaning = false
        duration = max(hint, 0)
        canPlay = url != nil
        gainDb = 0
        graph?.gain.globalGain = 0
        guard let url else { return }
        measureTask = Task {
            let measured = await Self.inspect(url)
            guard !Task.isCancelled, self.originalURL == url else { return }
            if let seconds = measured.duration, seconds > 0 { self.duration = seconds }
            let gain = Loudness.playbackGainDb(integratedLufs: measured.lufs)
            self.gainDb = gain
            self.graph?.gain.globalGain = gain
        }
    }

    /// Length and loudness, read off the main actor (a few milliseconds a minute).
    @concurrent
    nonisolated private static func inspect(_ url: URL) async -> (duration: TimeInterval?, lufs: Double?) {
        (AudioCheck.duration(url), Loudness.measure(url))
    }

    // MARK: - Playing

    /// Plays from where it paused, or from the start (also after it finished).
    func play() {
        guard canPlay, !isPlaying else { return }
        if engaged {
            resume()
        } else {
            begin(from: 0)
        }
    }

    func pause() {
        guard isPlaying else { return }
        pausedAt = elapsed
        if !isPreview, let graph {
            if graph.engine.isRunning {
                graph.node.pause()
            } else {
                token = UUID()
                graph.node.stop()
                needsReschedule = true
            }
        }
        resumedAt = nil
        isPlaying = false
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    /// Plays from `seconds` into the recording.
    func play(from seconds: TimeInterval) {
        guard canPlay else { return }
        let target = clamp(seconds)
        if isPreview {
            engaged = true
            pausedAt = target
            resumedAt = .now
            isPlaying = true
            return
        }
        if engaged, file != nil, graph?.engine.isRunning == true {
            activateSession()
            schedule(from: target, playing: true)
        } else {
            if engaged { stop(keepingSession: true) }
            begin(from: target)
        }
    }

    /// Moves to `seconds` without changing whether it plays. At rest, it waits there.
    func seek(to seconds: TimeInterval) {
        guard canPlay else { return }
        let target = clamp(seconds)
        if isPlaying {
            play(from: target)
        } else {
            engaged = true
            pausedAt = target
            needsReschedule = true
        }
    }

    /// Moves to `fraction` (0...1) of the recording without changing whether it plays.
    func seek(toFraction fraction: Double) {
        seek(to: min(max(fraction, 0), 1) * duration)
    }

    /// Stops, goes back to rest, and hands the audio session back to other apps.
    func stop() {
        stop(keepingSession: false)
    }

    // MARK: - Studio sound

    /// Switches between the recording and studio sound's cleaner copy, keeping your place.
    /// The first clean copy takes a few seconds (`isCleaning`). Returns a quiet line to
    /// show when the copy couldn't be made; it stays on the original then.
    @discardableResult
    func choose(_ wanted: Sound) async -> String? {
        requestedSound = wanted
        guard let originalURL else { return nil }
        switch wanted {
        case .raw:
            isCleaning = false
            if sound != .raw { swapSource(to: originalURL, as: .raw) }
            return nil
        case .clean:
            guard sound != .clean else { return nil }
            if isPreview {
                sound = .clean
                return nil
            }
            isCleaning = true
            do {
                let copy = try await StudioSound.shared.cleanCopy(of: originalURL)
                guard self.originalURL == originalURL, requestedSound == .clean else { return nil }
                isCleaning = false
                swapSource(to: copy, as: .clean)
                return nil
            } catch {
                guard self.originalURL == originalURL else { return nil }
                isCleaning = false
                // Left the page, or picked raw again while it cleaned: nothing to say.
                if error is CancellationError || Task.isCancelled || requestedSound != .clean { return nil }
                requestedSound = .raw
                let note = (error as? LocalizedError)?.errorDescription
                    ?? "studio sound couldn't clean this one. playing the original."
                return note.museQuiet
            }
        }
    }

    // MARK: - Engine work

    private func begin(from seconds: TimeInterval) {
        guard !isPreview else {
            play(from: seconds)
            return
        }
        guard let sourceURL else { return }
        do {
            activateSession()
            let file = try AVAudioFile(forReading: sourceURL)
            // A header and no frames (an interrupted take): nothing to hear, so say so.
            guard file.length > 0 else {
                canPlay = false
                stop()
                return
            }
            let graph = self.graph ?? Graph()
            self.graph = graph
            graph.gain.globalGain = gainDb
            graph.connect(format: file.processingFormat)
            if !graph.engine.isRunning { try graph.engine.start() }
            self.file = file
            let length = Double(file.length) / max(file.processingFormat.sampleRate, 1)
            if length > 0 { duration = length }
            engaged = true
            schedule(from: seconds >= duration - 0.05 ? 0 : seconds, playing: true)
        } catch {
            print("[muse][player] couldn't play: \(error.localizedDescription)")
            stop()
        }
    }

    private func resume() {
        guard !isPreview else {
            resumedAt = .now
            isPlaying = true
            return
        }
        guard let graph, file != nil else {
            begin(from: pausedAt)
            return
        }
        do {
            activateSession()
            if !graph.engine.isRunning {
                try graph.engine.start()
                needsReschedule = true
            }
            if needsReschedule || pausedAt >= duration - 0.05 {
                schedule(from: pausedAt >= duration - 0.05 ? 0 : pausedAt, playing: true)
            } else {
                graph.node.play()
                resumedAt = .now
                isPlaying = true
            }
        } catch {
            print("[muse][player] couldn't resume: \(error.localizedDescription)")
            stop()
        }
    }

    /// Schedules the file from `seconds` to the end and plays it, or holds it paused.
    private func schedule(from seconds: TimeInterval, playing: Bool) {
        guard let graph, let file else { return }
        let rate = max(file.processingFormat.sampleRate, 1)
        let length = file.length
        let start = AVAudioFramePosition(min(max(seconds, 0) * rate, Double(max(length - 1, 0))))
        let frames = AVAudioFrameCount(max(length - start, 0))
        let token = UUID()
        self.token = token
        graph.node.stop()
        // Nothing to schedule means no completion to end it: back to rest, not "playing".
        guard frames > 0 else {
            stop()
            return
        }
        graph.node.scheduleSegment(
            file,
            startingFrame: start,
            frameCount: frames,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { @Sendable [weak self] _ in
            guard let player = self else { return }
            Task { @MainActor in player.stretchEnded(token) }
        }
        offset = Double(start) / rate
        pausedAt = offset
        needsReschedule = false
        heardDelay = Self.outputDelay()
        if playing {
            graph.node.play()
            resumedAt = .now
            isPlaying = true
        } else {
            resumedAt = nil
            isPlaying = false
        }
    }

    /// The file played to its end.
    private func stretchEnded(_ ended: UUID) {
        guard ended == token else { return }
        stop()
    }

    private func stop(keepingSession: Bool) {
        token = UUID()
        if !isPreview, let graph {
            graph.node.stop()
            if graph.engine.isRunning { graph.engine.stop() }
        }
        file = nil
        engaged = false
        isPlaying = false
        offset = 0
        pausedAt = 0
        resumedAt = nil
        needsReschedule = false
        if !keepingSession { deactivateSession() }
    }

    /// Opens `url` in place of the current file, at the same spot, playing or not.
    private func swapSource(to url: URL, as newSound: Sound) {
        sourceURL = url
        sound = newSound
        guard !isPreview, engaged, let graph else { return }
        let position = elapsed
        let wasPlaying = isPlaying
        do {
            let next = try AVAudioFile(forReading: url)
            if next.processingFormat != file?.processingFormat {
                token = UUID()
                graph.node.stop()
                graph.engine.stop()
                graph.connect(format: next.processingFormat)
                try graph.engine.start()
            }
            file = next
            schedule(from: position, playing: wasPlaying)
        } catch {
            print("[muse][player] couldn't swap: \(error.localizedDescription)")
            sourceURL = originalURL
            sound = .raw
            // The engine went down mid-swap: back to rest rather than "playing" silence.
            if !graph.engine.isRunning { stop() }
        }
    }

    private func clamp(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, 0), max(duration, 0))
    }

    // MARK: - Audio session

    private func activateSession() {
        guard !isPreview else { return }
        observeSessionIfNeeded()
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playback || session.mode != .spokenAudio {
                try session.setCategory(.playback, mode: .spokenAudio)
            }
            try session.setActive(true)
            sessionIsOurs = true
        } catch {
            print("[muse][player] audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateSession() {
        guard sessionIsOurs, !isPreview else { return }
        sessionIsOurs = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[muse][player] audio session: \(error.localizedDescription)")
        }
    }

    /// Render buffer plus the route's own latency: how far behind the engine your ears are.
    private static func outputDelay() -> TimeInterval {
        let session = AVAudioSession.sharedInstance()
        return min(max(session.outputLatency + session.ioBufferDuration, 0), 0.5)
    }

    /// A call, Siri, headphones coming out or the engine being reset: pause as a tap would.
    private func pauseForSessionChange() {
        guard isPlaying else { return }
        pause()
        if graph?.engine.isRunning != true { needsReschedule = true }
    }

    private func observeSessionIfNeeded() {
        guard !isObservingSession else { return }
        isObservingSession = true
        let center = NotificationCenter.default
        observers.add(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began,
                  let self else { return }
            MainActor.assumeIsolated { self.pauseForSessionChange() }
        })
        observers.add(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable,
                  let self else { return }
            MainActor.assumeIsolated { self.pauseForSessionChange() }
        })
        observers.add(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Only this player's engine; it is made on first play, so filter here.
            guard let source = note.object as AnyObject?, let self else { return }
            let changed = ObjectIdentifier(source)
            MainActor.assumeIsolated {
                guard let engine = self.graph?.engine, ObjectIdentifier(engine) == changed else { return }
                self.pauseForSessionChange()
            }
        })
    }
}

// MARK: - Graph

/// player → gain (the loudness level) → peak limiter → mixer. Made on first play, so
/// opening a page costs nothing until you listen.
@MainActor
private final class Graph {
    let engine = AVAudioEngine()
    let node = AVAudioPlayerNode()
    let gain = AVAudioUnitEQ(numberOfBands: 0)
    let limiter: AVAudioUnitEffect
    private var format: AVAudioFormat?

    init() {
        var description = AudioComponentDescription()
        description.componentType = kAudioUnitType_Effect
        description.componentSubType = kAudioUnitSubType_PeakLimiter
        description.componentManufacturer = kAudioUnitManufacturer_Apple
        limiter = AVAudioUnitEffect(audioComponentDescription: description)
        engine.attach(node)
        engine.attach(gain)
        engine.attach(limiter)
    }

    func connect(format: AVAudioFormat) {
        guard format != self.format else { return }
        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(gain)
        engine.disconnectNodeOutput(limiter)
        engine.connect(node, to: gain, format: format)
        engine.connect(gain, to: limiter, format: format)
        engine.connect(limiter, to: engine.mainMixerNode, format: format)
        self.format = format
    }

    /// Seconds the player has rendered since its stretch started, or nil when it isn't
    /// playing (paused, stopped, the engine down).
    func renderedSeconds() -> TimeInterval? {
        guard engine.isRunning,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime),
              playerTime.sampleRate > 0
        else { return nil }
        return max(Double(playerTime.sampleTime) / playerTime.sampleRate, 0)
    }
}

/// Holds notification observers and removes them when the player goes.
nonisolated private final class NotificationTokens: @unchecked Sendable {
    private var tokens: [NSObjectProtocol] = []
    private let lock = NSLock()

    func add(_ token: NSObjectProtocol) {
        lock.withLock { tokens.append(token) }
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }
}
