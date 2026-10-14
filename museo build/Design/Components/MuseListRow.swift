import SwiftUI

/// A place to go: Satoshi title, optional meta line, optional icon, value and chevron.
/// With an `action` it is a button; without, it is a label (for a `NavigationLink`).
struct MuseListRow: View {
    let title: String
    var meta: String?
    var value: String?
    var systemImage: String?
    var showsChevron: Bool
    var action: (() -> Void)?

    @Environment(\.museInListCard) private var inCard

    init(
        title: String,
        meta: String? = nil,
        value: String? = nil,
        systemImage: String? = nil,
        showsChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.meta = meta
        self.value = value
        self.systemImage = systemImage
        self.showsChevron = showsChevron
        self.action = action
    }

    init(
        _ title: String,
        meta: String? = nil,
        value: String? = nil,
        systemImage: String? = nil,
        showsChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.init(title: title, meta: meta, value: value, systemImage: systemImage, showsChevron: showsChevron, action: action)
    }

    var body: some View {
        if let action {
            Button {
                MuseHaptics.play(.soft)
                action()
            } label: {
                row
            }
            .buttonStyle(MuseRowPressStyle())
            .modifier(MuseStandaloneRow(inCard: inCard))
        } else {
            row
                .modifier(MuseStandaloneRow(inCard: inCard))
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: MuseSpacing.row) {
            if let systemImage {
                MuseIconTile(systemImage, tone: .quiet)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                if let meta {
                    Text(meta)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                }
            }
            Spacer(minLength: MuseSpacing.xs)
            if let value {
                Text(value)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .museSymbol(13, weight: .semibold)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
