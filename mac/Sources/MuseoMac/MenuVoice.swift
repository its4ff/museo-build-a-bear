import AppKit
import Foundation
import Observation

/// How loud the hold is, for the menu bar pill and the flow bar: the last five readings of
/// the ring's audio, 0 to 1, newest on the right. `Dictation` hands it each chunk of a hold.
@MainActor
@Observable
final class MenuVoice {
    static let shared = MenuVoice()

    nonisolated static let bars = 5
    /// Quiet: low, even bars, so the pill reads as listening before you speak.
    private static let resting: [Double] = [0.15, 0.3, 0.45, 0.3, 0.15]

    private(set) var levels = MenuVoice.resting

    /// About 100 ms more of the hold.
    func hear(_ samples: [Int16]) {
        // Reduce Motion: the pill shows, the bars hold still.
        guard !samples.isEmpty, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        var sum = 0.0
        for sample in samples {
            let value = Double(sample) / 32_768
            sum += value * value
        }
        let rms = (sum / Double(samples.count)).squareRoot()
        // Speech into the ring sits around 0.02 to 0.08 rms; lift it into 0 to 1.
        let level = min(1, pow(rms * 14, 0.7))
        levels = Array((levels + [max(0.12, level)]).suffix(Self.bars))
    }

    /// A hold ended (or began): back to rest.
    func reset() {
        levels = Self.resting
    }
}
