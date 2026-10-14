import SwiftUI

/// The pills under the home's title: all, streamed, memory, long, and typed once there are any.
/// Selected is flat moss with ground text; the rest are raised chrome. A selection tick on
/// every change. Scrolls sideways when large text runs them past the edge, and the scroll
/// reaches the screen's edges so pills never clip at the gutter.
struct LibraryFilterBar: View {
    let filters: [LibraryFilter]
    @Binding var selection: LibraryFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MuseSpacing.xs) {
                ForEach(filters) { filter in
                    pill(filter)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, MuseSpacing.page, for: .scrollContent)
        .padding(.horizontal, -MuseSpacing.page)
    }

    private func pill(_ filter: LibraryFilter) -> some View {
        let selected = filter == selection
        return Button {
            guard !selected else { return }
            MuseHaptics.play(.selection)
            selection = filter
        } label: {
            Text(filter.label)
                .font(selected ? MuseType.metaMedium : MuseType.meta)
                .foregroundStyle(selected ? MuseColor.ground : MuseColor.ink70)
                .lineLimit(1)
                .padding(.horizontal, MuseSpacing.row)
                .padding(.vertical, MuseSpacing.xs)
                .musePill(.chrome, selected: selected)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.97))
        .accessibilityLabel(filter.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(MuseMotion.snappy, value: selected)
    }
}

#Preview("filter bar") {
    @Previewable @State var filter = LibraryFilter.all
    LibraryFilterBar(filters: LibraryFilter.allCases, selection: $filter)
        .padding(.horizontal, MuseSpacing.page)
        .frame(maxHeight: .infinity)
        .background { MuseShelfBackground() }
}
