import SwiftUI

/// A dot whose glow breathes while something is moving (the ring streaming, a sync).
/// Still under Reduce Motion.
struct MuseLiveDot: View {
    var color: Color
    var size: CGFloat
    var pulses: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(color: Color = MuseColor.moss600, size: CGFloat = 7, pulses: Bool = true) {
        self.color = color
        self.size = size
        self.pulses = pulses
    }

    var body: some View {
        let dot = Circle()
            .fill(color)
            .frame(width: size, height: size)
        Group {
            if pulses && !reduceMotion {
                dot.phaseAnimator([false, true]) { content, lit in
                    content.shadow(color: color.opacity(lit ? 0.8 : 0.2), radius: lit ? 6 : 2)
                } animation: { _ in
                    .easeInOut(duration: 1.4)
                }
            } else {
                dot
            }
        }
        .accessibilityHidden(true)
    }
}
