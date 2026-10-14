import Foundation

/// Nine believable muses for trying the home without a ring: `loadSamples()`, lab screens
/// and previews all use these same ones.
///
/// ```swift
/// MuseStore.preview(SampleMuses.make(now: SampleMuses.referenceNow))   // lab, previews
/// MusePipeline.shared.loadSamples()                                    // the live app
/// ```
///
/// Spread over today (three), yesterday (three) and earlier (three): varied lengths, titles,
/// one blank, one that couldn't be read, one with brief notes and one long thought with the
/// full write-up. All are `.sample`: the model never runs on them (their notes are written
/// here), they carry no audio, and deleting one never touches a file.
nonisolated enum SampleMuses {
    /// The lab's "now": 9:41a on october 8, 2026, in this iphone's time zone.
    static let referenceNow: Date = {
        let components = DateComponents(year: 2026, month: 10, day: 8, hour: 9, minute: 41)
        return Calendar.current.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 813_145_260)
    }()

    // Stable ids, so lab fixtures can point at a sample.

    /// Today, 3 min before now: "remind me to call mum back…".
    static let reminderID = id(1)
    /// Today, titled "rings floating in the window".
    static let windowID = id(2)
    /// Today, landed 40 minutes after it was said, the way a muse kept on the ring does.
    static let bakeryID = id(3)
    /// Yesterday, nothing but "thank you." (a blank muse).
    static let blankID = id(4)
    /// Yesterday, the long one, titled "call with priya".
    static let callID = id(5)
    /// Earlier, a recording that couldn't be read.
    static let failedID = id(6)
    /// Earlier, late at night.
    static let kettleID = id(7)
    /// Yesterday evening, about 180 words on the card in the box: brief notes.
    static let cardID = id(8)
    /// Two days ago, the long walk home from the market: a long thought with the full write-up.
    static let marketID = id(9)

    /// Every sample, newest first, placed around `now`. Pass `referenceNow` for pixel-stable
    /// screenshots; the live app passes `.now`.
    static func make(now: Date = referenceNow, calendar: Calendar = .current) -> [Muse] {
        let today = calendar.startOfDay(for: now)

        /// `minutes` before now. Just after midnight there isn't room, so today's three share
        /// the minutes since midnight instead (`slot` 3 newest): still today, still in order,
        /// never later than now.
        func todayAt(minutesAgo minutes: Double, slot: Int) -> Date {
            let wanted = now.addingTimeInterval(-minutes * 60)
            guard wanted < today else { return wanted }
            return today.addingTimeInterval(now.timeIntervalSince(today) * Double(slot) / 4)
        }

        /// A clock time `daysAgo` days before today.
        func day(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today.addingTimeInterval(Double(-daysAgo) * 86_400)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
                ?? start.addingTimeInterval(Double(hour * 3_600 + minute * 60))
        }

        return [
            sample(
                reminderID,
                at: todayAt(minutesAgo: 3, slot: 3),
                seconds: 14,
                words: "remind me to call mum back about sunday lunch, and ask if she wants me to bring the lemon tart.",
                confidence: 0.94
            ),
            sample(
                windowID,
                at: todayAt(minutesAgo: 49, slot: 2),
                seconds: 41,
                words: "okay, the shop window. instead of standing the rings up, hang them on thread at different heights so they look like they're floating. warm light from below. and one small card that just says listen.",
                title: "rings floating in the window",
                confidence: 0.91
            ),
            sample(
                bakeryID,
                at: todayAt(minutesAgo: 146, slot: 1),
                seconds: 23,
                words: "walked past the bakery on elm street again, the one with the green door. find out if they bake sourdough on weekdays.",
                confidence: 0.89,
                arrivesAfter: 40 * 60
            ),
            sample(
                blankID,
                at: day(1, 18, 5),
                seconds: 2,
                words: "thank you.",
                confidence: 0.42
            ),
            sample(
                callID,
                at: day(1, 13, 20),
                seconds: 107,
                words: "notes from the call with priya. she thinks we ship two sizes first, not five. the charging case can wait until spring.\n\nshe wants to see onboarding again on friday, the part where you hold the ring and the first muse lands. and she said the green is right, so don't touch the green.",
                title: "call with priya",
                confidence: 0.93
            ),
            sample(
                cardID,
                at: day(1, 21, 40),
                seconds: 74,
                words: "thinking about the card that goes in the box. right now it says thank you for your order, which is what every box says. i want it to say something only we would say. maybe just listen, like the window. or the date you bought it, handwritten. the handwriting matters, even if it takes me an extra minute a box. the paper should be the same green as the shop, not white, white feels like a receipt. and no logo on the front, the logo can be tiny on the back. if someone keeps the card on their desk, that's the win.\n\nalso the box itself is too big. the ring rattles around in it and it feels cheap when you open it. find a smaller box, or put a little cloth inside so it sits still. ask the printer if they can do the green on thicker card, and how many we'd need to order to make it worth it. maybe two hundred to start, and see how fast they go.",
                title: "the card in the box",
                confidence: 0.92,
                notes: MuseNotes(
                    kind: .brief,
                    bullets: [
                        "the card should say something only we would say, maybe just listen",
                        "handwrite the date, even if it costs a minute a box",
                        "shop green card, not white, logo tiny on the back",
                        "the box is too big and the ring rattles: smaller box or a cloth inside",
                        "ask the printer about green on thicker card, maybe two hundred to start",
                    ],
                    madeAt: day(1, 21, 42)
                )
            ),
            sample(
                marketID,
                at: day(2, 19, 10),
                seconds: 186,
                words: "okay, walking home from the market and i want to get this down before it goes. the stall did better than i thought, but not because of the rings. people stopped because of the window, the way the light came through the thread. one little girl pressed her nose to the glass for five whole minutes while her dad waited. so maybe the shop isn't really about selling rings, it's about making a place people want to stand in for a minute. that changes a lot. it means the window is the most important thing we make, not the website.\n\nthe other thing is the price. three people asked if there was a cheaper one, and i almost said yes. but every time i put the cheap version next to the real one, the cheap one makes the real one look worse. so no. one ring, one price, and if someone can't afford it this month, they can come back. that feels more honest than a smaller ring that nobody loves.\n\npriya said something on the call yesterday that keeps coming back. she said, don't make five of anything until people ask for the second one. i think that's the whole plan for spring. two sizes, one finish, the window, and a small card that just says listen. if people ask for more, we make more. if they don't, we saved ourselves a year of boxes in the back room. the woman with the flower stall next to us said the same thing about her first year. she made everything, and she sold three things. find the three things first, she said, then make more of those.\n\ni should also stop doing the books at midnight. every time i do them late i make a mistake and then i spend the next morning fixing it. sunday mornings, with coffee, before the market opens. that's the rule now.\n\nand mum wants to come see the stall. i keep putting it off because i want it to be perfect when she sees it, which is silly. she doesn't care if it's perfect. she'll care that i'm doing it. so this weekend, bring her, buy her the lemon tart, let her see it messy.\n\nto do, then. sketch the window for the shop tonight. email the jeweller about the second size. move the books to sunday mornings. ask mum about saturday. it's been a good week. it feels like the thing is finally turning into what it was supposed to be.",
                title: "the window is the shop",
                confidence: 0.9,
                notes: MuseNotes(
                    kind: .longThought,
                    bullets: [
                        "people stopped for the window, not the rings",
                        "the shop is a place to stand in for a minute, so the window matters more than the website",
                        "no cheaper ring: one ring, one price",
                        "spring is two sizes, one finish, the window and a card that says listen",
                        "the books move to sunday mornings",
                        "bring mum to the stall this weekend, messy is fine",
                    ],
                    overview: "the market showed that the window is what pulls people in, which makes the shop a place more than a store. the plan for spring gets smaller on purpose: one price, two sizes, and more only when people ask.",
                    threads: [
                        .init(title: "the window is the product", detail: "people stopped for the light through the thread, so the window comes before the website."),
                        .init(title: "one ring, one price", detail: "a cheaper version would make the real one look worse. better they come back later."),
                        .init(title: "make less until asked", detail: "priya's rule: don't make five of anything until someone asks for the second."),
                    ],
                    moments: [
                        .init(quote: "don't make five of anything until people ask for the second one", note: "priya, on the call"),
                        .init(quote: "she doesn't care if it's perfect. she'll care that i'm doing it", note: nil),
                    ],
                    actions: [
                        "sketch the window for the shop",
                        "email the jeweller about the second size",
                        "move the books to sunday mornings",
                        "ask mum about saturday",
                    ],
                    mood: 0.6,
                    madeAt: day(2, 19, 16)
                )
            ),
            sample(
                failedID,
                at: day(3, 9, 14),
                seconds: 9,
                words: nil,
                state: .failed,
                error: "this recording can't be read."
            ),
            sample(
                kettleID,
                at: day(3, 22, 32),
                seconds: 19,
                words: "a line for later. the kettle knows the morning has started before i do.",
                confidence: 0.9
            ),
        ].sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private

    private static func sample(
        _ id: UUID,
        at createdAt: Date,
        seconds: TimeInterval,
        words: String?,
        title: String? = nil,
        confidence: Double? = nil,
        state: TranscriptionState = .complete,
        error: String? = nil,
        notes: MuseNotes? = nil,
        arrivesAfter delay: TimeInterval = 4
    ) -> Muse {
        Muse(
            id: id,
            createdAt: createdAt,
            duration: seconds,
            origin: .sample,
            transcript: words,
            transcriptionState: state,
            transcriptionError: error,
            title: title,
            notes: notes,
            language: words == nil ? nil : "en",
            wordConfidence: confidence,
            textModel: words == nil ? nil : "sample",
            isBlank: state == .complete && Muse.isBlankTranscript(words),
            arrivedAt: createdAt.addingTimeInterval(seconds + delay)
        )
    }

    /// "muse" in the first four bytes, the sample's number in the last.
    private static func id(_ n: UInt8) -> UUID {
        UUID(uuid: (0x6D, 0x75, 0x73, 0x65, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, n))
    }
}
