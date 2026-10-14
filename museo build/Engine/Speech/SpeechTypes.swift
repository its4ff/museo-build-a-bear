import Foundation

// The shapes the speech engine hands back. Everything here is plain data, safe to
// pass between actors and to save as JSON.

/// One spoken word and where it sits in the audio, in milliseconds from the start.
nonisolated struct TimedWord: Codable, Sendable, Hashable {
    let text: String
    let startMs: Int
    let endMs: Int
}

/// One stretch of speech, roughly a phrase or a sentence.
nonisolated struct TimedSegment: Codable, Sendable, Hashable {
    let text: String
    let startMs: Int
    let endMs: Int
}

nonisolated extension TimedWord {
    /// Start in seconds, for `AVAudioPlayer.currentTime`.
    var start: TimeInterval { TimeInterval(startMs) / 1_000 }
    /// End in seconds.
    var end: TimeInterval { TimeInterval(endMs) / 1_000 }
}

nonisolated extension TimedSegment {
    var start: TimeInterval { TimeInterval(startMs) / 1_000 }
    var end: TimeInterval { TimeInterval(endMs) / 1_000 }
}

/// One on-device pass over a muse's audio: the words, and when each was said.
///
/// The text and the timings come from the same recognizer, so `words` lines up with
/// the word-bearing tokens of `text`, one to one and in order.
nonisolated struct SpeechResult: Sendable {
    /// Punctuated text, with paragraph breaks where the speaker paused after a
    /// sentence. Empty when nothing was said.
    let text: String
    /// One entry per word of `text` (tokens with a letter or digit), in order.
    let words: [TimedWord]
    /// One entry per phrase (Apple) or sentence (Voz).
    let segments: [TimedSegment]
    /// The language the words came out in, as an ISO code: "en", "es".
    let language: String?
    /// Mean word confidence 0...1 from Apple speech. Nil from Voz, or when none was reported.
    let confidence: Double?
    /// Which recognizer wrote the words: "apple-speech", "apple-dictation", "voz-0.1.0".
    let textModel: String
    /// Which model timed them: the text model, which times its own words. Muses from
    /// before Align was removed can read "apple-speech+align-3.5.0".
    let timingModel: String
}

nonisolated extension SpeechResult {
    /// True when the recognizer heard no words at all.
    var isEmpty: Bool { words.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Why a transcription didn't land.
nonisolated enum SpeechError: LocalizedError {
    /// The language model isn't on this iphone yet and couldn't be fetched (usually
    /// offline). Retryable: the muse stays pending and is tried again later.
    case assetsUnavailable
    /// Neither Apple recognizer handles this language on this iphone.
    case unsupportedLanguage
    /// The audio file is missing, empty or damaged.
    case unreadableAudio

    var errorDescription: String? {
        switch self {
        case .assetsUnavailable:
            "this language isn't on this iphone yet. it downloads next time you're online."
        case .unsupportedLanguage:
            "this iphone can't transcribe this language yet."
        case .unreadableAudio:
            "this recording couldn't be read."
        }
    }

    /// Whether the muse should stay pending and be tried again later, rather than be
    /// marked failed.
    var isRetryable: Bool {
        switch self {
        case .assetsUnavailable: true
        case .unsupportedLanguage, .unreadableAudio: false
        }
    }
}
