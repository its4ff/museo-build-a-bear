import AVFoundation
import Foundation
import MuseoKit
import Speech

/// One hold's words: the ring's live audio in, words out while they form. A port of museo
/// build's `LiveSpeech` (Engine/Speech).
final class HoldSpeech {
    /// What the recognizer has, so far.
    nonisolated struct Words: Equatable, Sendable {
        /// Settled: these are what gets typed.
        var heard = ""
        /// Still forming at the end; they can change.
        var hearing = ""
    }

    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    /// Nil when the ring's chunks already fit the recognizer's format.
    private let converter: AVAudioConverter?
    private let format: AVAudioFormat
    private var results: Task<String, Never>?

    private init(analyzer: SpeechAnalyzer, input: AsyncStream<AnalyzerInput>.Continuation, converter: AVAudioConverter?, format: AVAudioFormat) {
        self.analyzer = analyzer
        self.input = input
        self.converter = converter
        self.format = format
    }

    /// Starts a recognizer for a hold, or nil when this mac doesn't have the model yet.
    /// `onWords` runs on the main actor each time the words change.
    static func begin(onWords: @escaping (Words) -> Void) async -> HoldSpeech? {
        guard let module = await MacSpeech.holdTranscriber(),
              let chunkFormat = LiveAudioChunk.format() else { return nil }
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) ?? chunkFormat
        let converter = format == chunkFormat ? nil : AVAudioConverter(from: chunkFormat, to: format)
        if format != chunkFormat, converter == nil { return nil }

        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(
            modules: [module],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)
        )
        // Your words, as hints: apple's recognizer leans toward them too.
        try? await analyzer.setContext(YourWords.shared.appleContext)
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            return nil
        }
        let speech = HoldSpeech(analyzer: analyzer, input: input, converter: converter, format: format)
        speech.results = Task {
            var words = Words()
            do {
                for try await result in MacSpeech.results(of: module) {
                    let piece = result.text
                    if result.isFinal {
                        words.heard = MacSpeech.joined(words.heard, piece)
                        words.hearing = ""
                    } else {
                        words.hearing = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    onWords(words)
                }
            } catch {
                // Cancelled, or the recognizer gave up: keep what it had.
            }
            // The hold is over, so words still forming are as settled as they'll get. Apple
            // dictation can end with its last stretch never marked final; without this, those
            // holds showed words in the island and typed nothing.
            return MacSpeech.joined(words.heard, words.hearing)
        }
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

    /// The hold ended: the last words settle and come back.
    func finish() async -> String {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        return await results?.value ?? ""
    }

    /// Stops now, without settling.
    func cancel() {
        input.finish()
        results?.cancel()
        Task { [analyzer] in await analyzer.cancelAndFinishNow() }
    }
}
