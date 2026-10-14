import ActivityKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import MuseoKit

/// Capture and sync on the lock screen. Starts locally when the app is visible.
/// Backgrounded starts throw `.visibility` and are skipped; BLE still runs.
/// If a capture or sync began while the app was in the background, its activity
/// appears the next time the app comes to the front.
///
/// It listens to the ring like anything else in the app (`Museo.onEvent`).
final class MuseLiveActivityController {
    static let shared = MuseLiveActivityController()

    /// Once, at launch, after `Museo.start`.
    func attach() {
        guard let ble = Museo.manager, self.ble == nil else { return }
        self.ble = ble
        Museo.onEvent { event in
            let controller = MuseLiveActivityController.shared
            switch event {
            case .liveStarted(let at): controller.captureChanged(true, startedAt: at)
            case .liveEnded: controller.captureChanged(false, startedAt: nil)
            case .syncStarted(let count): controller.syncStarted(total: count)
            case .syncProgress(let remaining): controller.syncProgress(remaining: remaining)
            case .syncEnded: controller.syncEnded()
            }
        }

        // A fresh launch can't be mid-capture or mid-sync yet, so anything still on
        // the lock screen belongs to a run that ended without saying so.
        if !ble.isCapturing, capture == nil {
            for activity in Activity<MuseCaptureActivityAttributes>.activities {
                end(activity, nil, after: nil)
            }
        }
        if !ble.isSyncingOffline, sync == nil {
            for activity in Activity<MuseSyncActivityAttributes>.activities {
                end(activity, nil, after: nil)
            }
        }
        observeForeground()
    }

    /// Read only for the sync's error line, so a run with a failed file doesn't claim "all in".
    private weak var ble: RingBLEManager?

    private var capture: Activity<MuseCaptureActivityAttributes>?
    private var sync: Activity<MuseSyncActivityAttributes>?

    /// Activities we've asked to end. Ending is async, so for a moment they still look
    /// live; they must never be picked up again as the current capture or sync.
    private var retired: Set<String> = []

    // What the ring last told us, kept even when no activity could start.
    private var isCapturing = false
    private var captureStartedAt: Date?
    private var isSyncing = false
    private var syncTotal = 0
    private var syncRemaining = 0
    /// The ring zeroed its queue while still syncing: it stopped early (link lost, aborted).
    /// A sync that finishes stops first and never reports zero.
    private var syncStoppedEarly = false

    private var foregroundObserver: (any NSObjectProtocol)?

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    private var appVisible: Bool {
        #if canImport(UIKit)
        return UIApplication.shared.applicationState != .background
        #else
        return true
        #endif
    }

    // MARK: Capture

    func captureChanged(_ isCapturing: Bool, startedAt: Date?) {
        self.isCapturing = isCapturing
        if isCapturing {
            if captureStartedAt == nil || startedAt != nil {
                captureStartedAt = startedAt ?? Date()
            }
            guard enabled, capture == nil else { return }
            guard appVisible else { return }
            do {
                capture = try Activity.request(
                    attributes: MuseCaptureActivityAttributes(startedAt: captureStartedAt ?? Date()),
                    content: ActivityContent(state: MuseCaptureActivityAttributes.ContentState(), staleDate: nil)
                )
            } catch {
                capture = nil
                print("[muse][la] capture activity failed: \(error.localizedDescription)")
            }
        } else {
            captureStartedAt = nil
            let activity = capture ?? adoptable(Activity<MuseCaptureActivityAttributes>.activities)
            capture = nil
            guard let activity else { return }
            end(activity, nil, after: 4)
        }
    }

    /// Opening the app mid-capture puts the activity on the lock screen from there.
    /// `AppStart.becameActive` calls it; safe to call again.
    func reconcile() {
        guard let ble else { return }
        reconcileCapture(isCapturing: ble.isCapturing, startedAt: ble.activeCaptureStartedAt)
    }

