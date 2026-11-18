import AppKit
import Observation
import Sparkle

/// New versions of museo, without a new download. Sparkle looks at the appcast on 4ff.com
/// about once a day; when there is a newer build it is offered in museo's own words (a line
/// in the panel, a small sheet), checked against museo's own key, and swapped in.
///
/// Only a released build updates itself: `scripts/mac.sh` takes the feed out of a build made
/// here, so a mac you develop on is never swapped for the public one.
@MainActor
enum Updates {
    private static var updater: SPUUpdater?
    private static let driver = UpdateDriver()

    /// This build knows where its updates come from.
    static var isOn: Bool { Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil }

    /// "0.2": the version in this app's own plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func start() {
        guard isOn, updater == nil else { return }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: nil)
        do {
            try updater.start()
            self.updater = updater
        } catch {
            print("[museo][update] the updater didn't start:", error.localizedDescription)
        }
    }

    /// Looks now, and says what it found in the panel's line and the library's settings.
    static func check() {
        // One already on offer: show it, don't look again.
        if UpdateModel.shared.offer != nil {
            LibraryOpener.update()
            return
        }
        updater?.checkForUpdates()
    }

    /// "update" was pressed: bring the offered version in.
    static func install() { driver.install() }
    /// "restart" was pressed: quit, swap, and open again.
    static func restart() { driver.restart() }
}

/// What museo knows about a newer version right now, for the views.
@MainActor
@Observable
final class UpdateModel {
    static let shared = UpdateModel()

    /// A newer museo, and how far along it is. Nil when this is the newest.
    var offer: UpdateOffer?
    /// One quiet line after a check that found nothing or went wrong; gone in a few seconds.
    private(set) var note: String?
    var isChecking = false

    @ObservationIgnored private var clearing: Task<Void, Never>?

    func say(_ line: String) {
        note = line
        clearing?.cancel()
        clearing = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            note = nil
        }
    }
}

/// Sparkle's side of the conversation, answered with museo's own views in place of its
/// standard window. Sparkle calls these on the main thread as an update moves along; the
/// replies it hands over are kept until someone presses "update" or "restart".
@MainActor
final class UpdateDriver: NSObject, SPUUserDriver {
    private let model = UpdateModel.shared
    private var found: ((SPUUserUpdateChoice) -> Void)?
    private var ready: ((SPUUserUpdateChoice) -> Void)?
    private var expected: UInt64 = 0
    private var received: UInt64 = 0

    func install() {
        guard let reply = found else { return }
        found = nil
        model.offer?.stage = .comingDown(0)
        reply(.install)
    }

    func restart() {
        guard let reply = ready else { return }
        ready = nil
        reply(.install)
    }

    // MARK: - Looking

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // museo looks by itself and sends nothing about this mac.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        model.isChecking = true
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        model.isChecking = false
        found = reply
        var offer = UpdateOffer(version: appcastItem.displayVersionString, notes: Self.notes(appcastItem.itemDescription))
        if appcastItem.contentLength > 0 {
            offer.size = String(format: "%.1f mb", Double(appcastItem.contentLength) / 1_000_000)
        }
        // Already here from an earlier look: one press from done.
        if state.stage != .notDownloaded {
            offer.stage = .ready
            ready = reply
            found = nil
        }
        model.offer = offer
        print("[museo][update] \(offer.version) is on offer")
        // Asked for by hand: answer with the sheet. Found on its own: only the panel's line.
        if state.userInitiated { LibraryOpener.update() }
    }

    func showUpdateInFocus() {
        LibraryOpener.update()
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        model.isChecking = false
        model.say("this is the newest museo")
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        model.isChecking = false
        model.offer = nil
        model.say("couldn't look for a newer museo")
        print("[museo][update] error:", error.localizedDescription)
        acknowledgement()
    }

    // MARK: - Bringing it in

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        expected = 0
        received = 0
        model.offer?.stage = .comingDown(0)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expected = expectedContentLength
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        received += length
        guard expected > 0 else { return }
        model.offer?.stage = .comingDown(min(1, Double(received) / Double(expected)))
    }

    func showDownloadDidStartExtractingUpdate() {
        model.offer?.stage = .comingDown(1)
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        ready = reply
        model.offer?.stage = .ready
        print("[museo][update] ready to restart")
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        found = nil
        ready = nil
        model.isChecking = false
        model.offer = nil
    }

    /// The appcast's plain notes as a few short lines.
    private static func notes(_ description: String?) -> [String] {
        guard let description else { return [] }
        let plain = description.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        return plain.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t-•*")) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .map { $0 }
    }
}
