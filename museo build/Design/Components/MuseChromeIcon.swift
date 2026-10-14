import SwiftUI

/// A 38pt raised circle with an SF Symbol, inside a 44pt target. The top chrome row's
/// buttons (build, close, more). Plays `.soft`.
struct MuseChromeIcon: View {
    let systemName: String
    let label: String
    let action: () -> Void

    init(systemName: String, label: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    init(_ systemName: String, label: String, action: @escaping () -> Void) {
        self.init(systemName: systemName, label: label, action: action)
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            Image(systemName: systemName)
                .font(MuseFont.symbol(15, weight: .medium))
                .foregroundStyle(MuseColor.ink70)
                .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                .background {
                    Circle()
                        .fill(MuseColor.raised)
                        .overlay { Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75) }
                        .frame(width: MuseTopChrome.circle, height: MuseTopChrome.circle)
                }
                .contentShape(Circle())
        }
        .buttonStyle(MusePressStyle())
        .accessibilityLabel(label)
    }
}
