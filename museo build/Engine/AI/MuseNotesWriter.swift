import Foundation
import FoundationModels
import OSLog

/// Writes a muse's notes with Apple's on-device model. `MuseAI.notes(_:for:)` is the way in;
/// the pipeline calls it once a muse's words land.
///
/// ```
/// 150 to 399 words  ─▶ brief         one call: 3 to 5 bullets
/// 400 words and up  ─▶ long thought  one call while the words fit the model's window,
///                                    longer ones map, then reduce:
///   words ─▶ parts of about 800 words ─▶ bullets, quotes, to-dos for each part
///         ─▶ the long thought, written from the parts in order
/// ```
///
/// The window is 4,096 tokens for instructions, words and answer together, so about
/// 1,500 spoken words fit in one call. Past 8 parts (about 40 minutes of talking) the long
/// thought is read from 8 evenly spaced ones.
///
/// Everything that comes back is tidied before it's kept: no dashes, lowercase except the
/// names they said (`TheirNames`), no empty lines, no more than `MuseNotes` allows.
@MainActor
enum MuseNotesWriter {
    /// Words per part when a long thought is read in parts.
    static let partWords = 800
    /// The one retry after a part (or the parts together) was still too long.
    static let smallerPartWords = 450
    /// The most parts read for one muse.
    static let mostParts = 8

