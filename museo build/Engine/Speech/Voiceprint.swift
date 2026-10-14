import Accelerate
import AVFoundation
import Foundation
import Synchronization

/// A recording's loudness over time, folded into a few bars: the shape inside the
/// listen capsule. Read once per file revision and remembered for the session.
///
/// ```swift
/// let bars = Voiceprint.bars(for: url, count: 30)   // 0...1, loudest bar is 1
/// ```
nonisolated enum Voiceprint {
    private static let cache = Mutex<[String: [Float]]>([:])

    /// `count` levels from 0 to 1, the loudest bar at 1. All zeros when the audio can't
    /// be read or is silent, so a layout never jumps. Reads the file once in `count`
    /// chunks (a few milliseconds for a minute of audio); call it off the main actor
    /// for long recordings.
    static func bars(for url: URL, count: Int) -> [Float] {
        guard count > 0 else { return [] }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(url.standardizedFileURL.path)|\(modified)|\(count)"
        if let hit = cache.withLock({ $0[key] }) { return hit }

        let flat = Array(repeating: Float(0), count: count)
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return flat }
        let framesPerBar = max(1, AVAudioFrameCount(file.length / AVAudioFramePosition(count)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesPerBar) else {
            return flat
        }

        var levels: [Float] = []
        levels.reserveCapacity(count)
        for _ in 0..<count {
            do {
                try file.read(into: buffer, frameCount: framesPerBar)
            } catch {
                break
            }
            guard buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] else { break }
            var meanSquare: Float = 0
            vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(buffer.frameLength))
            levels.append(meanSquare.squareRoot())
        }
        guard let loudest = levels.max(), loudest > 0 else { return flat }
        // A short final read leaves the tail quiet rather than missing.
        levels += Array(repeating: 0, count: max(0, count - levels.count))
        let normalized = levels.map { min(1, $0 / loudest) }
        cache.withLock { cache in
            if cache.count > 256 { cache.removeAll(keepingCapacity: true) }
            cache[key] = normalized
        }
        return normalized
    }
}
