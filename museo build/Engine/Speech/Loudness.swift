import AVFoundation
import Foundation
import Synchronization

/// How loud a recording is (ITU-R BS.1770 integrated loudness, in LUFS), and how much
/// gain brings it to an even listening level. The file itself is never changed: the
/// player applies the gain.
///
/// ```swift
/// let gain = Loudness.playbackGainDb(integratedLufs: Loudness.measure(url))
/// eq.globalGain = gain   // AVAudioUnitEQ in the playback graph
/// ```
nonisolated enum Loudness {
    /// Where every muse lands at playback: the level podcasts and voice apps use.
    static let targetLUFS = -16.0
    /// Never quieter than this.
    static let minGainDB = -9.0
    /// Never louder than this. Players limit peaks after the gain, and lifting a clean
    /// but quiet recording doesn't change how it sounds otherwise.
    static let maxBoostDB = 18.0

    private struct Key: Hashable {
        let path: String
        let size: Int
        let modified: TimeInterval
    }

    /// Measurements by file revision. NaN marks "measured, nothing to go by".
    private static let cache = Mutex<[Key: Double]>([:])

    /// Integrated loudness in LUFS, or nil when the file can't be read or is silent.
    /// Reads the file in short chunks (flat memory for any length) and remembers the
    /// answer per file revision. Takes a few milliseconds per minute of audio; call it
    /// off the main actor for long recordings.
    static func measure(_ url: URL) -> Double? {
        let key = key(for: url)
        if let key, let hit = cache.withLock({ $0[key] }) {
            return hit.isNaN ? nil : hit
        }
        let value = integratedLUFS(url)
        if let key {
            cache.withLock { cache in
                if cache.count > 512 { cache.removeAll(keepingCapacity: true) }
                cache[key] = value ?? .nan
            }
        }
        return value
    }

    /// Gain in dB that brings a recording to `targetLUFS`, clamped to
    /// `minGainDB...maxBoostDB`. Ring muses are levelled fully: the ring's chain already
    /// flattened whisper against raised voice. Nil (unmeasured) plays as recorded.
    static func playbackGainDb(integratedLufs: Double?) -> Float {
        guard let integratedLufs, integratedLufs.isFinite else { return 0 }
        return Float(max(minGainDB, min(maxBoostDB, targetLUFS - integratedLufs)))
    }

    // MARK: - BS.1770

    private static func key(for url: URL) -> Key? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize
        else { return nil }
        return Key(
            path: url.standardizedFileURL.path,
            size: size,
            modified: values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        )
    }

    /// K-weighting, 400 ms blocks every 100 ms, absolute gate at -70 LUFS, relative gate
    /// 10 LU under the gated mean.
    private static func integratedLUFS(_ url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let hop = Int(sampleRate * 0.1)
        guard hop > 0, channels > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(hop * 10))
        else { return nil }

        var filters = Array(repeating: KWeighting(sampleRate: sampleRate), count: channels)
        // Sum of squared, weighted samples (all channels) for each 100 ms hop.
        var hops: [Double] = []
        hops.reserveCapacity(Int(file.length) / hop + 1)
        var sum = 0.0
        var inHop = 0

        while file.framePosition < file.length {
            do {
                try file.read(into: buffer, frameCount: buffer.frameCapacity)
            } catch {
                break
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let data = buffer.floatChannelData else { break }
            for frame in 0..<frames {
                for channel in 0..<channels {
                    let weighted = filters[channel].process(Double(data[channel][frame]))
                    sum += weighted * weighted
                }
                inHop += 1
                if inHop == hop {
                    hops.append(sum)
                    sum = 0
                    inHop = 0
                }
            }
        }

        // A 400 ms block is four hops.
        guard hops.count >= 4 else { return nil }
        let blockFrames = Double(hop * 4)
        var blocks: [Double] = []
        blocks.reserveCapacity(hops.count - 3)
        for index in 0...(hops.count - 4) {
            let meanSquare = (hops[index] + hops[index + 1] + hops[index + 2] + hops[index + 3]) / blockFrames
            if meanSquare > 0 { blocks.append(meanSquare) }
        }

        func loudness(_ meanSquare: Double) -> Double { -0.691 + 10 * log10(meanSquare) }

        let gated = blocks.filter { loudness($0) >= -70 }
        guard !gated.isEmpty else { return nil }
        let relative = loudness(gated.reduce(0, +) / Double(gated.count)) - 10
        let kept = gated.filter { loudness($0) >= relative }
        let used = kept.isEmpty ? gated : kept
        let integrated = loudness(used.reduce(0, +) / Double(used.count))
        return integrated.isFinite && integrated > -120 ? integrated : nil
    }

    /// The two BS.1770 pre-filters (a high shelf, then a high pass), with state, so a
    /// file can stream through in chunks.
    private struct KWeighting {
        var shelf: Biquad
        var highPass: Biquad

        init(sampleRate fs: Double) {
            let f0 = 1681.974450955533
            let g = 3.999843853973347
            let q1 = 0.7071752369554196
            let k1 = tan(Double.pi * f0 / fs)
            let vh = pow(10.0, g / 20.0)
            let vb = pow(vh, 0.4996667741545416)
            let a0 = 1 + k1 / q1 + k1 * k1
            shelf = Biquad(
                b0: (vh + vb * k1 / q1 + k1 * k1) / a0,
                b1: 2 * (k1 * k1 - vh) / a0,
                b2: (vh - vb * k1 / q1 + k1 * k1) / a0,
                a1: 2 * (k1 * k1 - 1) / a0,
                a2: (1 - k1 / q1 + k1 * k1) / a0
            )

            let f0b = 38.13547087602444
            let q2 = 0.5003270373238773
            let k2 = tan(Double.pi * f0b / fs)
            let a0b = 1 + k2 / q2 + k2 * k2
            highPass = Biquad(
                b0: 1,
                b1: -2,
                b2: 1,
                a1: 2 * (k2 * k2 - 1) / a0b,
                a2: (1 - k2 / q2 + k2 * k2) / a0b
            )
        }

        mutating func process(_ x: Double) -> Double {
            highPass.process(shelf.process(x))
        }
    }

    private struct Biquad {
        let b0, b1, b2, a1, a2: Double
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
            self.b0 = b0
            self.b1 = b1
            self.b2 = b2
            self.a1 = a1
            self.a2 = a2
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }
}
