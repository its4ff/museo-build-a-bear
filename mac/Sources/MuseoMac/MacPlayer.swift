import AVFoundation
import Foundation
import Observation

/// Plays one muse's audio at an even level, like museo build's `MuseAudioPlayer`: player →
/// gain (`Loudness`, toward -16 LUFS) → peak limiter → speakers. The ring records quietly,
/// so most muses are lifted; the file itself never changes. One per open muse.
@MainActor
@Observable
final class MacPlayer {
    private(set) var isPlaying = false
    /// 0 to 1, for the bar.
    private(set) var progress: Double = 0
    /// The recording's shape for the waveform: loudest moment in each of `bins` stretches,
    /// 0 to 1. Empty until read.
    private(set) var peaks: [Double] = []

    nonisolated static let bins = 56

    @ObservationIgnored private let file: AVAudioFile?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let node = AVAudioPlayerNode()
    @ObservationIgnored private let gain = AVAudioUnitEQ(numberOfBands: 0)
    @ObservationIgnored private let limiter: AVAudioUnitEffect
    /// Something is scheduled on the node (playing or paused mid-way).
    @ObservationIgnored private var scheduled = false
    /// Which play the finish callback belongs to, so a stop never ends a newer one.
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var ticker: Timer?

    init(url: URL) {
        file = try? AVAudioFile(forReading: url)
        var description = AudioComponentDescription()
        description.componentType = kAudioUnitType_Effect
        description.componentSubType = kAudioUnitSubType_PeakLimiter
        description.componentManufacturer = kAudioUnitManufacturer_Apple
        limiter = AVAudioUnitEffect(audioComponentDescription: description)
        engine.attach(node)
        engine.attach(gain)
        engine.attach(limiter)
        if let format = file?.processingFormat {
            engine.connect(node, to: gain, format: format)
            engine.connect(gain, to: limiter, format: format)
            engine.connect(limiter, to: engine.mainMixerNode, format: format)
        }
        // Measured off the main actor; a few ms a minute of audio.
        Task { [gain] in
            let lufs = await Task.detached { Loudness.measure(url) }.value
            gain.globalGain = Loudness.playbackGainDb(integratedLufs: lufs)
        }
        Task {
            peaks = await Task.detached { Self.readPeaks(url) }.value
        }
    }

    /// The loudest sample in each stretch, normalized to the loudest stretch.
    nonisolated private static func readPeaks(_ url: URL) -> [Double] {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16_384) else { return [] }
        let per = max(1, Int(file.length) / bins)
        var peaks = [Float](repeating: 0, count: bins)
        var frame = 0
        while (try? file.read(into: buffer)) != nil, buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] {
            for i in 0..<Int(buffer.frameLength) {
                let bin = min(bins - 1, (frame + i) / per)
                peaks[bin] = max(peaks[bin], abs(samples[i]))
            }
            frame += Int(buffer.frameLength)
        }
        let top = max(peaks.max() ?? 0, 0.0001)
        return peaks.map { Double($0 / top) }
    }

    var canPlay: Bool { file != nil }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func stop() {
        run += 1
        node.stop()
        engine.stop()
        scheduled = false
        isPlaying = false
        progress = 0
        stopTicking()
    }

    // MARK: - Playing

    private func play() {
        guard let file else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        if !scheduled {
            run += 1
            let this = run
            file.framePosition = 0
            node.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in
                Task { @MainActor [weak self] in self?.finished(this) }
            }
            scheduled = true
        }
        node.play()
        isPlaying = true
        startTicking()
    }

    private func pause() {
        node.pause()
        isPlaying = false
        stopTicking()
    }

    private func finished(_ this: Int) {
        guard this == run else { return }
        scheduled = false
        isPlaying = false
        progress = 0
        node.stop()
        stopTicking()
    }

    // MARK: - Progress

    private func startTicking() {
        stopTicking()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let file, file.length > 0,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else { return }
        progress = min(1, max(0, Double(playerTime.sampleTime) / Double(file.length)))
    }
}
