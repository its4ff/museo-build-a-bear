import AVFoundation
import CryptoKit
import Foundation
import Synchronization

/// Cheap questions about an audio file, answered without decoding it all.
///
/// ```swift
/// if AudioCheck.isIntact(url) { … }
/// let seconds = AudioCheck.duration(url) ?? 0
/// ```
nonisolated enum AudioCheck {
    /// The file opens, holds audio, and holds at least the bytes its header promises.
    /// A recording killed before its header was written fails the last test, and would
    /// otherwise send readers past the end of the file.
    static func isIntact(_ url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return false }
        let bytesPerFrame = Int64(file.fileFormat.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return true } // compressed: nothing to compare
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return size >= file.length * bytesPerFrame
    }

    /// Length in seconds, from the header. Nil when the file can't be opened.
    static func duration(_ url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let rate = file.fileFormat.sampleRate
        guard rate > 0 else { return nil }
        return TimeInterval(file.length) / rate
    }

    // MARK: - Fingerprint

    private struct HashKey: Hashable {
        let path: String
        let size: Int
        let modified: TimeInterval
    }

    private static let hashes = Mutex<[HashKey: String]>([:])

    /// SHA-256 of the file, hex. Remembered by path, size and modification date, so
    /// asking twice reads the file once and an edited file is never served stale.
    static func sha256(_ url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize
        else { return nil }
        let key = HashKey(
            path: url.standardizedFileURL.path,
            size: size,
            modified: values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        )
        if let hit = hashes.withLock({ $0[key] }) { return hit }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        hashes.withLock { cache in
            if cache.count > 2_048 { cache.removeAll(keepingCapacity: true) }
            cache[key] = hash
        }
        return hash
    }

    // MARK: - Samples

    /// The file as mono Float32 samples at `sampleRate`, optionally only its first
    /// `maxSeconds`. Reads the whole span into memory, so keep it to muse-sized audio.
    static func monoSamples(_ url: URL, sampleRate: Double, maxSeconds: Double? = nil) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw SpeechError.unreadableAudio
        }
        let input = file.processingFormat
        var frames = file.length
        if let maxSeconds { frames = min(frames, AVAudioFramePosition(maxSeconds * input.sampleRate)) }
        guard frames > 0,
              let output = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: sampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let converter = AVAudioConverter(from: input, to: output),
              let source = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: AVAudioFrameCount(frames))
        else { throw SpeechError.unreadableAudio }
        // A stereo file (an imported one) folds both sides in rather than dropping one.
        converter.downmix = true
        try file.read(into: source, frameCount: AVAudioFrameCount(frames))

        let capacity = AVAudioFrameCount(Double(source.frameLength) * sampleRate / input.sampleRate) + 4_096
        guard let destination = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else {
            throw SpeechError.unreadableAudio
        }
        let feed = ConverterFeed(source)
        var conversionError: NSError?
        let status = converter.convert(to: destination, error: &conversionError) { _, inputStatus in
            guard let buffer = feed.take() else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channel = destination.floatChannelData?[0] else {
            throw conversionError ?? SpeechError.unreadableAudio
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(destination.frameLength)))
    }
}

/// Hands the converter its one source buffer from inside the converter's own
/// (synchronous, same-thread) input callback, exactly once.
nonisolated private final class ConverterFeed: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
