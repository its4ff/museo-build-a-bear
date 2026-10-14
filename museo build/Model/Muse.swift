import Foundation
import MuseoKit

/// Where a muse came from. The ring gives `.stream` and `.offline`; `.typed` and `.sample`
/// are the app's ways to make one without the ring.
nonisolated enum MuseOrigin: String, Codable, Sendable, CaseIterable {
    /// Streamed from the ring to this phone while you hold it.
    case stream
    /// Recorded on the ring's flash while the phone was away, brought in later.
    case offline
    /// Typed (`MusePipeline.addTyped`). Skips transcription; titled like any muse.
    case typed
    /// A fixture muse (lab screens, `MusePipeline.loadSamples()`).
    case sample

    init(_ source: CaptureSource) {
        switch source {
        case .stream: self = .stream
        case .offline: self = .offline
        }
    }

    var isRing: Bool { self == .stream || self == .offline }

    /// Short lowercase line for cards and details: "from the ring".
    var label: String {
        switch self {
        case .stream: "from the ring"
        case .offline: "synced from the ring"
        case .typed: "typed"
        case .sample: "sample"
        }
    }

    /// SF Symbol for the origin. Ring origins draw `MuseRingMark` instead in the UI.
    var symbol: String {
        switch self {
        case .stream, .offline: "circle.circle"
        case .typed: "keyboard"
        case .sample: "sparkle"
        }
    }
}

nonisolated enum TranscriptionState: String, Codable, Sendable {
    case pending
    case transcribing
    case complete
    case failed
}

