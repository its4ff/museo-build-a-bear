import SwiftUI

/// A quiet text button under a primary: "skip for now", "or try the samples". Satoshi label
/// in ink70, a full 44pt target, one soft haptic.
struct MuseQuietButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            Text(title)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink70)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .padding(.horizontal, MuseSpacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.97))
        .transition(.opacity)
    }
}

#Preview {
    MuseQuietButton("skip for now") {}
        .padding()
        .background { MuseBackground() }
}
