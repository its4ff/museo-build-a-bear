import SwiftUI

// The orb is the only gradient sphere in the app, and it is small on purpose.
// Idle is moss with a slow breath. Listening inverts to linen, so the surface you speak
// into is the colour of the paper. Thinking drifts the highlight.

/// muse's one glyph: a glossy sphere. `MuseOrb(mode: .listening, size: MuseOrb.Size.chat)`.
struct MuseOrb: View {
    nonisolated enum Mode: CaseIterable, Equatable, Sendable {
        /// Moss, breathing slowly. The resting state, empty states, the send button.
        case idle
        /// Linen: the ring is streaming, a muse is being heard.
        case listening
        /// Moss with an orbiting highlight: transcribing, an app running.
        case thinking
    }

    /// The four sizes the orb comes in.
    nonisolated enum Size {
        /// A mark beside text.
        static let mark: CGFloat = 16
        /// In a field or a row.
        static let search: CGFloat = 20
        /// In a composer or a card.
        static let chat: CGFloat = 30
        /// On its own: empty states, voice moments.
        static let voice: CGFloat = 52
    }

    var mode: Mode
    var size: CGFloat
    /// The idle breath. Turn it off where the orb repeats or sits beside moving content.
    var breathes: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mode: Mode = .idle, size: CGFloat = Size.voice, breathes: Bool = true) {
        self.mode = mode
        self.size = size
        self.breathes = breathes
    }

    var body: some View {
        ZStack {
            switch mode {
            case .idle:
                breathing(sphere(phase: 0), from: 1, to: 1.035, seconds: 2.6, active: moves)
            case .listening:
                breathing(sphere(phase: 0, linen: true), from: 0.99, to: 1.02, seconds: 1.8, active: moves)
            case .thinking:
                if reduceMotion {
                    sphere(phase: 0.8)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        sphere(phase: t * 0.55)
                            .scaleEffect(1 + 0.02 * sin(t * 1.8))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .animation(MuseMotion.smooth, value: mode)
        .accessibilityLabel(accessibility)
    }

    /// A slow scale loop, restarted whenever the mode changes.
    @ViewBuilder
    private func breathing(_ sphere: some View, from: CGFloat, to: CGFloat, seconds: Double, active: Bool) -> some View {
        if active {
            sphere.phaseAnimator([false, true]) { content, out in
                content.scaleEffect(out ? to : from)
            } animation: { _ in
                .easeInOut(duration: seconds)
            }
        } else {
            sphere
        }
    }

    /// Breathing is on for idle (when asked) and always for listening, never under
    /// Reduce Motion.
    private var moves: Bool {
        guard !reduceMotion else { return false }
        return mode == .listening || breathes
    }

    private var accessibility: String {
        switch mode {
        case .idle: "muse"
        case .listening: "listening"
        case .thinking: "thinking"
        }
    }

    private func sphere(phase: Double, linen: Bool = false) -> some View {
        let highlight = UnitPoint(
            x: 0.33 + 0.08 * cos(phase),
            y: 0.26 + 0.08 * sin(phase * 1.3)
        )
        let tone: (bright: Color, mid: Color, deep: Color, deepest: Color) = linen
            ? (MuseColor.orbLinenHighlight, MuseColor.orbLinenMid, MuseColor.orbLinenDeep, MuseColor.orbLinenShade)
            : (MuseColor.orbHighlight, MuseColor.orbMid, MuseColor.orbDeep, MuseColor.moss900)
        let insetDark = linen ? MuseColor.orbLinenInset.opacity(0.35) : MuseColor.moss900.opacity(0.45)
        return ZStack {
            // Body: the radial ramp, lit from the highlight.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: tone.bright, location: 0),
                            .init(color: tone.mid, location: 0.26),
                            .init(color: tone.deep, location: 0.58),
                            .init(color: tone.deepest, location: 1),
                        ],
                        center: highlight,
                        startRadius: 0,
                        endRadius: size * 0.78
                    )
                )
            // Shade pooling at the bottom.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [insetDark, .clear],
                        center: UnitPoint(x: 0.5, y: 1.05),
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
            // Specular.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [MuseColor.composer.opacity(linen ? 0.7 : 0.22), .clear],
                        center: UnitPoint(x: 0.33, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.28
                    )
                )
                .blendMode(.screen)
            // Paper tooth on the sphere.
            MuseGrainOverlay(opacity: linen ? 0.10 : 0.14)
                .clipShape(Circle())
        }
        .compositingGroup()
        .shadow(color: MuseColor.moss900.opacity(linen ? 0.18 : 0.36), radius: size * 0.22, x: 0, y: size * 0.12)
    }
}