/// One thing you said into the ring. Stored as JSON by `MuseStore`.
///
/// Adding a field: give it a default and decode it with `decodeIfPresent` in
/// `init(from:)` below, or older saves stop loading.
nonisolated struct Muse: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    /// When you started speaking (the ring's clock for offline muses).
    var createdAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var origin: MuseOrigin

    var transcript: String?
    var transcriptionState: TranscriptionState
    var transcriptionError: String?
    /// A short title. On-device model when available, else nil (UI falls back to the first line).
    var title: String?
    /// The person wrote or changed the title on the muse page. The model never replaces it.
    var titleIsTheirs: Bool
    /// Notes from the on-device model for longer muses (150 words and up). See `MuseNotes`.
    var notes: MuseNotes?
    /// BCP-47 language the words came out in, e.g. "en" or "es".
    var language: String?
    /// Mean word confidence from the recognizer, 0...1, when it reported one.
    var wordConfidence: Double?
    /// Which engine wrote the words: "apple-speech", "apple-dictation", "voz-…", "typed".
    var textModel: String?
    /// True when the audio held no real words ("blank muse"). The muse and its audio are kept.
    var isBlank: Bool

    /// 16 kHz mono wav, in `MuseFiles.audio`.
    var audioFileName: String?
    /// The ring's original file (.ogg streamed, .ops offline), kept next to the wav. Deleted with the muse.
    var sourceFileName: String?

    /// When this muse landed on this phone. Drives the arrival animation and the "new" mark.
    var arrivedAt: Date
    /// Which of the ring's 30-minute files it holds (memory muses from a dated ring file).
    /// `MuseJoiner` folds a long recording's parts into one muse by it.
    var ringParts: RingParts?

    init(
        id: UUID = UUID(),
        createdAt: Date,
        endedAt: Date? = nil,
        duration: TimeInterval,
        origin: MuseOrigin,
        transcript: String? = nil,
        transcriptionState: TranscriptionState = .pending,
        transcriptionError: String? = nil,
        title: String? = nil,
        titleIsTheirs: Bool = false,
        notes: MuseNotes? = nil,
        language: String? = nil,
        wordConfidence: Double? = nil,
        textModel: String? = nil,
        isBlank: Bool = false,
        audioFileName: String? = nil,
        sourceFileName: String? = nil,
        arrivedAt: Date = .now,
        ringParts: RingParts? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.endedAt = endedAt ?? createdAt.addingTimeInterval(duration)
        self.duration = duration
        self.origin = origin
        self.transcript = transcript
        self.transcriptionState = transcriptionState
        self.transcriptionError = transcriptionError
        self.title = title
        self.titleIsTheirs = titleIsTheirs
        self.notes = notes
        self.language = language
        self.wordConfidence = wordConfidence
        self.textModel = textModel
        self.isBlank = isBlank
        self.audioFileName = audioFileName
        self.sourceFileName = sourceFileName
        self.arrivedAt = arrivedAt
        self.ringParts = ringParts
    }

    // MARK: - Files

    var audioURL: URL? {
        guard let audioFileName else { return nil }
        let url = MuseFiles.audio.appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var sourceURL: URL? {
        sourceFileName.map { MuseFiles.audio.appendingPathComponent($0) }
    }

    // MARK: - Display

    /// Their words, trimmed. Empty when nothing has landed yet.
    var words: String {
        transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Title, else the first line of the words, else "blank muse".
    var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let text = words
        guard !text.isEmpty, !isBlank else { return "blank muse" }
        return String(text.split(whereSeparator: \.isNewline).first ?? Substring(text))
    }

    var isTranscribed: Bool { transcriptionState == .complete }

    /// How many words they said. Zero until the words land. Chinese, Japanese and Thai,
    /// written without spaces, are counted by the word tokenizer (`MuseWordParts.wordCount`).
    var wordCount: Int {
        MuseWordParts.wordCount(words)
    }

    /// The notes this muse should have from its words (`MuseNotes.kind(forWordCount:)`),
    /// or nil when it's short, blank or has no words yet.
    var expectedNotes: MuseNotes.Kind? {
        guard isTranscribed, !isBlank else { return nil }
        return MuseNotes.kind(forWordCount: wordCount)
    }

    /// Landed in the last `seconds`. The home types the words in for fresh muses only.
    func isFresh(within seconds: TimeInterval = 90, now: Date = .now) -> Bool {
        now.timeIntervalSince(arrivedAt) < seconds
    }

    /// Recognizers sometimes hear words in silence ("thank you", "you"). Those
    /// muses are kept and marked blank, never deleted.
    static func isBlankTranscript(_ text: String?) -> Bool {
        guard let text else { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return true }
        let normalized = trimmed.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let artifacts: Set<String> = [
            "you", "thank you", "thanks", "thank you so much", "thanks so much",
            "bye", "bye bye", "goodbye", "okay", "ok", "hmm", "um", "uh", "huh", "oh",
            "silence", "music", "applause", "laughter", "noise",
        ]
        return normalized.isEmpty || artifacts.contains(normalized)
    }

    // MARK: - Codable (resilient)

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, endedAt, duration, origin
        case transcript, transcriptionState, transcriptionError, title, titleIsTheirs, notes, language
        case wordConfidence, textModel, isBlank, audioFileName, sourceFileName, arrivedAt, ringParts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt) ?? createdAt.addingTimeInterval(duration)
        origin = (try? c.decodeIfPresent(MuseOrigin.self, forKey: .origin)) ?? .stream
        transcript = try c.decodeIfPresent(String.self, forKey: .transcript)
        transcriptionState = (try? c.decodeIfPresent(TranscriptionState.self, forKey: .transcriptionState)) ?? .pending
        transcriptionError = try c.decodeIfPresent(String.self, forKey: .transcriptionError)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        titleIsTheirs = (try? c.decodeIfPresent(Bool.self, forKey: .titleIsTheirs)) ?? false
        notes = try? c.decodeIfPresent(MuseNotes.self, forKey: .notes)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        wordConfidence = try c.decodeIfPresent(Double.self, forKey: .wordConfidence)
        textModel = try c.decodeIfPresent(String.self, forKey: .textModel)
        isBlank = try c.decodeIfPresent(Bool.self, forKey: .isBlank) ?? false
        audioFileName = try c.decodeIfPresent(String.self, forKey: .audioFileName)
        sourceFileName = try c.decodeIfPresent(String.self, forKey: .sourceFileName)
        arrivedAt = try c.decodeIfPresent(Date.self, forKey: .arrivedAt) ?? createdAt
        ringParts = try? c.decodeIfPresent(RingParts.self, forKey: .ringParts)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encode(duration, forKey: .duration)
        try c.encode(origin, forKey: .origin)
        try c.encodeIfPresent(transcript, forKey: .transcript)
        try c.encode(transcriptionState, forKey: .transcriptionState)
        try c.encodeIfPresent(transcriptionError, forKey: .transcriptionError)
        try c.encodeIfPresent(title, forKey: .title)
        if titleIsTheirs { try c.encode(titleIsTheirs, forKey: .titleIsTheirs) }
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encodeIfPresent(wordConfidence, forKey: .wordConfidence)
        try c.encodeIfPresent(textModel, forKey: .textModel)
        try c.encode(isBlank, forKey: .isBlank)
        try c.encodeIfPresent(audioFileName, forKey: .audioFileName)
        try c.encodeIfPresent(sourceFileName, forKey: .sourceFileName)
        try c.encode(arrivedAt, forKey: .arrivedAt)
        try c.encodeIfPresent(ringParts, forKey: .ringParts)
    }
}

/// Where the app keeps files. Ring audio lands in the kit's captures folder, and every
/// muse resolves its audio there.
nonisolated enum MuseFiles {
    /// `Documents/MuseBuildCaptures/` (the ring kit's folder). Created on demand.
    static var audio: URL {
        let url = RingBLEManager.capturesDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `Documents/MuseBuild/`: muses.json and exports.
    static var library: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MuseBuild", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `Application Support/MuseBuild/<name>/`: sidecars and model files, never user-visible.
    static func support(_ name: String) -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MuseBuild", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
