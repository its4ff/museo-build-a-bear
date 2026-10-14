import SwiftUI

/// A moss-tint well with a Lora sentence: a gentle explanation, a tip, an empty state.
struct MuseHintCard: View {
    let text: String
    var systemImage: String?

    init(_ text: String, systemImage: String? = nil) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .museSymbol(15, weight: .medium)
                    .foregroundStyle(MuseColor.moss600)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(MuseType.serif)
                .lineSpacing(4)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MuseColor.mossTint, in: RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
