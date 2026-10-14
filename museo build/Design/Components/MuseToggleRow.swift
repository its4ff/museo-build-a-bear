import SwiftUI

/// A setting you flip: Satoshi title, optional subtitle, a moss switch. The whole row
/// toggles.
struct MuseToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    @Environment(\.museInListCard) private var inCard

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.init(title: title, subtitle: subtitle, isOn: isOn)
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            withAnimation(MuseMotion.snappy) { isOn.toggle() }
        } label: {
            HStack(alignment: .center, spacing: MuseSpacing.row) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: MuseSpacing.sm)
                MuseSwitchTrack(isOn: isOn)
            }
            .padding(.horizontal, MuseSpacing.card)
            .padding(.vertical, MuseSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MuseRowPressStyle())
        .modifier(MuseStandaloneRow(inCard: inCard))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}
