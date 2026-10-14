import Foundation
import Observation
import SwiftUI

/// What's on screen above the home. One sheet at a time.
///
/// Any view can open something: `@Environment(AppRouter.self) var router` then
/// `router.open(.ring)`. `RootView` presents it.
@MainActor
@Observable
final class AppRouter {
    /// The live app's router. Deep links open sheets through it.
    /// Lab screens and previews make their own with `AppRouter()`.
    static let shared = AppRouter()

    enum Sheet: Identifiable, Equatable {
        /// The ring sheet: battery, setup, storage, firmware.
        case ring
        /// The build page, optionally scrolled to a section.
        case build(BuildSection? = nil)
        /// One muse.
        case muse(UUID)
        /// The firmware updater.
        case firmware
        /// How museo works: the cheat card.
        case howItWorks

        var id: String {
            switch self {
            case .ring: "ring"
            case .build(let section): "build.\(section?.rawValue ?? "top")"
            case .muse(let id): "muse.\(id.uuidString)"
            case .firmware: "firmware"
            case .howItWorks: "how"
            }
        }
    }

    var sheet: Sheet?
    /// How tall the sheet is right now. `RootView` binds the ring and firmware sheets'
    /// detents to it; at `.medium` the top of the home still shows above them.
    var sheetDetent: PresentationDetent = .large

    /// Set while the firmware updater writes to the ring (`RootView` holds it). Anything
    /// opened meanwhile waits in `queued` instead of covering the update, and opens once
    /// the firmware sheet closes (`openQueued()`).
    @ObservationIgnored private(set) var isHeld = false
    @ObservationIgnored private var queued: Sheet?

    /// The muses the muse page can swipe through, in the order they were on screen when
    /// one was opened (`open(muse:among:)`). Empty: just that one.
    var musePool: [UUID] = []

    /// The muse the muse page shows right now, which moves off the one it opened on as
    /// they browse or delete. `MuseDetailView` sets it; `RootView` zooms the page back
    /// into this muse's tile. Nil once the page is gone.
    var museShown: UUID?

    /// Opens one muse with its neighbors, so the muse page can go to the newer or older one
    /// without closing: `router.open(muse: muse.id, among: shown.map(\.id))`.
    func open(muse id: UUID, among pool: [UUID]) {
        open(.muse(id))
        musePool = pool
    }

    func open(_ newSheet: Sheet) {
        guard newSheet != sheet else { return }
        if isHeld, sheet == .firmware {
            queued = newSheet
            return
        }
        // Something newer opened: whatever waited is no longer what you asked for.
        queued = nil
        // A muse opened on its own (a deep link) browses nothing; `open(muse:among:)` sets
        // the pool right after this.
        musePool = []
        // The page zooms from the tile it opens on until it says otherwise.
        if case .muse(let id) = newSheet {
            museShown = id
        } else {
            museShown = nil
        }
        sheetDetent = Self.startingDetent(for: newSheet)
        sheet = newSheet
    }

    func close() {
        guard !(isHeld && sheet == .firmware) else { return }
        sheet = nil
        sheetDetent = .large
    }

    /// Holds the firmware sheet in front while an update runs, or lets it go.
    func hold(_ held: Bool) {
        isHeld = held
    }

    /// Once the muse page has finished closing: forget which muse it showed. Not in
    /// `close()`, because the page is still zooming back into that tile then.
    func musePageGone() {
        guard sheet == nil else { return }
        museShown = nil
    }

    /// After a sheet closes: opens what waited while the firmware sheet was held, if
    /// nothing else opened since.
    func openQueued() {
        guard sheet == nil, let next = queued else { return }
        queued = nil
        open(next)
    }

    /// The ring and firmware sheets open at half height; the rest open full.
    private static func startingDetent(for sheet: Sheet) -> PresentationDetent {
        switch sheet {
        case .ring, .firmware: .medium
        case .build, .muse, .howItWorks: .large
        }
    }
}

/// The sections of the build page, in order. `router.open(.build(.ring))` opens build there.
nonisolated enum BuildSection: String, CaseIterable, Identifiable, Sendable {
    case speech
    case ring
    case muses
    case about

    var id: String { rawValue }

    /// Section label, lowercase.
    var title: String {
        switch self {
        case .speech: "speech"
        case .ring: "ring"
        case .muses: "your muses"
        case .about: "about"
        }
    }
}
