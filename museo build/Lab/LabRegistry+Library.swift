#if DEBUG
import SwiftUI
import MuseoKit

/// The home: the library of muses, how new ones arrive, search, pills, sort, empty states.
extension LabRegistry {
    // MARK: Home

    static var library: [LabScreen] {
        [
            LabScreen("home.empty", title: "home · empty", note: "no muses yet, no ring set up") {
                libraryStage(LabWorld(muses: [], status: .notSetUp)) { HomeView() }
            },
            LabScreen("home.empty.away", title: "home · empty, ring away", note: "no muses yet, the ring is set up but away") {
                libraryStage(LabWorld(muses: [], status: LabFixtures.away)) { HomeView() }
            },
            LabScreen("home.feed", title: "home · library", note: "the samples on the shelf, by day") {
                libraryStage(LabWorld()) { HomeView(sort: .newest) }
            },
            LabScreen("home.feed.2", title: "home · library, the end", note: "scrolled to \u{201C}that's everything.\u{201D}") {
                libraryStage(LabWorld()) {
                    HomeView(sort: .newest)
                        .labScrolled(LabScroll.end)
                }
            },
            LabScreen("home.full", title: "home · ring nearly full", note: "the status line says so and leads to the ring sheet") {
                libraryStage(LabWorld(status: LabFixtures.nearlyFullAllIn)) { HomeView(sort: .newest) }
            },
            LabScreen("home.streaming", title: "home · streaming", note: "a muse streaming in: the streaming card above the shelf") {
                libraryStage(LabWorld(status: .live)) {
                    HomeView(sort: .newest)
                        .environment(\.museLiveWords, LabFixtures.liveWords)
                }
            },
            LabScreen(
                "home.arriving",
                title: "home · arriving",
                note: "a fresh muse lands as the first tile, its words type in, then its title",
                settle: .seconds(9)
            ) {
                libraryStage(LabWorld()) { LabArrivingHome() }
            },
            LabScreen("home.transcribing", title: "home · transcribing", note: "the newest muse waiting for its words") {
                libraryStage(LabWorld(
                    muses: [LabFixtures.waiting] + LabFixtures.muses,
                    working: [LabFixtures.waitingID],
                    noting: [SampleMuses.cardID]
                )) { HomeView(sort: .newest) }
            },
            LabScreen(
                "home.search",
                title: "home · search",
                note: "\u{201C}window\u{201D}: the closest muses, best first",
                settle: .seconds(2)
            ) {
                libraryStage(LabWorld()) { HomeView(sort: .newest, query: "window") }
            },
            LabScreen("home.filter.memory", title: "home · memory", note: "only the muses kept on the ring and brought in later") {
                libraryStage(LabWorld()) { HomeView(filter: .memory, sort: .newest) }
            },
            LabScreen("home.sort.longest", title: "home · longest", note: "longest first, one run without day rules") {
                libraryStage(LabWorld()) { HomeView(sort: .longest) }
            },
        ]
    }

    /// A home screen on its own world, with the library's clock pinned to the lab's 9:41a so
    /// "3m ago" and "today" read the same whenever the lab runs.
    private static func libraryStage<Content: View>(
        _ world: @autoclosure @escaping () -> LabWorld,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        LabStage(world()) { _ in
            content()
                .environment(\.museLibraryNow, LabFixtures.now)
        }
    }
}
#endif