    /// Notes of this kind for their words, or nil when the model is unavailable, declines,
    /// or finds nothing worth keeping. `partWords` reads a long thought in parts of that
    /// size even when it would fit in one call (the notes probe uses it).
    static func write(_ kind: MuseNotes.Kind, for words: String, partWords forced: Int? = nil) async -> MuseNotes? {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MuseAI.isAvailable, !text.isEmpty else { return nil }
        let names = TheirNames(text)
        do {
            switch kind {
            case .brief: return try await brief(text, names: names)
            case .longThought: return try await longThought(text, names: names, forcedPartWords: forced)
            }
        } catch is CancellationError {
            return nil
        } catch {
            log.info("no \(kind.rawValue, privacy: .public) notes: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Whether these words fit one long-thought call, with the counts that decided it.
    static func fitsOneCall(_ words: String) async -> (fits: Bool, used: Int, room: Int) {
        let room = SystemLanguageModel.default.contextSize - longAnswerTokens - slackTokens
        let used = await tokens(instructions: longRules)
            + tokens(schema: MuseLongThoughtDraft.generationSchema)
            + tokens(prompt(words))
        return (used <= room, used, room)
    }

    // MARK: - Brief

    private static func brief(_ words: String, names: TheirNames) async throws -> MuseNotes? {
        do {
            let draft = try await MuseAI.generate(MuseBriefDraft.self, from: prompt(words), instructions: briefRules)
            let bullets = lines(draft.bullets, names: names, most: MuseNotes.mostBriefBullets)
            guard !bullets.isEmpty else { return nil }
            return MuseNotes(kind: .brief, bullets: bullets)
        } catch MuseAIError.declined {
            return try await bulletsInstead(.brief, from: prompt(words), instructions: plainBriefRules, names: names)
        }
    }

    // MARK: - Long thought

    private static func longThought(_ words: String, names: TheirNames, forcedPartWords: Int?) async throws -> MuseNotes? {
        if let forcedPartWords {
            return try await inParts(words, names: names, partWords: forcedPartWords)
        }
        if await fitsOneCall(words).fits {
            do {
                let draft = try await MuseAI.generate(MuseLongThoughtDraft.self, from: prompt(words), instructions: longRules)
                return tidy(draft, names: names)
            } catch MuseAIError.tooLong {
                log.info("one call was too long, reading it in parts")
            } catch MuseAIError.declined {
                return try await bulletsInstead(.longThought, from: prompt(words), instructions: plainLongRules, names: names)
            }
        }
        do {
            return try await inParts(words, names: names, partWords: partWords)
        } catch MuseAIError.tooLong {
            log.info("parts were too long, once more with smaller ones")
            return try await inParts(words, names: names, partWords: smallerPartWords, lean: true)
        }
    }

    /// Map, then reduce: the bones of each part, then the long thought from all of them.
    /// `lean` keeps fewer bullets per part, so the parts together take less room.
    private static func inParts(_ words: String, names: TheirNames, partWords: Int, lean: Bool = false) async throws -> MuseNotes? {
        let all = MuseWordParts.split(words, around: partWords)
        var read: [(index: Int, bones: PartBones)] = []
        for part in MuseWordParts.spread(all, keeping: mostParts) {
            try Task.checkCancellation()
            let partPrompt = "part \(part.index + 1) of \(all.count):\n\n\(part.text)"
            do {
                let draft = try await MuseAI.generate(MusePartDraft.self, from: partPrompt, instructions: partRules)
                read.append((part.index, PartBones(bullets: draft.bullets, quotes: draft.quotes, actions: draft.actions)))
            } catch MuseAIError.declined {
                // The guardrails passed on this part: its bullets once more, in plain text.
                // A part that still gives nothing is left out; the others make the notes.
                let bullets = (try? await plainBullets(from: partPrompt, instructions: plainPartRules)) ?? []
                if bullets.isEmpty {
                    log.info("part \(part.index + 1) of \(all.count) was declined")
                } else {
                    read.append((part.index, PartBones(bullets: bullets)))
                }
            }
        }
        guard !read.isEmpty else { return nil }
        let parts = digest(read, of: all.count, bulletsEach: lean ? 3 : MuseNotes.mostBriefBullets, names: names)
        do {
            let draft = try await MuseAI.generate(MuseLongThoughtDraft.self, from: parts, instructions: fromPartsRules)
            return tidy(draft, names: names)
        } catch MuseAIError.declined {
            return try await bulletsInstead(.longThought, from: parts, instructions: plainFromPartsRules, names: names)
        }
    }

    /// What one part gave: the guided call's bullets, quotes and to-dos, or bullets alone
    /// from the plain text one.
    private struct PartBones {
        var bullets: [String]
        var quotes: [String] = []
        var actions: [String] = []
    }

    /// The parts, in order, as the reduce step reads them:
    ///
    /// ```
    /// part 1 of 3
    /// · people stopped for the window, not the rings
    /// they said: "find the three things first"
    /// to do: sketch the window
    /// ```
    private static func digest(_ read: [(index: Int, bones: PartBones)], of total: Int, bulletsEach: Int, names: TheirNames) -> String {
        read.map { part in
            var lines = ["part \(part.index + 1) of \(total)"]
            lines += self.lines(part.bones.bullets, names: names, most: bulletsEach).map { "· \($0)" }
            lines += self.lines(part.bones.quotes, names: names, most: 2, unquote: true).map { "they said: \($0.museQuoted)" }
            lines += self.lines(part.bones.actions, names: names, most: 3).map { "to do: \($0)" }
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    // MARK: - When the guardrails pass

    /// Guided answers run under the default guardrails, which pass on muses about something
    /// sensitive (an illness, a fight, the news). Plain text runs under permissive ones, so
    /// a declined call is asked once more for bullets alone, one per line. The kind stays;
    /// only the bullets come back.
    private static func bulletsInstead(_ kind: MuseNotes.Kind, from prompt: String, instructions: String, names: TheirNames) async throws -> MuseNotes? {
        log.info("\(kind.rawValue, privacy: .public) was declined, asking once in plain text")
        let most = kind == .brief ? MuseNotes.mostBriefBullets : MuseNotes.mostLongBullets
        let answer = try await plainBullets(from: prompt, instructions: instructions)
        let bullets = lines(answer, names: names, most: most)
        guard !bullets.isEmpty else { return nil }
        return MuseNotes(kind: kind, bullets: bullets)
    }

    /// The plain answer's lines, untidied, or none when the model refused in words. A lead
    /// in line ("here are the bullets:") is dropped.
    private static func plainBullets(from prompt: String, instructions: String) async throws -> [String] {
        let answer = try await MuseAI.answer(prompt, instructions: instructions, options: GenerationOptions(sampling: .greedy))
        guard !MuseAI.looksLikeRefusal(answer) else { return [] }
        return answer.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasSuffix(":")
        }
    }

    // MARK: - Tidying

    private static func tidy(_ draft: MuseLongThoughtDraft, names: TheirNames) -> MuseNotes? {
        let overview = names.calm(draft.overview.replacingOccurrences(of: "\n", with: " "))
        let threads = draft.threads.compactMap { thread -> MuseNotes.Thread? in
            guard let title = line(thread.title, names: names) else { return nil }
            let detail = names.calm(thread.detail.replacingOccurrences(of: "\n", with: " "))
            guard !detail.isEmpty else { return nil }
            return MuseNotes.Thread(title: title, detail: detail)
        }
        let moments = draft.moments.compactMap { moment -> MuseNotes.Moment? in
            guard let quote = line(moment.quote, names: names, unquote: true) else { return nil }
            return MuseNotes.Moment(quote: quote, note: line(moment.note, names: names))
        }
        let mood = draft.mood.isFinite ? min(max(draft.mood, -1), 1) : nil
        let notes = MuseNotes(
            kind: .longThought,
            bullets: lines(draft.bullets, names: names, most: MuseNotes.mostLongBullets),
            overview: overview.isEmpty ? nil : overview,
            threads: Array(unique(threads, by: \.title).prefix(MuseNotes.mostThreads)),
            moments: Array(unique(moments, by: \.quote).prefix(MuseNotes.mostMoments)),
            actions: lines(draft.actions, names: names, most: MuseNotes.mostActions),
            mood: mood
        )
        return notes.hasContent ? notes : nil
    }

    /// Tidy lines, no empties or repeats, at most `most`.
    private static func lines(_ raw: [String], names: TheirNames, most: Int, unquote: Bool = false) -> [String] {
        Array(unique(raw.compactMap { line($0, names: names, unquote: unquote) }, by: \.self).prefix(most))
    }

    /// One short line: one line, no list mark or end period, calm, lowercase except names.
    /// Nil when nothing is left.
    private static func line(_ raw: String, names: TheirNames, unquote: Bool = false) -> String? {
        var text = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        // A list mark the model added: "- ", "• ", "· ", "* ", "1. ", "2) ".
        if let mark = text.firstMatch(of: #/^(?:[-•·*]|\d{1,2}[.)])\s+/#) {
            text.removeSubrange(mark.range)
        }
        if unquote {
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}").union(.whitespaces))
        }
        text = names.calm(text)
        while text.hasSuffix(".") && !text.hasSuffix("..") { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// First of each, by a key compared without case.
    private static func unique<T>(_ items: [T], by key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return items.filter { seen.insert(key($0).lowercased()).inserted }
    }

    // MARK: - Room

    /// Kept for the answer: a long thought runs to about 600 tokens, so this leaves margin.
    private static let longAnswerTokens = 1_100
    /// The chat template, role marks and the prompt's own framing.
    private static let slackTokens = 150

    private static func prompt(_ words: String) -> String {
        "their words:\n\n\(words)"
    }

    // The model counts tokens from iOS 26.4. Before that, the estimate below stands in.

    private static func tokens(_ prompt: String) async -> Int {
        guard #available(iOS 26.4, *) else { return estimate(prompt) }
        return (try? await SystemLanguageModel.default.tokenCount(for: Prompt(prompt))) ?? estimate(prompt)
    }

    private static func tokens(instructions: String) async -> Int {
        guard #available(iOS 26.4, *) else { return estimate(instructions) }
        return (try? await SystemLanguageModel.default.tokenCount(for: Instructions(instructions))) ?? estimate(instructions)
    }

    private static func tokens(schema: GenerationSchema) async -> Int {
        guard #available(iOS 26.4, *) else { return 400 }
        return (try? await SystemLanguageModel.default.tokenCount(for: schema)) ?? 400
    }

    /// When the model can't count (before iOS 26.4, or when counting fails): about 1.4 tokens for each word between spaces, and one
    /// for each character of Chinese, Japanese, Thai or Korean, which take about a token
    /// a character.
    nonisolated static func estimate(_ text: String) -> Int {
        var dense = 0
        for scalar in text.unicodeScalars
        where MuseWordParts.isUnspaced(scalar) || (0xAC00...0xD7AF).contains(scalar.value) {
            dense += 1
        }
        let words = Double(text.split(whereSeparator: \.isWhitespace).count)
        return Int((words * 1.4).rounded(.up)) + dense
    }

    // MARK: - Prompts

    nonisolated private static let log = Logger(subsystem: "museo.build", category: "notes")

    /// Said in every notes prompt.
    nonisolated private static let groundRules = """
    lowercase everywhere except names. never say "the user" or "the speaker": write the way \
    they'd jot it for themselves. write in the same language as their words. never invent \
    anything that isn't in their words. never use em dashes or en dashes anywhere: use \
    commas, periods or colons instead.
    """

    /// 150 to 399 words: a few bullets, on this iphone.
    nonisolated static let briefRules = MuseAI.voice + """


    right now you are the notes engine inside museo. you skim one spoken muse and pull out \
    the bones as bullets.

    write 3 to 5 bullets. each is one short line: what they were actually saying, not a \
    paraphrase essay. spare, close to their words. no filler, no throat clearing, no \
    invented points. skip anything that isn't in their words. if there is almost nothing \
    worth keeping, return fewer bullets rather than padding.

    """ + groundRules

    /// 400 words and up, in one call. The long thought, without the title (the muse
    /// gets one from `MuseAI.title`) or the persona.
    nonisolated static let longRules = MuseAI.voice + """


    right now you are the notes engine inside museo. someone wore a voice ring and spoke \
    one long thought, no phone in hand. you get their words. write the notes they'd want \
    waiting for them under their words.

    """ + longThoughtFields(moments: "lines worth keeping, quoted close to how they said them, 0 to 4 of them") + """

    - their words come from speech recognition and are imperfect. skip filler, false starts \
    and noise, and read through obvious errors
    - leave arrays empty rather than padding them

    """ + groundRules

    /// The map step: one part of a thought too long for one call.
    nonisolated static let partRules = MuseAI.voice + """


    right now you are the notes engine inside museo. someone spoke one long thought into a \
    voice ring, too long to read at once, so you get it one part at a time. pull out the \
    bones of this part.

    - bullets: 2 to 5 short lines, what they were actually saying in this part, close to \
    their words. no filler
    - quotes: up to 2 lines worth keeping, copied word for word from this part
    - actions: only real commitments or next steps they said out loud in this part, \
    imperative and short
    - their words come from speech recognition and are imperfect. read through obvious errors
    - leave arrays empty rather than padding them

    """ + groundRules

    /// The reduce step: the long thought from its parts' notes.
    nonisolated static let fromPartsRules = MuseAI.voice + """


    right now you are the notes engine inside museo. someone wore a voice ring and spoke \
    one long thought, too long to read at once. you get notes on it part by part, in the \
    order they said it: what they said, lines they said word for word, and what they said \
    they'd do. write the notes for the whole thought.

    """ + longThoughtFields(moments: "lines worth keeping, taken word for word from what they said, 0 to 4 of them") + """

    - actions come only from their to-dos
    - leave arrays empty rather than padding them

    """ + groundRules

    /// Plain text bullets when the guided brief was declined.
    nonisolated static let plainBriefRules = plainRules("""
    you skim one spoken muse and pull out the bones.
    """, lines: "3 to 5")

    /// Plain text bullets when the guided long thought was declined.
    nonisolated static let plainLongRules = plainRules("""
    someone wore a voice ring and spoke one long thought. pull out the bones of the whole \
    thought. their words come from speech recognition and are imperfect, so skip filler and \
    read through obvious errors.
    """, lines: "4 to 6")

    /// Plain text bullets when one part's guided call was declined.
    nonisolated static let plainPartRules = plainRules("""
    someone spoke one long thought into a voice ring, too long to read at once, so you get \
    it one part at a time. pull out the bones of this part.
    """, lines: "2 to 5")

    /// Plain text bullets when the guided reduce step was declined.
    nonisolated static let plainFromPartsRules = plainRules("""
    someone spoke one long thought into a voice ring, too long to read at once. you get \
    notes on it part by part, in the order they said it. pull out the bones of the whole \
    thought.
    """, lines: "4 to 6")

    nonisolated private static func plainRules(_ task: String, lines count: String) -> String {
        MuseAI.voice + """


        right now you are the notes engine inside museo. \(task)

        write \(count) short lines, one per line, and nothing else: no heading, no mark in \
        front of a line, nothing before or after them. each line is what they were actually \
        saying, close to their words. no filler, no invented points. if there is almost \
        nothing worth keeping, write fewer lines rather than padding.

        """ + groundRules
    }

    nonisolated private static func longThoughtFields(moments: String) -> String {
        """
        rules:
        - overview: 2 to 4 sentences on what this thought was actually about and what shifted
        - bullets: 4 to 6 short lines, the bones of the whole thought. what they were actually \
        saying, close to their words. not a paraphrase essay. no filler, no throat clearing
        - threads: the distinct lines of thinking, 2 to 5 of them. a few words for the title, \
        1 or 2 sentences of detail
        - moments: \(moments)
        - actions: only real commitments or next steps they said out loud, 0 to 6, imperative \
        and short
        - mood: -1 for heavy, 0 for level, 1 for light
        """
    }
}
