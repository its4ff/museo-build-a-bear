import SwiftUI
import MuseoKit

/// The app's one screen, the home, and everything that opens over it.
///
/// Sheets come from `AppRouter.shared` (so a deep link can open a muse from anywhere): the
/// ring sheet, build, a muse page, the firmware updater. This is also where the shared
/// models enter the environment, so every screen reads them the same way:
///
/// ```swift
/// @Environment(MuseStore.self) private var store      // every muse
/// @Environment(RingModel.self) private var ring       // ring.status
/// @Environment(AppRouter.self) private var router     // router.open(.ring)
/// ```
///
/// The first run (`OnboardingCover`) covers the home until it's been seen through or put
/// off with "later"; build › about opens it again.
///
/// Live app only: lab screens build `HomeView()` with preview models instead.
struct RootView: View {
    @Namespace private var zoom
    /// The onboarding is up. At launch: only on a first run with an empty library.
    @State private var showsOnboarding = Onboarding.isNeeded(hasMuses: !MuseStore.shared.muses.isEmpty)
    /// Asked for again while a sheet was up (build › about): it opens once that sheet is gone.
    @State private var onboardingWaits = false

    var body: some View {
        @Bindable var router = AppRouter.shared
        let actions = RingActions.live(openFirmware: { AppRouter.shared.open(.firmware) })
        HomeView()
            .environment(\.museSyncNow, { Museo.manager?.startOfflineSyncIfNeeded() })
            .environment(\.museSetUpRing, actions.setUp)
            .environment(\.museZoomSpace, zoom)
            .sheet(item: $router.sheet, onDismiss: {
                Museo.firmware.resetIfSettled()
                AppRouter.shared.musePageGone()
                if onboardingWaits {
                    onboardingWaits = false
                    showsOnboarding = true
                    return
                }
                // Anything opened during an update opens now, once you've seen how it went.
                AppRouter.shared.openQueued()
            }) { sheet in
                RootSheet(sheet: sheet, actions: actions, firmware: Museo.firmware, zoom: zoom)
                    .liveRingManager()
            }
            .fullScreenCover(isPresented: $showsOnboarding) {
                OnboardingCover(actions: actions) {
                    Onboarding.isDone = true
                    showsOnboarding = false
                }
            }
            // Outside the sheet, so build › about (inside it) can reach it.
            .environment(\.museShowOnboarding, showOnboardingAgain)
            .environment(\.museLiveWords, LiveWords.shared)
            .environment(MuseStore.shared)
            .environment(RingModel.shared)
            .environment(MusePipeline.shared)
            .environment(AppRouter.shared)
    }

    /// Build › about: close whatever sheet is up, then bring the onboarding back.
    private func showOnboardingAgain() {
        if AppRouter.shared.sheet == nil {
            showsOnboarding = true
        } else {
            onboardingWaits = true
            AppRouter.shared.close()
        }
    }
}

/// One sheet's content. Its own view so it redraws with the ring and the updater while it's
/// up, without redrawing the home.
private struct RootSheet: View {
    let sheet: AppRouter.Sheet
    let actions: RingActions
    @ObservedObject var firmware: RingFirmwareUpdater
    let zoom: Namespace.ID

    @Environment(RingModel.self) private var ring
    @Environment(AppRouter.self) private var router

    var body: some View {
        // The detent goes back to the router, so the home knows how much of it shows.
        @Bindable var router = self.router
        switch sheet {
        case .ring:
            RingSheet(status: ring.status, actions: actions, events: RingSetup.shared.events)
                .presentationDetents([.medium, .large], selection: $router.sheetDetent)
        case .build(let section):
            // The updater too, so build can show it over itself and still be there after.
            BuildView(initialSection: section)
                .environmentObject(firmware)
                .presentationDetents([.large])
        case .muse(let id):
            // Back into the tile of the muse on screen now, which browsing or a delete
            // may have moved off the one it opened on.
            MuseDetailView(id: id)
                .presentationDetents([.large])
                .navigationTransition(.zoom(sourceID: router.museShown ?? id, in: zoom))
        case .howItWorks:
            RingCheatPage(onClose: { router.close() })
                .presentationDetents([.large])
        case .firmware:
            FirmwareSheet(
                firmware: firmware,
                canUpdate: ring.status.isLinked,
                onNeedRing: { router.open(.ring) },
                onClose: { router.close() }
            )
            .presentationDetents([.medium, .large], selection: $router.sheetDetent)
            .interactiveDismissDisabled(firmware.phase.isBusy)
            // While the ring is half written nothing replaces this sheet: a deep link
            // waits in the router until it closes.
            .onChange(of: firmware.phase.isBusy, initial: true) { _, busy in router.hold(busy) }
            .onDisappear { router.hold(false) }
        }
    }
}

extension View {
    /// Hands the ring manager to the dev tools in build (the ring console, clear the ring),
    /// once `Museo.start` has run. Screens read `RingModel.status`, never the manager.
    @ViewBuilder
    func liveRingManager() -> some View {
        if let manager = Museo.manager {
            environmentObject(manager)
        } else {
            self
        }
    }
}
