import Foundation

/// Notes for one muse, written on this iphone by Apple's on-device model (`MuseAI.notes`).
/// How much there is depends on how much they said:
///
/// | their words | notes |
/// |---|---|
/// | under 150 | none: the words are the note |
/// | 150 to 399 | `.brief`: 3 to 5 bullets |
/// | 400 and up | `.longThought`: bullets, an overview, threads, moments, to-dos, mood |
///
/// Stored on the muse (`Muse.notes`), so they're saved and deleted with it. Adding a field:
/// give it a default and decode it with `decodeIfPresent`.
nonisolated struct MuseNotes: Codable, Equatable, Hashable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        /// 3 to 5 bullets.
        case brief
        /// The full write-up for a long muse.
        case longThought
    }

    /// One line of thinking in a long thought: a short title and a sentence or two.
    nonisolated struct Thread: Codable, Equatable, Hashable, Sendable {
        var title: String
        var detail: String
    }

    /// A line worth keeping, quoted close to how they said it.
    nonisolated struct Moment: Codable, Equatable, Hashable, Sendable {
        var quote: String
        var note: String?
    }

    var kind: Kind
    /// What they were actually saying, close to their words. Brief: 3 to 5. Long: 4 to 6.
    var bullets: [String]
    /// Long thoughts: 2 to 4 sentences on what it was about and what shifted.
    var overview: String?
    var threads: [Thread]
    var moments: [Moment]
    /// Commitments or next steps they said out loud. Plain lines, nothing is scheduled.
    var actions: [String]
    /// -1 heavy, 0 level, 1 light. Long thoughts only.
    var mood: Double?
    var madeAt: Date
    /// What wrote them, e.g. "apple-on-device".
    var model: String

    init(
        kind: Kind,
        bullets: [String],
        overview: String? = nil,
        threads: [Thread] = [],
        moments: [Moment] = [],
        actions: [String] = [],
        mood: Double? = nil,
        madeAt: Date = .now,
        model: String = MuseNotes.onDeviceModel
    ) {
        self.kind = kind
        self.bullets = bullets
        self.overview = overview
        self.threads = threads
        self.moments = moments
        self.actions = actions
        self.mood = mood
        self.madeAt = madeAt
        self.model = model
    }

    static let onDeviceModel = "apple-on-device"

    // MARK: - When a muse gets notes

    /// Fewer words than this and the words are the note.
    static let briefFrom = 150
    /// This many words and up get the long thought.
    static let longThoughtFrom = 400

    /// The notes a muse with this many words gets, or nil for none.
    static func kind(forWordCount count: Int) -> Kind? {
        if count >= longThoughtFrom { return .longThought }
        if count >= briefFrom { return .brief }
        return nil
    }

    // MARK: - How much

    /// The most of each part the notes keep. The model is asked for these too
    /// (`MuseNotesDrafts.swift`); these caps hold whatever comes back.
    static let mostBriefBullets = 5
    static let mostLongBullets = 6
    static let mostThreads = 5
    static let mostMoments = 4
    static let mostActions = 6

    /// Something to show: a bullet, or a long thought's overview.
    var hasContent: Bool {
        !bullets.isEmpty || !(overview ?? "").isEmpty
    }

    // MARK: - Reading

    /// "light", "heavy" or "level" for a long thought's mood, nil without one.
    var moodWord: String? {
        guard let mood else { return nil }
        if mood > 0.35 { return "light" }
        if mood < -0.35 { return "heavy" }
        return "level"
    }

    /// The notes as plain text, for copying and sharing:
    ///
    /// ```
    /// · bullet one
    /// · bullet two
    ///
    /// threads
    /// · thread title: detail
    ///
    /// moments
    /// · quote · note
    ///
    /// to do
    /// · action
    /// ```
    var plainText: String {
        var blocks: [String] = []
        if !bullets.isEmpty {
            blocks.append(bullets.map { "· \($0)" }.joined(separator: "\n"))
        } else if let overview, !overview.isEmpty {
            blocks.append(overview)
        }
        if !threads.isEmpty {
            blocks.append((["threads"] + threads.map { "· \($0.title): \($0.detail)" }).joined(separator: "\n"))
        }
        if !moments.isEmpty {
            let lines = moments.map { moment in
                let quote = "\u{201C}\(moment.quote)\u{201D}"
                guard let note = moment.note, !note.isEmpty else { return "· \(quote)" }
                return "· \(quote) · \(note)"
            }
            blocks.append((["moments"] + lines).joined(separator: "\n"))
        }
        if !actions.isEmpty {
            blocks.append((["to do"] + actions.map { "· \($0)" }).joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n")
    }

    // MARK: - Codable (resilient)

    private enum CodingKeys: String, CodingKey {
        case kind, bullets, overview, threads, moments, actions, mood, madeAt, model
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? .brief
        bullets = (try? c.decodeIfPresent([String].self, forKey: .bullets)) ?? []
        overview = try? c.decodeIfPresent(String.self, forKey: .overview)
        threads = (try? c.decodeIfPresent([Thread].self, forKey: .threads)) ?? []
        moments = (try? c.decodeIfPresent([Moment].self, forKey: .moments)) ?? []
        actions = (try? c.decodeIfPresent([String].self, forKey: .actions)) ?? []
        mood = try? c.decodeIfPresent(Double.self, forKey: .mood)
        madeAt = (try? c.decodeIfPresent(Date.self, forKey: .madeAt)) ?? .distantPast
        model = (try? c.decodeIfPresent(String.self, forKey: .model)) ?? Self.onDeviceModel
    }
}
