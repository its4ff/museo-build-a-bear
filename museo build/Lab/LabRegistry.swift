#if DEBUG
import SwiftUI
import MuseoKit

/// One mock screen. `id` is what `-museLab <id>` asks for; `settle` is how long the screen
/// needs before it's worth a screenshot (an arrival that types in needs a few seconds).
struct LabScreen: Identifiable {
    let id: String
    let title: String
    let note: String
    let settle: Duration
    let make: () -> AnyView

    init<V: View>(
        _ id: String,
        title: String,
        note: String,
        settle: Duration = .milliseconds(900),
        @ViewBuilder view: @escaping () -> V
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.settle = settle
        self.make = { AnyView(view()) }
    }

    /// "home.feed.quiet" belongs to "home"; the index groups by it.
    var group: String { String(id.split(separator: ".").first ?? "") }
}

/// Every lab screen, in the order the index and `scripts/lab.sh shots` show them. Each is
/// a real view fed fixtures (`LabFixtures`) through the environment.
enum LabRegistry {
    /// Each area keeps its screens in its own file: `LabRegistry+Library.swift` (the
    /// home), `LabRegistry+MusePage.swift`, `LabRegistry+Onboarding.swift`; ring, build and
    /// the design kit are below.
    static var all: [LabScreen] {
        library + musePage + onboarding + ring + build + pages
    }

    static func screen(_ id: String) -> LabScreen? {
        all.first { $0.id == id }
    }

    // MARK: Ring

    private static var ring: [LabScreen] {
        [
            LabScreen("ring.glyphs", title: "ring · glyphs", note: "every gauge style, the three ring buttons, every ring status") {
                LabRingGlyphs()
            },
            LabScreen("ring.glyphs.2", title: "ring · glyphs, the end", note: "every ring status in all three styles") {
                LabRingGlyphs()
                    .labScrolled(LabScroll.end)
            },
            LabScreen("ring.sheet.linked", title: "ring sheet · linked", note: "at rest, the medium detent") {
                LabStage(LabWorld(status: .linked)) { world in
                    LabSheet(.medium) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                    }
                }
            },
            LabScreen("ring.sheet.linked.2", title: "ring sheet · linked, the end", note: "pulled up to large, scrolled to the footer") {
                LabStage(LabWorld(status: .linked)) { world in
                    LabSheet(.large) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                            .labScrolled(LabScroll.end)
                    }
                }
            },
            LabScreen("ring.sheet.notsetup", title: "ring sheet · not set up", note: "large, before any ring") {
                LabStage(LabWorld(muses: [], status: .notSetUp)) { world in
                    LabSheet(.large) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview)
                    }
                }
            },
            LabScreen("ring.sheet.syncing", title: "ring sheet · syncing", note: "large, bringing in 3 recordings") {
                LabStage(LabWorld(status: LabFixtures.syncing)) { world in
                    LabSheet(.large) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                    }
                }
            },
            LabScreen("ring.sheet.away", title: "ring sheet · away", note: "large, set up but out of reach since 9:14a") {
                LabStage(LabWorld(status: LabFixtures.away)) { world in
                    LabSheet(.large) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                    }
                }
            },
            LabScreen("ring.sheet.full", title: "ring sheet · nearly full", note: "medium, two recordings waiting: bring them in") {
                LabStage(LabWorld(status: .nearlyFull)) { world in
                    LabSheet(.medium) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                    }
                }
            },
            LabScreen("ring.sheet.full.clear", title: "ring sheet · nearly full, all in", note: "medium, nothing waiting: clear it right here") {
                LabStage(LabWorld(status: LabFixtures.nearlyFullAllIn)) { world in
                    LabSheet(.medium) { HomeView() } content: {
                        RingSheet(status: world.ring.status, actions: .preview, events: LabFixtures.ringEvents)
                    }
                }
            },
            LabScreen("firmware", title: "firmware", note: "ready to update, at rest") {
                LabStage(LabWorld()) { _ in
                    LabSheet(.medium) { HomeView() } content: {
                        FirmwareSheetContent(phase: .idle, canUpdate: true)
                    }
                }
            },
            LabScreen("firmware.sending", title: "firmware · sending", note: "42% of the image on its way, about 24 s left") {
                LabStage(LabWorld()) { _ in
                    LabSheet(.medium) { HomeView() } content: {
                        FirmwareSheetContent(phase: .sending(progress: 0.42), status: "sending firmware", finishAt: .now.addingTimeInterval(24))
                    }
                }
            },
        ]
    }

    // MARK: Build

    private static var build: [LabScreen] {
        [
            buildScreen("build", title: "build", note: "the top: header and speech"),
            buildScreen("build.speech", title: "build · speech", note: "language, engine, studio sound", section: .speech),
            buildScreen("build.ring", title: "build · ring tools", note: "firmware and the console", section: .ring),
            LabScreen("build.3", title: "build · the end", note: "your muses, about, the sign-off") {
                LabStage(LabWorld()) { _ in
                    LabSheet(.large, grabber: false) { HomeView() } content: {
                        BuildView()
                            .labScrolled(LabScroll.end)
                    }
                }
            },
        ]
    }

    private static func buildScreen(
        _ id: String,
        title: String,
        note: String,
        section: BuildSection? = nil
    ) -> LabScreen {
        LabScreen(id, title: title, note: note) {
            LabStage(LabWorld()) { _ in
                LabSheet(.large, grabber: false) { HomeView() } content: {
                    BuildView(initialSection: section)
                }
            }
        }
    }

    // MARK: Pages

    private static var pages: [LabScreen] {
        [
            LabScreen("designkit", title: "design kit", note: "colors and type") {
                designKit(nil)
            },
            LabScreen("designkit.2", title: "design kit · 2", note: "a quarter of the way down") {
                designKit(UnitPoint(x: 0, y: 0.25))
            },
            LabScreen("designkit.3", title: "design kit · 3", note: "halfway down") {
                designKit(UnitPoint(x: 0, y: 0.5))
            },
            LabScreen("designkit.4", title: "design kit · 4", note: "three quarters down") {
                designKit(UnitPoint(x: 0, y: 0.75))
            },
            LabScreen("designkit.5", title: "design kit · the end", note: "orb, ring and ink", settle: .seconds(6)) {
                designKit(LabScroll.end)
            },
        ]
    }

    /// The design kit, a lab-only page: every token and component, each with its name.
    private static func designKit(_ anchor: UnitPoint?) -> some View {
        LabStage(LabWorld()) { _ in
            DesignKitView()
                .labScrolled(anchor)
        }
    }
}
/// Where a scrolled shot starts. Leading on x, so sideways code blocks stay at their start.
enum LabScroll {
    static let end = UnitPoint(x: 0, y: 1)
}

extension View {
    /// Opens every scroll view inside at `anchor`, and keeps it there while lazy rows and
    /// late content settle (so an end shot really shows the end).
    func labScrolled(_ anchor: UnitPoint?) -> some View {
        defaultScrollAnchor(anchor, for: .initialOffset)
            .defaultScrollAnchor(anchor, for: .sizeChanges)
    }
}
#endif
