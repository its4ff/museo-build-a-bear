import Foundation
import SwiftUI

// How to press the ring and what it lights up, drawn small enough to sit beside a word:
// a bar for a hold, a dot per click, and the ring's two lights (white while streaming, amber
// while it records to itself). The onboarding and the cheat card share them.

// MARK: - Gesture

/// A press on the ring as marks: `hold` is a short bar, `clicks(2)` two dots, `count(10)`
/// "10×" and a dot, for more clicks than the column fits.
struct RingGestureMark: View {
    nonisolated enum Gesture: Equatable, Sendable {
        case hold
        case clicks(Int)
        case count(Int)
    }

    let gesture: Gesture
    var color: Color
    /// The column the mark sits in; nil hugs the marks.
    var width: CGFloat?

    /// Wide enough for six small dots, so marks in a column line their words up.
    static let width: CGFloat = 36

    init(_ gesture: Gesture, color: Color = MuseColor.ink70, width: CGFloat? = RingGestureMark.width) {
        self.gesture = gesture
        self.color = color
        self.width = width
    }

    var body: some View {
        Group {
            switch gesture {
            case .hold:
                Capsule()
                    .fill(color)
                    .frame(width: 18, height: 5)
            case .clicks(let count):
                // Many clicks shrink a little so six still fit the column.
                let size: CGFloat = count > 3 ? 4 : 5
                HStack(spacing: count > 3 ? 2 : 3.5) {
                    ForEach(0..<max(count, 1), id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: size, height: size)
                    }
                }
            case .count(let count):
                HStack(spacing: 2) {
                    Text(verbatim: "\(count)\u{00D7}")
                        .font(MuseType.captionMedium)
                        .monospacedDigit()
                        .foregroundStyle(color)
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityHidden(true)
    }
}

// MARK: - Light

/// One of the ring's lights. White sits on paper with a hairline, amber is ochre. `glows`
/// breathes it, as the ring does while it's on (still under Reduce Motion).
struct RingLight: View {
    nonisolated enum Kind: Sendable {
        /// Streaming: on while you hold.
        case white
        /// Memory: on while the ring records to itself.
        case amber
    }

    let kind: Kind
    var size: CGFloat = 8
    var glows: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ kind: Kind, size: CGFloat = 8, glows: Bool = false) {
        self.kind = kind
        self.size = size
        self.glows = glows
    }

    var body: some View {
        let dot = Circle()
            .fill(fill)
            .overlay {
                if kind == .white {
                    Circle().strokeBorder(MuseColor.ink.opacity(0.22), lineWidth: 0.75)
                }
            }
            .frame(width: size, height: size)
        Group {
            if glows && !reduceMotion {
                dot.phaseAnimator([false, true]) { content, lit in
                    content.shadow(color: glow.opacity(lit ? 0.9 : 0.25), radius: lit ? size : size / 3)
                } animation: { _ in
                    .easeInOut(duration: 1.2)
                }
            } else {
                dot.shadow(color: glow.opacity(glows ? 0.6 : 0), radius: size / 2)
            }
        }
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch kind {
        case .white: MuseColor.composer
        case .amber: MuseColor.ringAmber
        }
    }

    /// White light reads on linen as a soft ink halo; amber glows amber.
    private var glow: Color {
        switch kind {
        case .white: MuseColor.ink.opacity(0.35)
        case .amber: MuseColor.ringAmber
        }
    }
}

// MARK: - Recipe row

/// "hold · white light · straight to this iphone": the gesture, its light and what it
/// does, in one quiet line under a step's words.
struct RingRecipeLine: View {
    let gesture: RingGestureMark.Gesture
    let name: String
    let light: RingLight.Kind
    let result: String

    var body: some View {
        // One line while it fits; the result drops under it when it doesn't.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                gestureAndLight
                dot
                resultText
            }
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                gestureAndLight
                resultText
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(lightName), \(result)")
    }

    private var gestureAndLight: some View {
        HStack(alignment: .center, spacing: MuseSpacing.xs) {
            RingGestureMark(gesture, color: MuseColor.ink, width: nil)
            Text(name)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
            dot
            RingLight(light)
            Text(lightName)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink70)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var resultText: some View {
        Text(result)
            .font(MuseType.meta)
            .foregroundStyle(MuseColor.ink70)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var lightName: String {
        switch light {
        case .white: "white light"
        case .amber: "amber light"
        }
    }

    private var dot: some View {
        Text(verbatim: "·")
            .font(MuseType.meta)
            .foregroundStyle(MuseColor.ink55)
            .accessibilityHidden(true)
    }
}

#Preview("ring marks") {
    VStack(alignment: .leading, spacing: MuseSpacing.md) {
        RingRecipeLine(gesture: .hold, name: "hold", light: .white, result: "straight to this iphone")
        RingRecipeLine(gesture: .clicks(2), name: "double click", light: .amber, result: "saved on the ring")
        HStack(spacing: MuseSpacing.md) {
            RingGestureMark(.clicks(1))
            RingGestureMark(.clicks(3))
            RingGestureMark(.clicks(6))
            RingLight(.white, glows: true)
            RingLight(.amber, glows: true)
        }
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseBackground() }
}
