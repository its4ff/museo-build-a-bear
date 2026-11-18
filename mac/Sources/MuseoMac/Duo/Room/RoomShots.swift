#if DEBUG
import SwiftUI

/// Room: today's library window, every piece in its place, on the duo's materials.
enum RoomShots {
    static var all: [DuoShot] {
        [
            DuoShot("room-yours") { RoomYours(open: PocketFixtures.window) },
            DuoShot("room-thought") { RoomYours(open: PocketFixtures.dentist) },
            DuoShot("room-places") { RoomPlaces(open: PocketFixtures.claude) },
            DuoShot("room-fm") { RoomFM(open: PocketFixtures.fmThoughts[0]) },
        ]
    }
}

// MARK: - The four moments

/// The library: thoughts by day on the left, one read on the right.
struct RoomYours: View {
    let open: PocketThought

    var body: some View {
        RoomWindow(source: .yours, actions: RoomAction.thought) {
            ForEach(PocketFixtures.days, id: \.day) { group in
                RoomDayHeading(group.day)
                ForEach(group.thoughts) { thought in
                    RoomRow(
                        meta: RoomFixtures.meta(thought),
                        title: thought.body,
                        selected: thought.id == open.id,
                        ink: thought.ink,
                        isUnseen: RoomFixtures.unseen.contains(thought.id)
                    )
                }
            }
        } pane: {
            RoomThoughtPane(thought: open)
        }
    }
}

/// Places: the list of places on the left, one place's page on the right.
struct RoomPlaces: View {
    let open: PocketPlace

    var body: some View {
        RoomWindow(source: .places, actions: RoomAction.place) {
            RoomListNote(PocketFixtures.placesCount)
            ForEach(Array(RoomFixtures.placeGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 { RoomGap() }
                ForEach(group) { place in
                    RoomPlaceRow(place: place, selected: place.id == open.id)
                }
            }
        } pane: {
            RoomPlacePane(place: open)
        }
    }
}

/// museo.fm: what people gave on the left, one read on the right.
struct RoomFM: View {
    let open: PocketFMThought

    var body: some View {
        RoomWindow(source: .fm, actions: RoomAction.fm) {
            RoomListNote(PocketFixtures.fmYoursLine)
            ForEach(PocketFixtures.fmThoughts) { thought in
                RoomRow(
                    meta: thought.isYours ? "yours · \(thought.foot)" : thought.foot,
                    title: thought.words,
                    selected: thought.id == open.id
                )
            }
        } pane: {
            RoomFMPane(thought: open)
        }
    }
}
#endif
