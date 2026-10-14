import Foundation
import MuseoKit
import UIKit

/// Starts every part of the app, in order. One place, so it is easy to read what runs.
@MainActor
enum AppStart {
    /// Called once at launch (from the app delegate, before any screen).
    static func start() {
        // Muses saved before a restart can't be read until the iphone is first unlocked
        // (the ring can wake the app before that). Read them the moment it unlocks.
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { MuseStore.shared.reloadIfNeeded() }
        }
        // Speech usage counts carry no device details.
        SpeechEngine.keepUsageAnonymous()
        // Deleting a muse deletes its word timings.
        TimedTranscriptStore.installCleanup()
        // Your hooks, before the first muse can arrive, so they see every one.
        YourCode.install()
        // The ring: bluetooth, setup with iOS's accessory sheet, status, firmware (MuseoKit).
        Museo.start(name: AppConfig.ringName, clearsRingAfterSync: AppConfig.clearsRingAfterSyncByDefault)
        // Finished recordings become muses, then words and a title.
        MusePipeline.shared.attach()
        // Listening and syncing on the lock screen and the dynamic island.
        MuseLiveActivityController.shared.attach()
        // The paper grain is drawn off the main thread before the first frame needs it.
        MuseGrain.warm()
        // The on-device model loads ahead of the first title.
        MuseAI.prewarm()
        // The speech model for this iphone's language downloads and stays put.
        Task { await SpeechEngine.shared.prepareAssets() }
        // Muses the last run left without words or a title.
        Task { await MusePipeline.shared.sweep() }
        // Exports and shared audio copies left in the temporary folder by the last run.
        Task.detached(priority: .background) { MuseExport.removeExports() }
    }

    /// Called every time the app comes to the foreground.
    /// (`RingSetup` reconciles AccessorySetupKit on its own when the app becomes active.)
    static func becameActive() {
        // muses.json couldn't be read at launch: try again now.
        MuseStore.shared.reloadIfNeeded()
        // A capture that started while the app was away shows on the lock screen now.
        MuseLiveActivityController.shared.reconcile()
        // Catch up: recordings still waiting, words, retries, titles.
        Task { await MusePipeline.shared.sweep() }
        // Words while you hold the ring, on screen as you speak.
        LiveWords.shared.listen()
    }

    /// Called when the app goes to the background.
    static func wentToBackground() {
        // Saves reach the disk now, not a moment later: iOS may end the app while it's away.
        MuseStore.shared.flush()
        // Tries waiting on the speech model pause; coming back sweeps anyway.
        MusePipeline.shared.enteredBackground()
        // Nobody is looking: no words while you hold. The recording still comes in.
        LiveWords.shared.stop()
    }
}
