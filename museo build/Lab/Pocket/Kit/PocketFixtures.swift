#if DEBUG
import Foundation

/// The made-up cast every pocket screen uses. Nothing here is anyone's real words.
nonisolated enum PocketFixtures {
    // MARK: Thoughts

    static let window = PocketThought(
        id: "window",
        title: "rings floating in the window",
        body: "rings floating in the window, just hung on thread so they turn a little when the door opens. no sign, no price. people stop for things that move.",
        day: "today", time: "9:36a", origin: .streamed, length: "0:41"
    )

    static let dentist = PocketThought(
        id: "dentist",
        title: "for claude, book the dentist thursday",
        body: "for claude, book the dentist thursday. afternoon if they have it.",
        day: "today", time: "9:12a", origin: .streamed, length: "0:08",
        place: "claude", why: "you said \u{201C}for claude\u{201D}",
        reply: PocketReply(who: "claude", text: "booked: thursday 3:30p. it's on your calendar.")
    )

    static let shop = PocketThought(
        id: "shop",
        title: "the window is the shop",
        body: "i keep thinking the window is the shop. most people never come in, they walk past twice a day and that's the whole relationship. so the window has to do what the counter does: say hello, show one thing, and change often enough that tuesday looks different from friday. one object, one line of type, good light. if someone does come in it should feel like stepping into the window, not past it.",
        day: "today", time: "8:40a", origin: .memory, length: "3:06",
        place: "ideas", why: "it sounded like an idea",
        hasNotes: true,
        notes: [
            "most people only ever meet the window",
            "one object, one line of type, good light",
            "change it often, so tuesday isn't friday",
        ]
    )

    static let card = PocketThought(
        id: "card",
        title: "the card in the box",
        body: "the card in the box should be handwritten, or look it. three lines. who made it, what to do first, and thank you. nothing to scan.",
        day: "today", time: "7:55a", origin: .streamed, length: "1:14",
        place: "ideas", why: "it sounded like an idea"
    )

    static let printShop = PocketThought(
        id: "print",
        title: "call the print shop",
        body: "call the print shop about the cards, ask if they can do the heavier stock by friday.",
        day: "yesterday", time: "4:20p", origin: .streamed, length: "0:15",
        place: "to do", why: "you said \u{201C}call\u{201D}"
    )

    static let supper = PocketThought(
        id: "supper",
        title: "a supper club, but for strangers",
        body: "a supper club, but for strangers. eight seats, one long table, nobody knows anybody. you leave your phone in a bowl by the door and the only rule is you can't ask what someone does.",
        day: "yesterday", time: "1:05p", origin: .streamed, length: "1:02",
        place: "ideas", why: "it sounded like an idea",
        givenToFM: true
    )

    static let farm = PocketThought(
        id: "farm",
        title: "what dad said about the farm",
        body: "what dad said about the farm, on the drive back. that he never wanted it, he just never said so, and by the time he could have it was his. he laughed about it. i want to remember that he laughed.",
        day: "sunday", time: "6:30p", origin: .memory, length: "3:10",
        place: "people", why: "you named dad"
    )

    static let walk = PocketThought(
        id: "walk",
        title: "a walk by the water",
        body: "a walk by the water. cold, flat, one heron. didn't think about work once until the car.",
        day: "sunday", time: "10:15a", origin: .memory, length: "0:42"
    )

    /// Newest first.
    static let thoughts: [PocketThought] = [window, dentist, shop, card, printShop, supper, farm, walk]

    /// The thoughts grouped by day, in order: today, yesterday, sunday.
    static let days: [(day: String, thoughts: [PocketThought])] = ["today", "yesterday", "sunday"].map { day in
        (day, thoughts.filter { $0.day == day })
    }

    /// The count line under "your thoughts".
    static let yoursCount = "212 · 3 today"

    /// The words arriving while the ring streams.
    static let streamingWords = "rings floating in the window, just hung on thread so they turn"

    // MARK: Places

    static let toDo = PocketPlace(id: "todo", name: "to do", sentence: "things i said i need to do", count: 14)
    static let ideas = PocketPlace(id: "ideas", name: "ideas", sentence: "ideas worth coming back to", count: 31)
    static let people = PocketPlace(id: "people", name: "people", sentence: "anything about a person i named", count: 9)

    static let claude = PocketPlace(
        id: "claude", name: "claude", sentence: "when i say for claude", count: 6,
        destination: .agent, sendsOn: true,
        recentSends: [
            PocketSend(id: "c1", title: "for claude, book the dentist thursday", state: .delivered, time: "9:12a"),
            PocketSend(id: "c2", title: "for claude, find the heavier card stock", state: .trying),
            PocketSend(id: "c3", title: "for claude, what was the name of that bakery", state: .failed),
        ]
    )

    static let journal = PocketPlace(
        id: "journal", name: "journal", sentence: "every thought, as it lands", count: 212,
        destination: .files, sendsOn: true,
        recentSends: [
            PocketSend(id: "j1", title: "rings floating in the window", state: .delivered, time: "9:36a"),
            PocketSend(id: "j2", title: "for claude, book the dentist thursday", state: .delivered, time: "9:12a"),
            PocketSend(id: "j3", title: "the window is the shop", state: .delivered, time: "8:40a"),
        ]
    )

    static let fmPlace = PocketPlace(
        id: "fm", name: "museo.fm", sentence: "only when i give one", count: 3,
        destination: .fm, sendsOn: false
    )

    static let places: [PocketPlace] = [toDo, ideas, people, claude, journal, fmPlace]

    /// The count line under "places".
    static let placesCount = "6 · 3 sending"

    static let suggestion = PocketSuggestion(count: 5, about: "the window")

    /// The thoughts filed in a place.
    static func thoughts(in place: PocketPlace) -> [PocketThought] {
        switch place.id {
        case "journal": thoughts
        case "fm": thoughts.filter(\.givenToFM)
        default: thoughts.filter { $0.place == place.name }
        }
    }

    // MARK: museo.fm

    static let fmThoughts: [PocketFMThought] = [
        PocketFMThought(
            id: "baker",
            words: "the baker across the street starts before the birds do. i have never once said thank you.",
            city: "lisbon", hour: "6:12a", hasVoice: true
        ),
        PocketFMThought(
            id: "daughter",
            words: "my daughter laughed in her sleep. i stood in the doorway far too long.",
            city: "osaka", hour: "11:04p", hasVoice: true
        ),
        PocketFMThought(
            id: "cups",
            words: "i still set two cups out. some mornings i let myself pour both.",
            city: "reykjavík", hour: "7:30a"
        ),
        PocketFMThought(
            id: "voicemail",
            words: "i kept my father's voicemail for nine years. today i listened to the end of it.",
            city: "nairobi", hour: "9:10a", hasVoice: true
        ),
        PocketFMThought(
            id: "tide",
            words: "the tide was all the way out and a man was teaching his dog to wait.",
            city: "vancouver", hour: "7:48a"
        ),
        PocketFMThought(
            id: "tomas",
            words: "learned the bus driver's name after four years. it's tomas.",
            city: "mexico city", hour: "8:15a"
        ),
        PocketFMThought(
            id: "supper",
            words: "a supper club, but for strangers",
            city: "toronto", hour: "1:05p", isYours: true
        ),
    ]

    /// "3 of yours are here"
    static let fmYoursLine = "3 of yours are here"

    // MARK: Ring

    /// Every pill state, in the order the review screen stacks them.
    static let ringStates: [PocketRingState] = [
        .linked(battery: 82),
        .away,
        .memory,
        .streaming(words: streamingWords),
        .bringingIn(done: 1, total: 2),
        .charging(level: 64),
    ]

    /// The ring at rest, for the shells.
    static let ring: PocketRingState = .linked(battery: 82)

    /// Room left on the ring, for the ring sheet.
    static let roomLeft = "2 hours, 48 minutes"
    static let firmware = "10.26"
}
#endif
