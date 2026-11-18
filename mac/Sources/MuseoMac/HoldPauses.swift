import Foundation

/// Where a hold went quiet. A command said at the edge of a hold only counts when a real
/// pause sets it apart from the sentence ("…that's the plan. [pause] new tab"), so
/// "let's open a new tab" inside a sentence never runs anything. Measured from the hold's
/// own audio, so it doesn't lean on any speech model's timings.
nonisolated struct HoldPauses: Sendable, Equatable {
    /// How long the first stretch of talking lasted, when a pause follows it.
    var leading: TimeInterval?
    /// How long the last stretch of talking lasted, when a pause comes before it.
    var trailing: TimeInterval?

    /// The quiet that counts as a pause. Gaps between words in one breath are well under it.
    static let pause: TimeInterval = 0.45
    /// One slice of audio, and the shortest sound that counts as talking.
    private static let slice: TimeInterval = 0.02
    private static let shortest: TimeInterval = 0.1
    /// Talking is louder than this share of the hold's loud moments.
    private static let floorShare: Float = 0.12

    init(leading: TimeInterval? = nil, trailing: TimeInterval? = nil) {
        self.leading = leading
        self.trailing = trailing
    }

    /// From a hold's samples at `rate` hertz.
    init(samples: [Int16], rate: Double = 16_000) {
        let size = max(1, Int(rate * Self.slice))
        guard samples.count >= size * 4 else { return }
        // How loud each slice is.
        var levels: [Float] = []
        levels.reserveCapacity(samples.count / size)
        var start = 0
        while start + size <= samples.count {
            var sum: Float = 0
            for index in start..<(start + size) {
                let sample = Float(samples[index])
                sum += sample * sample
            }
            levels.append((sum / Float(size)).squareRoot())
            start += size
        }
        // Loud is judged against this hold's own loud moments: the ring records quietly.
        let sorted = levels.sorted()
        let loud = sorted[min(sorted.count - 1, Int(Float(sorted.count) * 0.95))]
        guard loud > 0 else { return }
        let floor = loud * Self.floorShare
        // Stretches of talking, joined across anything shorter than a pause.
        let pauseSlices = Int(Self.pause / Self.slice)
        var runs: [(from: Int, to: Int)] = []
        for (index, level) in levels.enumerated() where level > floor {
            if let last = runs.last, index - last.to <= pauseSlices {
                runs[runs.count - 1].to = index
            } else {
                runs.append((index, index))
            }
        }
        // A click or a breath isn't a stretch of talking.
        let shortest = Int(Self.shortest / Self.slice)
        runs.removeAll { $0.to - $0.from + 1 < shortest }
        guard runs.count >= 2, let first = runs.first, let last = runs.last else { return }
        leading = Double(first.to - first.from + 1) * Self.slice
        trailing = Double(last.to - last.from + 1) * Self.slice
    }

    /// A stretch this long could be `words` words said as a command, and nothing more.
    static func fits(_ length: TimeInterval?, words: Int) -> Bool {
        guard let length else { return false }
        return length >= 0.12 && length <= 0.5 + 0.5 * Double(words)
    }
}
