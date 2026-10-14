import SwiftUI

/// The page opening: optional eyebrow, a Lora title ending in a period ("build."), an
/// optional subtitle. `trailing` sits on the title line (a filter, a count).
struct MuseHeader<Trailing: View>: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    var titleSize: CGFloat
    var subtitleColor: Color
    let trailing: Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 40,
        subtitleColor: Color = MuseColor.ink70,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleSize = titleSize
        self.subtitleColor = subtitleColor
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let eyebrow {
                MuseEyebrow(eyebrow)
            }
            titleRow
            if let subtitle {
                Text(subtitle)
                    .font(MuseType.body)
                    .lineSpacing(MuseType.bodyLineSpacing)
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleRow: some View {
        let word = Text(title)
            .font(MuseFont.lora(titleSize))
            .tracking(titleSize >= 34 ? -0.025 * titleSize : -0.02 * titleSize)
            .foregroundStyle(MuseColor.ink)
            .accessibilityAddTraits(.isHeader)
        if Trailing.self == EmptyView.self {
            word
        } else {
            HStack(alignment: .center, spacing: MuseSpacing.sm) {
                word
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: MuseSpacing.sm)
                trailing
            }
        }
    }
}

extension MuseHeader where Trailing == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 40,
        subtitleColor: Color = MuseColor.ink70
    ) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, titleSize: titleSize, subtitleColor: subtitleColor) {
            EmptyView()
        }
    }
}
