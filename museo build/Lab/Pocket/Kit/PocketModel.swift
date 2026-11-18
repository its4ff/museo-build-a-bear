#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import Foundation

// The pocket mock's plain data: thoughts, places, museo.fm thoughts and what the ring is
// doing. Made up, never the real model, so no screen here needs the store or the ring.

// MARK: - Tabs

/// The three places to be.
nonisolated enum PocketTabID: String, CaseIterable, Hashable, Sendable {
    case yours, places, fm

    /// The word under the tab.
    var title: String {
        switch self {
        case .yours: "yours"
        case .places: "places"
        case .fm: "museo.fm"
        }
    }

    /// Its SF Symbol, outlined.
    var symbol: String {
        switch self {
        case .yours: "square.grid.2x2"
        case .places: "tray.2"
        case .fm: "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - A thought

/// How a thought was made: a hold (streamed) or a double click (memory).
nonisolated enum PocketOrigin: String, Hashable, Sendable {
    case streamed, memory
}

/// What a place sent back, shown under the words and never acted on.
nonisolated struct PocketReply: Hashable, Sendable {
    /// Who answered: "claude".
    let who: String
    let text: String

    /// "claude answered"
    var lead: String { "\(who) answered" }
}

/// One of your thoughts.
nonisolated struct PocketThought: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// Their words.
    let body: String
    /// "today", "yesterday", "sunday".
    let day: String
    /// "9:12a"
    let time: String
    let origin: PocketOrigin
    /// "0:41"
    let length: String
    /// The place it is filed in, if any: "to do".
    var place: String?
    /// Why it was filed there: "you said \u{201C}call\u{201D}".
    var why: String?
    var reply: PocketReply?
    var hasNotes = false
    /// The short notes, for long ones.
    var notes: [String] = []
    var givenToFM = false

    var isToday: Bool { day == "today" }

    /// The one mono line on its page: "today · 9:12a · streamed · 0:08".
    var meta: String { "\(day) · \(time) · \(origin.rawValue) · \(length)" }

    /// The tile's one quiet line: what came back, else where it went. Nil when neither.
    var foot: String? {
        if let reply { return reply.lead }
        if givenToFM { return "museo.fm" }
        return place
    }

    /// "in to do · you said \u{201C}call\u{201D}", nil when it is filed nowhere.
    var filedLine: String? {
        guard let place else { return nil }
        guard let why else { return "in \(place)" }
        return "in \(place) · \(why)"
    }

    /// How much ink its tile gets: today in full, older a step back.
    var ink: PocketInk {
        switch day {
        case "today": .full
        case "yesterday": .receding
        default: .far
        }
    }
}

// MARK: - A place

/// Where a place sends what it gathers.
nonisolated enum PocketDestination: String, Hashable, Sendable {
    case none, files, webAddress, agent, fm

    /// The words on the "send to" row.
    var label: String {
        switch self {
        case .none: "nowhere, just keep them together"
        case .files: "files"
        case .webAddress: "a web address"
        case .agent: "an agent"
        case .fm: "ask me each time"
        }
    }
}

/// One thing a place sent, and how it went.
nonisolated struct PocketSend: Identifiable, Hashable, Sendable {
    nonisolated enum State: String, Hashable, Sendable {
        case delivered, trying, failed
    }

    let id: String
    /// The thought's title.
    let title: String
    let state: State
    /// "9:41a", for a delivered one.
    var time: String?

    /// "delivered 9:41a", "trying again…", "didn't send".
    var line: String {
        switch state {
        case .delivered: time.map { "delivered \($0)" } ?? "delivered"
        case .trying: "trying again…"
        case .failed: "didn't send"
        }
    }
}

/// A name, one plain sentence, and an optional "send to".
nonisolated struct PocketPlace: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The rule, the way a person talks: "things i said i need to do".
    let sentence: String
    let count: Int
    var destination: PocketDestination = .none
    /// The switch that is the consent.
    var sendsOn = false
    var recentSends: [PocketSend] = []

    /// It sends somewhere by itself (museo.fm never does: it asks each time).
    var sends: Bool { sendsOn && destination != .none && destination != .fm }
}

/// "5 thoughts about the window. make it a place?"
nonisolated struct PocketSuggestion: Hashable, Sendable {
    let count: Int
    let about: String

    var line: String { "\(count) thoughts about \(about). make it a place?" }
}

// MARK: - museo.fm

/// Someone's thought on museo.fm: words, a city and a local hour. No name.
nonisolated struct PocketFMThought: Identifiable, Hashable, Sendable {
    let id: String
    let words: String
    let city: String
    /// "6:12a"
    let hour: String
    var hasVoice = false
    var isYours = false

    /// "lisbon · 6:12a"
    var foot: String { "\(city) · \(hour)" }
}

// MARK: - The ring

/// What the ring is doing, as the pill shows it.
nonisolated enum PocketRingState: Hashable, Sendable {
    case away
    /// Battery, exact, 0...100.
    case linked(battery: Int)
    /// Recording to itself (double click): amber.
    case memory
    /// A hold: the words as they arrive.
    case streaming(words: String)
    case bringingIn(done: Int, total: Int)
    /// Battery, exact, 0...100.
    case charging(level: Int)

    /// A short name for captions and labels.
    var name: String {
        switch self {
        case .away: "away"
        case .linked: "linked"
        case .memory: "memory"
        case .streaming: "streaming"
        case .bringingIn: "bringing in"
        case .charging: "charging"
        }
    }
}
#endif
