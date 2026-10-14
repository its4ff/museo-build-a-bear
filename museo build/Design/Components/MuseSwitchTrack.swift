import SwiftUI

/// The moss switch, drawn: a 40 by 24 capsule, moss when on, a raised knob.
/// Shared by `MuseToggleRow` and `.toggleStyle(.muse)`.
struct MuseSwitchTrack: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? MuseColor.moss : MuseColor.ink.opacity(0.12))
            .frame(width: 40, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(MuseColor.raised)
                    .frame(width: 20, height: 20)
                    .shadow(color: MuseColor.ink.opacity(0.18), radius: 1.5, x: 0, y: 1)
                    .padding(2)
            }
            .animation(MuseMotion.snappy, value: isOn)
            .accessibilityHidden(true)
    }
}
