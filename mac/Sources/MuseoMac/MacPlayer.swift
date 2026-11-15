import AVFoundation
import Foundation
import Observation

/// Plays one muse's audio. One per open muse.
@MainActor
@Observable
final class MacPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    /// 0 to 1, for the bar.
    private(set) var progress: Double = 0

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Timer?

    init(url: URL) {
        super.init()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
    }

    var canPlay: Bool { player != nil }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            stopTicking()
        } else {
            player.play()
            startTicking()
        }
        isPlaying = player.isPlaying
    }

    func stop() {
        player?.stop()
        stopTicking()
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopTicking()
            self.isPlaying = false
            self.progress = 0
            self.player?.currentTime = 0
        }
    }

    private func startTicking() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
