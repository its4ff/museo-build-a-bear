import AVFoundation
import Foundation
import MuseoKit
import Speech

/// One hold's words as they form, on this iphone: the ring's live audio in (`Museo.liveAudio()`),
/// words out while they're still settling. `LiveWords` makes one per hold.
///
/// These words are for the screen. The saved recording is still transcribed as usual once
/// the muse lands, for its word timings and the most careful words.
final class LiveSpeech {
    /// What the recognizer has, so far.
    nonisolated struct Words: Equatable, Sendable {
        /// Words it has settled on.
        var heard = ""
        /// Words still forming at the end; they can change.
        var hearing = ""
    }

    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    /// Nil when the ring's chunks already fit the recognizer's format.
    private let converter: AVAudioConverter?
    private let format: AVAudioFormat
    private var results: Task<Void, Never>?

    private init(
        analyzer: SpeechAnalyzer,
        input: AsyncStream<AnalyzerInput>.Continuation,
        converter: AVAudioConverter?,
        format: AVAudioFormat
    ) {
        self.analyzer = analyzer
        self.input = input
        self.converter = converter
        self.format = format
    }

    /// Starts a recognizer for a hold, or nil when this iphone doesn't have the model for
    /// its language yet. `onWords` runs on the main actor each time the words change.
    static func begin(onWords: @escaping (Words) -> Void) async -> LiveSpeech? {
        guard let module = await SpeechEngine.shared.liveTranscriber(),
              let chunkFormat = LiveAudioChunk.format() else { return nil }
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) ?? chunkFormat
        let converter = format == chunkFormat ? nil : AVAudioConverter(from: chunkFormat, to: format)
        if format != chunkFormat, converter == nil { return nil }

        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(
            modules: [module],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)
        )
        let context = AnalysisContext()
        context.contextualStrings[.general] = SpeechEngine.vocabulary
        try? await analyzer.setContext(context)
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            return nil
        }
        let speech = LiveSpeech(analyzer: analyzer, input: input, converter: converter, format: format)
        speech.results = Task { await Self.collect(module, onWords: onWords) }
        return speech
    }

    /// Hands the recognizer the next stretch of the hold. Call in order.
    func feed(_ chunk: LiveAudioChunk) {
        guard let buffer = chunk.buffer() else { return }
        guard let converter else {
            input.yield(AnalyzerInput(buffer: buffer))
            return
        }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var handedOver = false
        var error: NSError?
        _ = converter.convert(to: converted, error: &error) { _, status in
            if handedOver {
                status.pointee = .noDataNow
                return nil
            }
            handedOver = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, converted.frameLength > 0 {
            input.yield(AnalyzerInput(buffer: converted))
        }
    }

    /// The hold ended: the last words settle, then the recognizer stops.
    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        await results?.value
    }

    /// Stops now, without settling (a new hold began, or the app left the screen).
    func cancel() {
        input.finish()
        results?.cancel()
        Task { [analyzer] in await analyzer.cancelAndFinishNow() }
    }

    // MARK: - Results

    private static func collect(_ module: any SpeechModule, onWords: @escaping (Words) -> Void) async {
        var words = Words()
        func take(_ text: AttributedString, isFinal: Bool) {
            let piece = String(text.characters)
            if isFinal {
                words.heard = Self.joined(words.heard, piece)
                words.hearing = ""
            } else {
                words.hearing = piece
            }
            onWords(words)
        }
        do {
            if let transcriber = module as? SpeechTranscriber {
                for try await result in transcriber.results { take(result.text, isFinal: result.isFinal) }
            } else if let transcriber = module as? DictationTranscriber {
                for try await result in transcriber.results { take(result.text, isFinal: result.isFinal) }
            }
        } catch {
            // Cancelled, or the recognizer gave up: the words so far stay on screen.
        }
    }

    /// Settled pieces, one space between them.
    private static func joined(_ heard: String, _ piece: String) -> String {
        let piece = piece.trimmingCharacters(in: .whitespaces)
        guard !piece.isEmpty else { return heard }
        return heard.isEmpty ? piece : heard + " " + piece
    }
}
