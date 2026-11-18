#if DEBUG
import Foundation

/// What the mac knows that the iphone's made-up cast doesn't say: where a streamed thought
/// landed, which model heard it, the page's date. All made up.
nonisolated enum RoomFixtures {
    /// Where a hold's words went on this mac.
    static let landing: [String: String] = [
        "window": "into your note",
        "dentist": "sent to claude",
        "card": "into your note",
        "print": "into reminders",
    ]

    /// Ring recordings nobody has opened yet.
    static let unseen: Set<String> = ["shop"]

    /// The speech model's name.
    static let model = "parakeet ultra"

    /// A day as the page's mono line writes it.
    static let dates: [String: String] = [
        "today": "tuesday nov 17",
        "yesterday": "monday nov 16",
        "sunday": "sunday nov 15",
    ]

    /// "9:36a · streamed · into your note", "8:40a · from the ring · 3:06".
    static func meta(_ thought: PocketThought) -> String {
        var parts = [thought.time, thought.origin == .memory ? "from the ring" : "streamed"]
        if let landing = landing[thought.id] {
            parts.append(landing)
        } else if thought.origin == .memory {
            parts.append(thought.length)
        }
        return parts.joined(separator: " · ")
    }

    /// "tuesday nov 17 · 9:36a · streamed · 0:41".
    static func dateLine(_ thought: PocketThought) -> String {
        [
            dates[thought.day] ?? thought.day,
            thought.time,
            thought.origin == .memory ? "from the ring" : "streamed",
            thought.length,
        ].joined(separator: " · ")
    }

    /// "sent to claude · parakeet ultra".
    static func heardLine(_ thought: PocketThought) -> String {
        [landing[thought.id], model].compactMap { $0 }.joined(separator: " · ")
    }

    /// Places as the iphone groups them: kept together, sending, given.
    static let placeGroups: [[PocketPlace]] = [
        [PocketFixtures.toDo, PocketFixtures.ideas, PocketFixtures.people],
        [PocketFixtures.claude, PocketFixtures.journal],
        [PocketFixtures.fmPlace],
    ]

    /// A place's newest thoughts, with when.
    static let claudeThoughts: [(title: String, when: String)] = [
        ("for claude, book the dentist thursday", "today · 9:12a"),
        ("for claude, move the standup to ten", "yesterday · 5:02p"),
        ("for claude, draft a note to the landlord", "sunday · 11:40a"),
    ]

    /// How long a museo.fm voice runs.
    static let fmLength = "0:09"
}
#endif
