import AppKit
import Foundation
import MuseoKit
import Observation

/// What the menu bar needs to know about the ring beyond its status: when a memory recording
/// started (for the timer), and a short tick after words are typed.
@MainActor
@Observable
final class RingWatch {
    static let shared = RingWatch()

    /// A memory recording is going (double click): when it started.
    private(set) var recordingSince: Date?
    /// Ticks each second while a memory recording runs, so the timer redraws.
    private(set) var now = Date()
    /// True for a moment after words are typed.
    private(set) var typedFlash = false
    /// The ring was forgotten here, and nothing has linked since. macOS keeps its own pairing
    /// (the ring is also its media keys), so the panel points to system settings to unpair.
    private(set) var forgotRing = UserDefaults.standard.bool(forKey: RingWatch.forgotKey)

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var flashing: Task<Void, Never>?
    @ObservationIgnored private var listing: Task<Void, Never>?
    @ObservationIgnored private var wasLinked = false

    func start() {
        follow()
    }

    /// The tick on the ring after a hold's words land.
    func flashTyped() {
        typedFlash = true
        flashing?.cancel()
        flashing = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            typedFlash = false
        }
    }

    /// Reads what's on the ring in a moment (battery, storage and its file list), so the
    /// panel's row can say what's there. Only a list: on a mac nothing comes over unless you
    /// click "bring in", since a transfer ties up the ring and a hold would wait behind it.
    func listSoon(after seconds: Double = 2.5) {
        listing?.cancel()
        listing = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            let status = RingModel.shared.status
            guard status.isLinked, !status.isSyncing, !status.isLive, !status.isRecordingOnRing else { return }
            RingActions.live(openFirmware: {}).refresh()
        }
    }

    // MARK: - Following the ring

    private func follow() {
        withObservationTracking {
            _ = RingModel.shared.status.isRecordingOnRing
            _ = RingModel.shared.status.link
        } onChange: {
            Task { @MainActor in
                RingWatch.shared.recordingChanged()
                RingWatch.shared.linkChanged()
                RingWatch.shared.follow()
            }
        }
    }

    /// "forget this ring": museo lets go, and remembers to say how to unpair it from the mac.
    func forget() {
        RingActions.live(openFirmware: {}).remove()
        setForgot(true)
    }

    /// Setting a ring up again: the note has done its job.
    func setUp() {
        setForgot(false)
        RingActions.live(openFirmware: {}).setUp()
    }

    private func setForgot(_ forgot: Bool) {
        forgotRing = forgot
        UserDefaults.standard.set(forgot, forKey: Self.forgotKey)
    }

    private static let forgotKey = "museo.mac.forgotRing"

    private func linkChanged() {
        let linked = RingModel.shared.status.isLinked
        if linked, forgotRing { setForgot(false) }
        if linked, !wasLinked { listSoon(after: 4) }
        wasLinked = linked
    }

    private func recordingChanged() {
        let recording = RingModel.shared.status.isRecordingOnRing && !RingModel.shared.status.isLive
        if recording, recordingSince == nil {
            recordingSince = .now
            now = .now
            ticker = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    now = .now
                }
            }
        } else if !recording, recordingSince != nil {
            ticker?.cancel()
            ticker = nil
            recordingSince = nil
        }
    }
}
