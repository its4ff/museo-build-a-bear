import Foundation
import NaturalLanguage

/// Search over their muses, on this iphone.
///
/// ```swift
/// let hits = MuseSearch.search("the fundraise", in: store.muses)   // best first
/// ```
///
/// Voice notes are short, which is what `NLEmbedding`'s sentence vectors are
/// trained for, and keeping retrieval on-device means a corpus of personal
/// thinking never leaves the phone to be searched.
///
/// Retrieval is hybrid: embeddings catch meaning ("the fundraise" finding a note
/// about investors), keyword overlap catches the proper nouns and rare words that
/// sentence vectors blur away. Neither alone is enough.
///
/// The home's search uses `search(_:in:limit:)`.
nonisolated enum MuseSearch {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var models: [String: NLEmbedding] = [:]

    /// Weight of semantic similarity against keyword overlap in the blended score.
    private static let semanticWeight = 0.68

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "than", "that", "this",
        "these", "those", "is", "are", "was", "were", "be", "been", "being", "am",
        "i", "me", "my", "you", "your", "it", "its", "we", "our", "they", "them",
        "of", "to", "in", "on", "for", "with", "at", "by", "from", "as", "so",
        "just", "really", "like", "about", "up", "out", "not", "do", "did", "have",
        "has", "had", "what", "when", "where", "who", "how", "why", "can", "could",
        "would", "should", "will", "there", "here", "some", "any", "all"
    ]

    // MARK: - Vectors

    /// Must only be called while `lock` is held. `NLEmbedding` can crash when
    /// the same model instance is entered concurrently, so model creation and
    /// inference share one critical section.
    private static func modelLocked(for language: NLLanguage) -> NLEmbedding? {
        if let cached = models[language.rawValue] { return cached }
        guard let created = NLEmbedding.sentenceEmbedding(for: language) else { return nil }
        models[language.rawValue] = created
        return created
    }

    /// Sentence vector for a piece of text, or nil when the language has no
    /// on-device model. Callers fall back to keyword-only retrieval.
    ///
    /// Each language has its own model, and vectors from two models don't compare. Keep
    /// the language next to the vector and compare it only with a query embedded in that
    /// same language (`rank` does).
    static func vector(for text: String, language: NLLanguage = .english) -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Sentence embeddings are trained on roughly a sentence to a short
        // paragraph; a long ramble gets truncated rather than averaged to mush.
        let clipped = String(trimmed.prefix(600))

        // NaturalLanguage's embedding model is not safe to invoke concurrently.
        // Searches can overlap the detached backfill task, so protect the
        // inference itself, not only the model cache that hands the instance out.
        lock.lock()
        defer { lock.unlock() }
        guard let model = modelLocked(for: language),
              let vector = model.vector(for: clipped) else { return nil }
        return vector.map(Float.init)
    }

    static func encode(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// Copies rather than binding memory: cached embedding bytes
    /// carries no alignment guarantee, and binding a misaligned buffer to `Float`
    /// is undefined behaviour.
    static func decode(_ data: Data) -> [Float]? {
        guard !data.isEmpty, data.count % MemoryLayout<Float>.size == 0 else { return nil }
        var values = [Float](repeating: 0, count: data.count / MemoryLayout<Float>.size)
        _ = values.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return values
    }

    static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot: Float = 0
        var lhsMagnitude: Float = 0
        var rhsMagnitude: Float = 0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }
        let denominator = (lhsMagnitude.squareRoot() * rhsMagnitude.squareRoot())
        guard denominator > 0 else { return 0 }
        return Double(dot / denominator)
    }

    // MARK: - Keywords

    static func tokens(in text: String) -> Set<String> {
        let parts = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return Set(parts.map(String.init).filter { $0.count > 2 && !stopWords.contains($0) })
    }

    /// Share of the query's meaningful words that appear in the text, with a
    /// bonus when the query shows up verbatim.
    static func keywordScore(queryTokens: Set<String>, query: String, text: String) -> Double {
        guard !queryTokens.isEmpty else { return 0 }
        let lowered = text.lowercased()
        let textTokens = tokens(in: text)
        let overlap = Double(queryTokens.intersection(textTokens).count) / Double(queryTokens.count)
        let phraseBonus = lowered.contains(query.lowercased()) ? 0.35 : 0
        return min(1, overlap + phraseBonus)
    }

    static func blend(semantic: Double, keyword: Double, hasVector: Bool) -> Double {
        guard hasVector else { return keyword }
        return semanticWeight * semantic + (1 - semanticWeight) * keyword
    }

    /// Below this everything looks vaguely related, so a miss stays a miss.
    static let matchFloor = 0.18

    struct Ranked<ID: Hashable>: Identifiable {
        let id: ID
        let score: Double
    }

    /// A sentence vector and the language of the model that made it. Only vectors of the
    /// same language compare.
    nonisolated struct Embedded: Sendable {
        let vector: [Float]
        /// `NLLanguage.rawValue`, e.g. "en" or "zh-Hans".
        let languageCode: String

        var language: NLLanguage { NLLanguage(rawValue: languageCode) }
    }

    /// One thing to rank: its words, and its sentence vector with the language of the
    /// model that made it (nil to rank it by keywords alone).
    nonisolated struct Item<ID: Hashable> {
        let id: ID
        let text: String
        let vector: [Float]?
        let language: NLLanguage?
    }

    /// Hybrid rank over any library: stored (or cached) vectors for meaning,
    /// keyword overlap for names and rare words. The query is embedded once for each
    /// language the items' vectors are in, and each item is compared with the query in
    /// its own language: vectors from different language models don't compare.
    static func rank<ID: Hashable>(query: String, items: [Item<ID>], limit: Int = 80) -> [Ranked<ID>] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return [] }

        let queryTokens = tokens(in: trimmed)
        var queryVectors: [NLLanguage: [Float]?] = [:]
        func queryVector(in language: NLLanguage) -> [Float]? {
            if let cached = queryVectors[language] { return cached }
            let made = vector(for: trimmed, language: language)
            queryVectors[language] = .some(made)
            return made
        }

        let hits: [Ranked<ID>] = items.compactMap { item in
            var semantic = 0.0
            var hasVector = false
            if let vector = item.vector, let language = item.language, let queryVector = queryVector(in: language) {
                semantic = cosine(queryVector, vector)
                hasVector = true
            }
            let keyword = keywordScore(queryTokens: queryTokens, query: trimmed, text: item.text)
            let score = blend(semantic: semantic, keyword: keyword, hasVector: hasVector)
            guard score > matchFloor else { return nil }
            return Ranked(id: item.id, score: score)
        }

        return hits.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    /// "en", "en-US" or "es" as the embedding language; the text decides when unknown.
    /// Chinese goes by its script: "zh-Hant", "zh-TW" and "zh-HK" are traditional, other
    /// "zh" codes simplified.
    static func language(_ code: String?, for text: String) -> NLLanguage {
        if let code, !code.isEmpty {
            let lowered = code.lowercased()
            guard lowered.hasPrefix("zh") else { return NLLanguage(rawValue: String(lowered.prefix(2))) }
            let traditional = ["hant", "tw", "hk", "mo"].contains { lowered.contains($0) }
            return traditional ? .traditionalChinese : .simplifiedChinese
        }
        return NLLanguageRecognizer.dominantLanguage(for: text) ?? .english
    }
}

