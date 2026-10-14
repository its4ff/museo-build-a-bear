import SwiftUI

/// The springy press every tappable piece of chrome shares. No fill of its own.
struct MusePressStyle: ButtonStyle {
    var pressedScale: CGFloat

    init(pressedScale: CGFloat = 0.94) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(MuseMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, down in
                if down { MuseHaptics.prepare() }
            }
    }
}

/// A row press: a faint ink wash instead of a scale, so rows inside a card stay put.
struct MuseRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed { MuseColor.ink.opacity(0.04) }
            }
            .animation(MuseMotion.snappy, value: configuration.isPressed)
    }
}
