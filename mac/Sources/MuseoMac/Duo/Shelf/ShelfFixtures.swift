#if DEBUG
import Foundation

/// The shelf's own made-up thoughts: the kit's cast first, then enough more in the same
/// voice to fill a mac window for a few days. Nothing here is anyone's real words.
nonisolated enum ShelfFixtures {
    // MARK: More thoughts

    static let door = PocketThought(
        id: "door",
        title: "the door should sound like something",
        body: "the door should sound like something. a small bell, or just good wood. you remember a shop by its door.",
        day: "today", time: "7:20a", origin: .streamed, length: "0:19"
    )

    static let maya = PocketThought(
        id: "maya",
        title: "ask maya about the linen samples",
        body: "ask maya about the linen samples, the oat one and the one that looked like wet sand.",
        day: "yesterday", time: "11:40a", origin: .streamed, length: "0:11",
        place: "people", why: "you named maya"
    )

    static let tag = PocketThought(
        id: "tag",
        title: "the tag is the receipt",
        body: "the tag is the receipt. one piece of card, the price on the back in pencil, nothing printed twice.",
        day: "yesterday", time: "10:02a", origin: .memory, length: "0:48",
        place: "ideas", why: "it sounded like an idea"
    )

    static let frames = PocketThought(
        id: "frames",
        title: "pick up the frames before six",
        body: "pick up the frames before six, they close early on mondays.",
        day: "yesterday", time: "8:15a", origin: .streamed, length: "0:07",
        place: "to do", why: "you said \u{201C}pick up\u{201D}"
    )

    static let emptyShelf = PocketThought(
        id: "emptyshelf",
        title: "a shelf that is mostly empty",
        body: "a shelf that is mostly empty. three things on it and a lot of air. the air is what makes them look chosen.",
        day: "sunday", time: "4:45p", origin: .memory, length: "1:20",
        place: "ideas", why: "it sounded like an idea"
    )

    static let printRoom = PocketThought(
        id: "printroom",
        title: "the smell of the print room",
        body: "the smell of the print room. ink and warm paper. i want the box to smell a little like that when it opens.",
        day: "sunday", time: "2:10p", origin: .memory, length: "0:36"
    )

    static let noor = PocketThought(
        id: "noor",
        title: "send noor the photo of the heron",
        body: "send noor the photo of the heron, she won't believe how close it let me get.",
        day: "sunday", time: "10:50a", origin: .streamed, length: "0:09",
        place: "people", why: "you named noor"
    )

    static let quiet = PocketThought(
        id: "quiet",
        title: "open late on thursdays, quietly",
        body: "open late on thursdays, quietly. no sign about it. the people who find out will tell the right people.",
        day: "saturday", time: "9:05p", origin: .memory, length: "0:52",
        place: "ideas", why: "it sounded like an idea"
    )

    static let lamp = PocketThought(
        id: "lamp",
        title: "the lamp from grandma's hallway",
        body: "the lamp from grandma's hallway would be right for the counter. ask mom if it's still in the garage.",
        day: "saturday", time: "3:30p", origin: .streamed, length: "0:21"
    )

    static let string = PocketThought(
        id: "string",
        title: "buy string, the waxed kind",
        body: "buy string, the waxed kind, and more of the small brass hooks.",
        day: "saturday", time: "11:15a", origin: .streamed, length: "0:06",
        place: "to do", why: "you said \u{201C}buy\u{201D}"
    )

    // MARK: The shelf

    /// Newest first: the kit's cast with the shelf's own between them.
    static let thoughts: [PocketThought] = [
        PocketFixtures.window, PocketFixtures.dentist, PocketFixtures.shop, PocketFixtures.card, door,
        PocketFixtures.printShop, PocketFixtures.supper, maya, tag, frames,
        PocketFixtures.farm, emptyShelf, printRoom, noor, PocketFixtures.walk,
        quiet, lamp, string,
    ]

    /// The shelf grouped by day, in order.
    static let days: [(day: String, thoughts: [PocketThought])] = ["today", "yesterday", "sunday", "saturday"].map { day in
        (day, thoughts.filter { $0.day == day })
    }

    /// The count line under "your thoughts".
    static let yoursCount = "212 · 5 today"

    // MARK: museo.fm

    /// Other people's thoughts, after the kit's.
    static let moreFM: [PocketFMThought] = [
        PocketFMThought(
            id: "pears",
            words: "the neighbor leaves pears on our step and has never once knocked.",
            city: "tbilisi", hour: "5:40p"
        ),
        PocketFMThought(
            id: "radio",
            words: "found my mother's handwriting inside the radio. it just says louder.",
            city: "cork", hour: "10:22p", hasVoice: true
        ),
        PocketFMThought(
            id: "snow",
            words: "first snow. the whole street went quiet at the same time.",
            city: "sapporo", hour: "6:55a"
        ),
        PocketFMThought(
            id: "ferry",
            words: "i take the slow ferry on purpose now.",
            city: "istanbul", hour: "8:05a", hasVoice: true
        ),
    ]

    /// The one given room at the top.
    static let fmFirst: PocketFMThought = PocketFixtures.fmThoughts[0]

    /// Everyone else, as tiles.
    static let fmRest: [PocketFMThought] = Array(PocketFixtures.fmThoughts.dropFirst()) + moreFM

    static let fmCount = "thoughts from rings around the world"
}
#endif
