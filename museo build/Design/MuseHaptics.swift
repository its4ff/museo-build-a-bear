import CoreHaptics
import UIKit

// Haptics with meaning. Generators stay warm for the app's life (a generator made per tap
// starts cold and its first tap can trail the touch it answers). The typewriter's key taps
// run on Core Haptics so every keystroke can have its own weight.
//
// Conventions: `.soft` for chrome taps, sheets and segments; `.selection` for disclosures;
// `.medium` for setting up the ring; `.success` for copy and save; `.warning` before a
// destructive confirm; `.received` when a muse lands; `.sent` when you send something;
// `.tick` for a first word landing; `.done` for something finished.

// MARK: - Haptics

/// One call for every tap: `MuseHaptics.play(.soft)`. Honors the system haptics switch.
@MainActor
enum MuseHaptics {

    nonisolated enum Kind: CaseIterable, Sendable {
        case soft
        case light
        case medium
        /// A crisp click: something landing in place.
        case rigid
        case selection
        case success
        case warning
        case error
        /// Something left: a soft double tap, the second lighter.
        case sent
        /// Something arrived (a muse landing): the same shape, quieter.
        case received
        /// A first word landing.
        case tick
        /// Something finished: pen down, a firmer draw, then lift.
        case done
    }

    static func play(_ kind: Kind) {
        switch kind {
        case .soft:
            soft.impactOccurred(intensity: 0.7)
            soft.prepare()
        case .light:
            light.impactOccurred()
            light.prepare()
        case .medium:
            medium.impactOccurred()
            medium.prepare()
        case .rigid:
            rigid.impactOccurred(intensity: 0.75)
            rigid.prepare()
        case .selection:
            selection.selectionChanged()
            selection.prepare()
        case .success:
            notice.notificationOccurred(.success)
            notice.prepare()
        case .warning:
            notice.notificationOccurred(.warning)
            notice.prepare()
        case .error:
            notice.notificationOccurred(.error)
            notice.prepare()
        case .sent:
            beats([(0, soft, 0.6), (0.08, soft, 0.4)])
        case .received:
            beats([(0, soft, 0.5), (0.1, soft, 0.35)])
        case .tick:
            light.impactOccurred(intensity: 0.55)
            light.prepare()
        case .done:
            beats([(0, soft, 0.42), (0.18, rigid, 0.78), (0.52, soft, 0.34)])
        }
    }

    /// Wakes the Taptic Engine for the taps a press usually ends in. Button styles call
    /// this on touch-down so the tap on release lands with the finger.
    static func prepare() {
        soft.prepare()
        light.prepare()
        selection.prepare()
    }

    /// One typewriter keystroke (Core Haptics). See `MuseKeyHaptics`.
    static func key(_ key: MuseKeyHaptics.Key, strength: Float = 1) {
        MuseKeyHaptics.shared.key(key, strength: strength)
    }

    /// The typewriter's taps, by their spec name: `MuseHaptics.keys(strength: 0.6)` is one
    /// letter; `MuseHaptics.keys(.stop, strength: 0.6)` a full stop. Same as `key(_:strength:)`.
    static func keys(_ key: MuseKeyHaptics.Key = .letter, strength: Float = 1) {
        MuseKeyHaptics.shared.key(key, strength: strength)
    }

    // MARK: Generators, kept warm

    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notice = UINotificationFeedbackGenerator()

    /// A short score of impacts: (seconds after the first, generator, intensity).
    private static func beats(_ score: [(TimeInterval, UIImpactFeedbackGenerator, CGFloat)]) {
        for (_, generator, _) in score { generator.prepare() }
        for (delay, generator, intensity) in score {
            if delay == 0 {
                generator.impactOccurred(intensity: intensity)
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }
}

// MARK: - Key haptics

/// Core Haptics for typing (`MuseInkText`). UIKit's generators offer three fixed taps;
/// typing wants a range: faint letters, a firmer start to each word, a rounded pause at a
/// comma, a deep full stop. One engine, warmed ahead, restarted after interruptions.
/// Falls back to a soft UIKit tap where Core Haptics isn't available.
@MainActor
final class MuseKeyHaptics {
    static let shared = MuseKeyHaptics()

    /// The beats of typing, lightest to deepest.
    nonisolated enum Key: CaseIterable, Sendable {
        case letter
        /// The first letter of a word, a touch firmer, so words have shape.
        case wordStart
        /// Comma, colon, semicolon: a soft, rounded pause.
        case pause
        /// Full stop, question mark: the satisfying one.
        case stop
    }

    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .soft)
    /// When making the engine last failed. Typing calls `prepare()` on every key, so a
    /// failure (the app in the background, the haptic server busy) waits a moment before
    /// trying again instead of building an engine 35 times a second.
    private var failedAt: Date?

    private init() {}

    /// Warms the engine so the first key isn't late.
    func prepare() {
        guard supported, engine == nil else { return }
        if let failedAt, Date.now.timeIntervalSince(failedAt) < 2 { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = Self.restart(engine)
            try engine.start()
            self.engine = engine
            failedAt = nil
        } catch {
            engine = nil
            failedAt = .now
        }
    }

    /// One keystroke. `strength` scales the whole preset (0.6 for a card, 1 for a hero line).
    func key(_ key: Key, strength: Float = 1) {
        // A little variance so a line never feels like a metronome.
        let jitter = Float.random(in: 0.9...1.1)
        switch key {
        case .letter:
            tap(intensity: 0.3 * strength * jitter, sharpness: 0.45)
        case .wordStart:
            tap(intensity: 0.42 * strength * jitter, sharpness: 0.5)
        case .pause:
            tap(intensity: 0.45 * strength, sharpness: 0.2)
        case .stop:
            tap(intensity: 0.7 * strength, sharpness: 0.12)
            // A faint echo, like a key settling back.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                self.tap(intensity: 0.25 * strength, sharpness: 0.3)
            }
        }
    }

    /// One transient tap, 0...1 intensity and sharpness.
    func tap(intensity: Float, sharpness: Float) {
        let intensity = min(max(intensity, 0), 1)
        prepare()
        guard let engine else {
            fallback.impactOccurred(intensity: CGFloat(intensity))
            return
        }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Stopped while idle or interrupted: start again and try once more.
            try? engine.start()
            if let pattern = try? CHHapticPattern(events: [event], parameters: []) {
                try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            }
        }
    }

    /// Built off the main actor: the engine calls this on its own queue.
    private nonisolated static func restart(_ engine: CHHapticEngine) -> CHHapticEngine.ResetHandler {
        { [weak engine] in try? engine?.start() }
    }
}