// MARK: - Search over muses

extension MuseSearch {
    /// Their muses closest to `query`, best first. Only the query is embedded here: muses
    /// use the vectors already made in the background (`remember`), and one without a
    /// vector yet is ranked by its words alone this time and embedded for the next search.
    /// Muses without words (still transcribing, blank) never match.
    @MainActor
    static func search(_ query: String, in muses: [Muse], limit: Int = 80) -> [Muse] {
        let searchable = muses.filter { $0.isTranscribed && !$0.isBlank }
        var uncached = false
        let items = searchable.map { muse -> Item<UUID> in
            let text = haystack(muse)
            let cached = MemoryVectors.lookup(muse.id, text)
            if cached == nil { uncached = true }
            let embedded = cached ?? nil
            return Item(id: muse.id, text: text, vector: embedded?.vector, language: embedded?.language)
        }
        if uncached { remember(searchable) }
        let byID = Dictionary(searchable.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ranked = rank(query: query, items: items, limit: limit)
        return ranked.compactMap { byID[$0.id] }
    }

    /// Embeds these muses off the main actor so later searches find them by meaning.
    /// One indexing pass at a time; muses asked for meanwhile join the next one. Call it
    /// when search opens, so the first query already has vectors.
    @MainActor
    static func remember(_ muses: [Muse]) {
        for muse in muses where muse.isTranscribed && !muse.isBlank {
            let text = haystack(muse)
            guard MemoryVectors.lookup(muse.id, text) == nil else { continue }
            MemoryVectors.waiting[muse.id] = (text, muse.language)
        }
        guard !MemoryVectors.waiting.isEmpty, !MemoryVectors.isIndexing else { return }
        MemoryVectors.isIndexing = true
        Task {
            while !MemoryVectors.waiting.isEmpty {
                let pending = MemoryVectors.waiting.map { (id: $0.key, text: $0.value.text, language: $0.value.language) }
                MemoryVectors.waiting.removeAll()
                let made = await Task.detached(priority: .utility) {
                    var result: [UUID: Embedded] = [:]
                    for item in pending {
                        let language = MuseSearch.language(item.language, for: item.text)
                        if let vector = MuseSearch.vector(for: item.text, language: language) {
                            result[item.id] = Embedded(vector: vector, languageCode: language.rawValue)
                        }
                    }
                    return result
                }.value
                for item in pending { MemoryVectors.store(item.id, item.text, made[item.id]) }
            }
            MemoryVectors.isIndexing = false
        }
    }

    /// What a search reads: the title, the notes and the words.
    private static func haystack(_ muse: Muse) -> String {
        [muse.title, muse.notes?.bullets.joined(separator: " "), muse.transcript]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

/// Sentence vectors by muse, with their language, keyed by the exact text they were made
/// from, so a retranscribed muse is embedded again. Memory only: rebuilt after a relaunch.
@MainActor
private enum MemoryVectors {
    static var isIndexing = false
    /// Muses to embed in the next indexing pass, with the text and language to use.
    static var waiting: [UUID: (text: String, language: String?)] = [:]
    private static var vectors: [UUID: (text: String, embedded: MuseSearch.Embedded?)] = [:]

    /// Nil when this text was never embedded; `.some(nil)` when it was and has no vector
    /// (a language without an on-device model), so keyword search carries it.
    static func lookup(_ id: UUID, _ text: String) -> MuseSearch.Embedded?? {
        guard let entry = vectors[id], entry.text == text else { return nil }
        return .some(entry.embedded)
    }

    static func store(_ id: UUID, _ text: String, _ embedded: MuseSearch.Embedded?) {
        vectors[id] = (text, embedded)
    }
}
