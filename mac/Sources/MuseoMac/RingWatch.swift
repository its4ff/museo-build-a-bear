import AppKit
import Foundation
import MuseoKit
import Observation

/// What the menu bar needs to know about the ring beyond its status: when a memory recording
/// started (for the timer), which app was in front then (for the fresh rule), and a short
/// tick after words are typed.
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

    /// The last memory recording that ended on this mac: when, and which app was in front
    /// when it began. `MacLibrary` takes it once, for the next recording that comes over.
    @ObservationIgnored private(set) var lastRecording: (stopped: Date, app: String?)?

    @ObservationIgnored private var appAtStart: String?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var flashing: Task<Void, Never>?

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

    /// Hands over the last recording's details once.
    func takeLastRecording() -> (stopped: Date, app: String?)? {
        defer { lastRecording = nil }
        return lastRecording
    }

    // MARK: - Following the ring

    private func follow() {
        withObservationTracking {
            _ = RingModel.shared.status.isRecordingOnRing
        } onChange: {
            Task { @MainActor in
                RingWatch.shared.recordingChanged()
                RingWatch.shared.follow()
            }
        }
    }

    private func recordingChanged() {
        let recording = RingModel.shared.status.isRecordingOnRing && !RingModel.shared.status.isLive
        if recording, recordingSince == nil {
            recordingSince = .now
            now = .now
            appAtStart = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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
            lastRecording = (.now, appAtStart)
            appAtStart = nil
        }
    }
}