    private func reconcileCapture(isCapturing: Bool, startedAt: Date?) {
        if capture == nil, let existing = adoptable(Activity<MuseCaptureActivityAttributes>.activities) {
            capture = existing
        }
        if isCapturing {
            captureChanged(true, startedAt: startedAt)
        } else if capture != nil {
            captureChanged(false, startedAt: nil)
        }
    }

    // MARK: Sync

    func syncStarted(total: Int) {
        isSyncing = true
        syncStoppedEarly = false
        syncTotal = max(total, 1)
        syncRemaining = syncTotal
        startSyncActivity()
    }

    func syncProgress(remaining: Int) {
        guard isSyncing else { return }
        guard remaining > 0 else {
            syncStoppedEarly = true
            return
        }
        syncRemaining = remaining
        syncTotal = max(syncTotal, remaining)
        guard let sync, sync.isLive else { return }
        let state = syncState
        guard state != sync.content.state else { return }
        Task { await sync.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func syncEnded() {
        // A file that came in partly or couldn't be saved sets the ring's sync error
        // and the queue carries on, so a clean finish also needs no error.
        let finished = isSyncing && !syncStoppedEarly && ble?.offlineSyncError == nil
        isSyncing = false
        let activity = sync ?? adoptable(Activity<MuseSyncActivityAttributes>.activities)
        sync = nil
        guard let activity else { return }
        if finished {
            // The ring stops before it reports its last recording, so say "all in" here.
            let done = MuseSyncActivityAttributes.ContentState(done: syncTotal, total: syncTotal)
            end(activity, ActivityContent(state: done, staleDate: nil), after: 6)
        } else {
            // Stopped early or a file didn't make it: the ring sheet explains;
            // the lock screen just lets go.
            end(activity, nil, after: nil)
        }
    }

    /// `done` counts recordings fully in; the widget reads `done + 1` as the one coming in.
    private var syncState: MuseSyncActivityAttributes.ContentState {
        MuseSyncActivityAttributes.ContentState(done: max(syncTotal - syncRemaining, 0), total: syncTotal)
    }

    private func startSyncActivity() {
        guard enabled, sync == nil, syncTotal > 0 else { return }
        if let existing = adoptable(Activity<MuseSyncActivityAttributes>.activities) {
            sync = existing
            let state = syncState
            Task { await existing.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        guard appVisible else { return }
        do {
            sync = try Activity.request(
                attributes: MuseSyncActivityAttributes(startedAt: Date()),
                content: ActivityContent(state: syncState, staleDate: nil)
            )
        } catch {
            sync = nil
            print("[muse][la] sync activity failed: \(error.localizedDescription)")
        }
    }

    // MARK: Foreground

    private func observeForeground() {
        #if canImport(UIKit)
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                MuseLiveActivityController.shared.becameActive()
            }
        }
        #endif
    }

    private func becameActive() {
        reconcileCapture(isCapturing: isCapturing, startedAt: captureStartedAt)
        if isSyncing, sync == nil {
            startSyncActivity()
        }
    }

    // MARK: Ending

    /// A live activity of ours that isn't already on its way out.
    private func adoptable<A: ActivityAttributes>(_ activities: [Activity<A>]) -> Activity<A>? {
        activities.first { $0.isLive && !retired.contains($0.id) }
    }

    /// Ends `activity` once: after `delay` seconds on screen, or right away when nil.
    private func end<A: ActivityAttributes>(
        _ activity: Activity<A>,
        _ content: ActivityContent<A.ContentState>?,
        after delay: TimeInterval?
    ) {
        guard retired.insert(activity.id).inserted else { return }
        let policy: ActivityUIDismissalPolicy = delay.map { .after(Date().addingTimeInterval($0)) } ?? .immediate
        Task { await activity.end(content, dismissalPolicy: policy) }
    }
}

private extension Activity {
    var isLive: Bool { activityState == .active || activityState == .stale }
}
