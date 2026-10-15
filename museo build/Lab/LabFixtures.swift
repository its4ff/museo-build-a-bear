#if DEBUG
import SwiftUI
import MuseoKit

/// Everything the lab screens show, the same on every run.
///
/// Clock times ("9:38a") and day headers ("today") hang off `now`, 9:41a today, which
/// matches the simulator's status bar override. Things a screen shows relative to the real
/// clock ("2m ago", whether a muse is fresh enough to type in) hang off `launched`, so they
/// read the same whatever time the lab runs.
@MainActor
enum LabFixtures {
    /// The wall clock when this lab screen launched.
    static let launched = Date.now

    /// The lab's clock: 9:41a today.
    static let now: Date = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: launched) ?? launched

    /// A lab-clock time moved onto the real clock, keeping its distance from 9:41a. For
    /// anything a screen shows relatively.
    static func real(_ labTime: Date) -> Date {
        launched.addingTimeInterval(labTime.timeIntervalSince(now))
    }

    // MARK: - Muses

    /// Where each sample came from. The samples are `.sample`; the lab shows them as the
    /// ring would, so the library's pills each find something: five streamed and four from the
    /// ring's memory (the long walk home among them).
    private static let origins: [UUID: MuseOrigin] = [
        SampleMuses.reminderID: .stream,
        SampleMuses.windowID: .stream,
        SampleMuses.bakeryID: .offline,
        SampleMuses.blankID: .stream,
        SampleMuses.callID: .stream,
        SampleMuses.cardID: .stream,
        SampleMuses.marketID: .offline,
        SampleMuses.failedID: .offline,
        SampleMuses.kettleID: .offline,
    ]

    /// The nine samples around 9:41a today, settled: nothing types in. The bakery muse
    /// came in from the ring's memory four minutes ago, so it carries the ochre dot.
    static var muses: [Muse] {
        SampleMuses.make(now: now).map { sample in
            var muse = sample
            muse.origin = origins[muse.id] ?? muse.origin
            if muse.id == SampleMuses.bakeryID {
                muse.arrivedAt = launched.addingTimeInterval(-4 * 60)
            } else {
                muse.arrivedAt = min(muse.arrivedAt, launched.addingTimeInterval(-15 * 60))
            }
            return muse
        }
    }

    static func muse(_ id: UUID) -> Muse? {
        muses.first { $0.id == id }
    }

    /// The muse that arrives on `home.arriving`, said twenty seconds before 9:41a.
    static let arrivingID = UUID(uuidString: "6D757365-0000-4000-8000-0000000000A1") ?? UUID()
    /// Words forming while the ring streams: settled, then still settling.
    static var liveWords: LiveWords {
        LiveWords.preview(heard: "the light on the canal at six is", hearing: "the green we want for")
    }

    static let arrivingWords = "the light on the canal at six is the green we want for the box. take a photo of it tomorrow, same spot by the lock."
    static let arrivingTitle = "the green for the box"

    static func arriving(state: TranscriptionState) -> Muse {
        let said = now.addingTimeInterval(-20)
        let done = state == .complete
        return Muse(
            id: arrivingID,
            createdAt: said,
            duration: 9,
            origin: .stream,
            transcript: done ? arrivingWords : nil,
            transcriptionState: state,
            language: done ? "en" : nil,
            wordConfidence: done ? 0.93 : nil,
            textModel: done ? "apple-speech" : nil,
            arrivedAt: .now
        )
    }

    /// A muse still waiting for its words, at the top of the feed.
    static let waitingID = UUID(uuidString: "6D757365-0000-4000-8000-0000000000A2") ?? UUID()

    static var waiting: Muse {
        Muse(
            id: waitingID,
            createdAt: now.addingTimeInterval(-40),
            duration: 26,
            origin: .stream,
            transcriptionState: .transcribing,
            arrivedAt: launched.addingTimeInterval(-6)
        )
    }

    // MARK: - Ring

    /// The ring sheet's setup log (debug builds show it collapsed).
    static let ringEvents = [
        "09:12:03.114 picker shown",
        "09:12:09.870 accessory added · museo",
        "09:12:11.402 linked · Museo_47cf",
    ]

    /// Away since 9:14a.
    static var away: RingStatus {
        var status = RingStatus.away
        status.batteryReadAt = now.addingTimeInterval(-27 * 60)
        return status
    }

    /// Nearly full with nothing waiting: the ring keeps a copy of everything that came in.
    static var nearlyFullAllIn: RingStatus {
        var status = RingStatus.nearlyFull
        status.waiting = 0
        return status
    }

    /// Bringing in 3, the first one 40% of the way.
    static var syncing: RingStatus {
        var status = RingStatus.syncing
        status.freeStoragePercent = 74
        return status
    }
}

// MARK: - A world of preview models

/// One lab screen's models: the store, the ring, the pipeline and a router of its own.
/// Never the live managers, never the ring.
@MainActor
final class LabWorld {
    let store: MuseStore
    let ring: RingModel
    let pipeline: MusePipeline
    let router = AppRouter()

    init(
        muses: [Muse]? = nil,
        status: RingStatus = .linked,
        working: Set<UUID> = [],
        noting: Set<UUID> = []
    ) {
        // Nil means the usual fixtures (defaults can't read main-actor statics).
        store = MuseStore.preview(muses ?? LabFixtures.muses)
        ring = RingModel.preview(status)
        pipeline = MusePipeline.preview(store, working: working, noting: noting)
    }
}

extension View {
    /// Hands a lab world to every screen under it, the way `RootView` hands the live models.
    func labWorld(_ world: LabWorld) -> some View {
        environment(world.store)
            .environment(world.ring)
            .environment(world.pipeline)
            .environment(world.router)
    }
}

/// Keeps one world for the life of a screen (a redraw never builds a fresh one) and
/// hands it to the content and the environment.
struct LabStage<Content: View>: View {
    @State private var world: LabWorld
    private let content: (LabWorld) -> Content

    init(_ world: @autoclosure () -> LabWorld, @ViewBuilder content: @escaping (LabWorld) -> Content) {
        _world = State(initialValue: world())
        self.content = content
    }

    var body: some View {
        content(world)
            .labWorld(world)
    }
}
#endif
