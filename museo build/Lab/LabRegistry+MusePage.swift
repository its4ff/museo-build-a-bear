#if DEBUG
import SwiftUI
import MuseoKit

/// One muse's page: a short muse, brief notes, a long thought, playing, the notes being
/// written, the title being edited, and the waiting and failed states.
extension LabRegistry {
    // MARK: Muse page

    static var musePage: [LabScreen] {
        let window = SampleMuses.windowID
        let card = SampleMuses.cardID
        let market = SampleMuses.marketID
        return [
            LabScreen("muse.page", title: "muse page", note: "a titled ring muse at rest, its words open") {
                musePageStage(window)
            },
            LabScreen("muse.page.2", title: "muse page · for builders", note: "scrolled to the details your code sees") {
                musePageStage(window, opensDetails: true, scrolled: true)
            },
            LabScreen("muse.page.brief", title: "muse page · brief", note: "about 180 words: notes on top, the words folded under them") {
                musePageStage(card)
            },
            LabScreen("muse.page.long", title: "muse page · long thought", note: "the full write-up: the thought, threads, moments, to do") {
                musePageStage(market)
            },
            LabScreen("muse.page.long.2", title: "muse page · long thought, the end", note: "the folded words, copy and share, the actions") {
                musePageStage(market, scrolled: true)
            },
            LabScreen("muse.page.playing", title: "muse page · playing", note: "the words ink in as it plays, about a third in") {
                let duration = musePageMuse(window)?.duration ?? 41
                return LabStage(musePageWorld()) { _ in
                    LabSheet(.large, grabber: false) { HomeView() } content: {
                        MuseDetailView(
                            id: window,
                            player: .preview(duration: duration, elapsed: 13, playing: true),
                            timings: TimedWordsView.sampleTimings(for: musePageMuse(window)?.words ?? "", duration: duration)
                        )
                    }
                }
            },
            LabScreen("muse.page.writing", title: "muse page · writing the notes", note: "a long muse whose write-up is on its way") {
                let muses = musePageMuses.map { muse in
                    var muse = muse
                    if muse.id == market { muse.notes = nil }
                    return muse
                }
                return musePageStage(market, world: musePageWorld(muses, noting: [market]))
            },
            LabScreen("muse.page.edit", title: "muse page · editing the title", note: "the title open in place, keep as is or save") {
                musePageStage(window, editsTitle: true)
            },
            LabScreen("muse.page.transcribing", title: "muse page · transcribing", note: "waiting for its words") {
                musePageStage(
                    LabFixtures.waitingID,
                    world: musePageWorld([LabFixtures.waiting] + musePageMuses, working: [LabFixtures.waitingID])
                )
            },
            LabScreen("muse.page.failed", title: "muse page · failed", note: "couldn't be read: the voice is kept, retry") {
                musePageStage(SampleMuses.failedID)
            },
            LabScreen("muse.page.untitled", title: "muse page · untitled", note: "a short muse without a title: the words are the hero") {
                musePageStage(SampleMuses.reminderID)
            },
            LabScreen("muse.page.blank", title: "muse page · blank", note: "nothing in it sounded like words") {
                musePageStage(SampleMuses.blankID)
            },
        ]
    }

    // MARK: Staging

    /// The page over the home, its player standing in for the audio.
    private static func musePageStage(
        _ id: UUID,
        world: @autoclosure () -> LabWorld = musePageWorld(),
        editsTitle: Bool = false,
        opensDetails: Bool = false,
        scrolled: Bool = false
    ) -> some View {
        let duration = musePageMuse(id)?.duration ?? LabFixtures.waiting.duration
        return LabStage(world()) { _ in
            LabSheet(.large, grabber: false) { HomeView() } content: {
                MuseDetailView(
                    id: id,
                    player: .preview(duration: duration, playing: false),
                    editsTitle: editsTitle,
                    opensDetails: opensDetails
                )
                .labScrolled(scrolled ? LabScroll.end : nil)
            }
        }
    }

    /// The usual samples, every one in the page's pool so the chevrons can browse.
    private static func musePageWorld(
        _ muses: [Muse]? = nil,
        working: Set<UUID> = [],
        noting: Set<UUID> = []
    ) -> LabWorld {
        let muses = muses ?? musePageMuses
        let world = LabWorld(muses: muses, working: working, noting: noting)
        world.router.musePool = muses.map(\.id)
        return world
    }

    /// The fixtures as the page shows them: the two muses with notes came from the ring too
    /// (the brief streamed, the long thought from memory), and every engine reads as apple's.
    private static var musePageMuses: [Muse] {
        LabFixtures.muses.map { muse in
            var muse = muse
            if muse.id == SampleMuses.cardID { muse.origin = .stream }
            if muse.id == SampleMuses.marketID { muse.origin = .offline }
            if muse.textModel == "sample" { muse.textModel = "apple-speech" }
            return muse
        }
    }

    private static func musePageMuse(_ id: UUID) -> Muse? {
        musePageMuses.first { $0.id == id }
    }
}
#endif
