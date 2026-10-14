import Foundation
import FoundationModels

// What the on-device model fills in for notes. `MuseNotesWriter` asks for these and tidies
// them into `MuseNotes`. Fields are generated in the order they're declared, so the overview
// comes before the bullets it sums up.
//
// Every one is `nonisolated`: the model fills them off the main actor, and the compiler
// won't warn if that's forgotten.

// MARK: - Brief (150 to 399 words)

@Generable
nonisolated struct MuseBriefDraft {
    @Guide(description: "3 to 5 short lines, what they were actually saying, close to their words. fewer when there is little to keep.", .count(1...5))
    var bullets: [String]
}

// MARK: - Long thought (400 words and up)

@Generable
nonisolated struct MuseLongThoughtDraft {
    @Guide(description: "2 to 4 sentences: what this thought was actually about and what shifted")
    var overview: String

    @Guide(description: "4 to 6 short lines, the bones of the whole thought, close to their words", .count(1...6))
    var bullets: [String]

    @Guide(description: "the distinct lines of thinking, up to 5", .count(0...5))
    var threads: [MuseThreadDraft]

    @Guide(description: "lines worth keeping, quoted close to how they said them, up to 4", .count(0...4))
    var moments: [MuseMomentDraft]

    @Guide(description: "real commitments or next steps they said out loud, imperative and short, up to 6", .count(0...6))
    var actions: [String]

    @Guide(description: "-1 heavy, 0 level, 1 light", .range(-1.0...1.0))
    var mood: Double
}

@Generable
nonisolated struct MuseThreadDraft {
    @Guide(description: "a few lowercase words naming this line of thinking")
    var title: String

    @Guide(description: "1 or 2 sentences on it")
    var detail: String
}

@Generable
nonisolated struct MuseMomentDraft {
    @Guide(description: "their line, quoted close to how they said it")
    var quote: String

    @Guide(description: "a few words on why it matters, or empty")
    var note: String
}

// MARK: - One part of a very long thought

/// Map step for muses too long for one call: the bones of one part, then the long thought
/// is written from every part's, in order.
@Generable
nonisolated struct MusePartDraft {
    @Guide(description: "2 to 5 short lines, what they were actually saying in this part, close to their words", .count(1...5))
    var bullets: [String]

    @Guide(description: "up to 2 lines worth keeping, copied word for word from this part", .count(0...2))
    var quotes: [String]

    @Guide(description: "real commitments or next steps they said out loud in this part, imperative and short", .count(0...3))
    var actions: [String]
}
