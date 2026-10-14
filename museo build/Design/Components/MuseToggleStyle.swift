import SwiftUI

/// `Toggle("studio sound", isOn: $on).toggleStyle(.muse)`: a Satoshi label and the moss
/// switch, instead of the system's green.
struct MuseToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            MuseHaptics.play(.soft)
            withAnimation(MuseMotion.snappy) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: MuseSpacing.sm) {
                configuration.label
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                Spacer(minLength: MuseSpacing.sm)
                MuseSwitchTrack(isOn: configuration.isOn)
            }
            .frame(minHeight: MuseTopChrome.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}

extension ToggleStyle where Self == MuseToggleStyle {
    /// The moss switch: `.toggleStyle(.muse)`.
    static var muse: MuseToggleStyle { MuseToggleStyle() }
}
