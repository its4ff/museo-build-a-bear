import AppKit
import SwiftUI

/// The ink on a note's page. Words from a hold soak in: each fills left to right, a beat
/// after the one before. Typed letters bloom. Words taken back drain the other way before
/// they go. All of it is color laid over the text by the layout manager, never the text
/// itself, so nothing here is saved, undone or copied.
@MainActor
final class NoteInk {
    private struct Run {
        var range: NSRange
        var start: CFTimeInterval
        var length: CFTimeInterval
        /// Ink leaving, right to left, instead of arriving.
        var drains = false
        /// The whole range at once, no sweep: typed letters, and Reduce Motion.
        var plain = false
    }

    private weak var textView: NSTextView?
    private var runs: [Run] = []
    private var timer: Timer?
    private var whenDrained: (() -> Void)?

    /// Words still forming, and where landing ink starts from.
    static let soft = NSColor(MuseColor.ink55).withAlphaComponent(0.7)
    private static let softParts = parts(soft)
    private static let inkParts = parts(NSColor(MuseColor.ink))
    /// How many letters wide the wet edge of a filling word is.
    private static let edge = 3.0

    init(_ textView: NSTextView) { self.textView = textView }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    // MARK: - Arriving and leaving

    /// A hold's words, just put in at `range`: they soak in, word after word. A long hold
    /// lands as fast as a short one.
    func land(_ range: NSRange) {
        let now = CACurrentMediaTime()
        if reduceMotion {
            runs.append(Run(range: range, start: now, length: 0.25, plain: true))
        } else {
            let words = words(in: range)
            let beat = min(0.07, 1.6 / Double(max(words.count, 1)))
            for (index, word) in words.enumerated() {
                runs.append(Run(range: word, start: now + Double(index) * beat, length: 0.6))
            }
        }
        begin()
    }

    /// Letters just typed at `range`.
    func bloom(_ range: NSRange) {
        runs.append(Run(range: range, start: CACurrentMediaTime(), length: 0.22, plain: true))
        begin()
    }

    /// The ink leaves `range`, last word first, then `done` takes the words away.
    func drain(_ range: NSRange, then done: @escaping () -> Void) {
        settle(from: 0)
        let now = CACurrentMediaTime()
        if reduceMotion {
            runs.append(Run(range: range, start: now, length: 0.2, drains: true, plain: true))
        } else {
            let words = words(in: range)
            let beat = min(0.045, 0.9 / Double(max(words.count, 1)))
            for (index, word) in words.reversed().enumerated() {
                runs.append(Run(range: word, start: now + Double(index) * beat, length: 0.4, drains: true))
            }
        }
        whenDrained = done
        begin()
    }

    /// The text is about to change at `location`: ink still moving there or after it is
    /// simply ink now, and a drain under way is called off (the words stay).
    func settle(from location: Int) {
        guard !runs.isEmpty else { return }
        let moved = runs.filter { NSMaxRange($0.range) > location }
        guard !moved.isEmpty else { return }
        runs.removeAll { NSMaxRange($0.range) > location }
        moved.forEach(clear)
        if moved.contains(where: \.drains) { whenDrained = nil }
        if runs.isEmpty { stop() }
    }

    #if DEBUG
    /// For `ScreenSheet`: `range` as it looks `seconds` into landing, held there.
    func still(_ range: NSRange, at seconds: CFTimeInterval) {
        let now = CACurrentMediaTime() - seconds
        for (index, word) in words(in: range).enumerated() {
            runs.append(Run(range: word, start: now + Double(index) * 0.07, length: 0.6))
        }
        paint(at: CACurrentMediaTime())
        runs = []
    }
    #endif

    // MARK: - Painting

    private func begin() {
        paint(at: CACurrentMediaTime())
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func step() {
        let now = CACurrentMediaTime()
        paint(at: now)
        // Arrived ink is the text's own color again. Drained words stay clear until all are.
        let arrived = runs.filter { !$0.drains && now >= $0.start + $0.length }
        runs.removeAll { !$0.drains && now >= $0.start + $0.length }
        arrived.forEach(clear)
        guard runs.allSatisfy({ now >= $0.start + $0.length }) else { return }
        let drained = runs
        let done = whenDrained
        runs = []
        whenDrained = nil
        stop()
        drained.forEach(clear)
        done?()
    }

    private func paint(at now: CFTimeInterval) {
        guard let layout = textView?.layoutManager, let length = textView?.textStorage?.length else { return }
        for run in runs where NSMaxRange(run.range) <= length {
            let progress = min(max((now - run.start) / run.length, 0), 1)
            let eased = 1 - pow(1 - progress, 3)
            let count = run.range.length
            for offset in 0..<count {
                let order = Double(run.drains ? count - 1 - offset : offset)
                let filled = run.plain ? eased : min(max((eased * (Double(count) + Self.edge) - order) / Self.edge, 0), 1)
                layout.addTemporaryAttribute(
                    .foregroundColor,
                    value: run.drains ? Self.leaving(filled) : Self.arriving(filled),
                    forCharacterRange: NSRange(location: run.range.location + offset, length: 1)
                )
            }
        }
    }

    private func clear(_ run: Run) {
        guard let layout = textView?.layoutManager, let length = textView?.textStorage?.length else { return }
        let range = NSIntersectionRange(run.range, NSRange(location: 0, length: length))
        if range.length > 0 { layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range) }
    }

    /// The stretches of `range` that aren't spaces or line breaks.
    private func words(in range: NSRange) -> [NSRange] {
        guard let text = textView?.string as NSString?, NSMaxRange(range) <= text.length else { return [] }
        var words: [NSRange] = []
        var start: Int?
        for index in range.location..<NSMaxRange(range) {
            let isSpace = Character(UnicodeScalar(text.character(at: index)) ?? " ").isWhitespace
            if isSpace, let from = start {
                words.append(NSRange(location: from, length: index - from))
                start = nil
            } else if !isSpace, start == nil {
                start = index
            }
        }
        if let from = start { words.append(NSRange(location: from, length: NSMaxRange(range) - from)) }
        return words
    }

    // MARK: - Color

    private static func parts(_ color: NSColor) -> [CGFloat] {
        let color = color.usingColorSpace(.sRGB) ?? color
        return [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
    }

    /// Soft ink at 0, the page's ink at 1.
    private static func arriving(_ amount: Double) -> NSColor {
        let mixed = zip(softParts, inkParts).map { $0 + ($1 - $0) * CGFloat(amount) }
        return NSColor(srgbRed: mixed[0], green: mixed[1], blue: mixed[2], alpha: mixed[3])
    }

    /// The page's ink at 0, nothing at 1.
    private static func leaving(_ amount: Double) -> NSColor {
        NSColor(srgbRed: inkParts[0], green: inkParts[1], blue: inkParts[2], alpha: inkParts[3] * CGFloat(1 - amount))
    }
}
