import AppKit
import Sparkle

/// New versions of museo, without a new download. Sparkle looks at the appcast on 4ff.com
/// about once a day, and when there is a newer build it offers it, checks it was signed with
/// museo's own key, and swaps the app.
///
/// Only a released build updates itself: `scripts/mac.sh` takes the feed out of a build made
/// here, so a mac you develop on is never swapped for the public one.
@MainActor
enum Updates {
    private static var controller: SPUStandardUpdaterController?

    /// This build knows where its updates come from.
    static var isOn: Bool { Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil }

    /// "0.2": the version in this app's own plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func start() {
        guard isOn, controller == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    /// Looks now, and says so either way.
    static func check() {
        // museo has no dock icon: come forward so Sparkle's window isn't behind everything.
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}
