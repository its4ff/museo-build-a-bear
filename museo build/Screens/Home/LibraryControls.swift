import SwiftUI

/// Sort and search, side by side at the trailing end of the home's title row: two raised
/// 38pt circles in 44pt targets. Each turns moss while it's doing
/// something (a sort other than newest, search open).
struct LibraryControls: View {
    @Binding var sort: LibrarySort
    let searchOpen: Bool
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            sortMenu
            searchButton
        }
    }

    // MARK: Sort

    private var sortMenu: some View {
        Menu {
            Picker("sort", selection: $sort) {
                ForEach(LibrarySort.allCases) { item in
                    Label(item.label, systemImage: item.symbol).tag(item)
                }
            }
            .pickerStyle(.inline)
            .labelsVisibility(.visible)
        } label: {
            LibraryCircle(systemName: "arrow.up.arrow.down", active: sort != .newest)
        }
        .buttonStyle(MusePressStyle())
        .accessibilityLabel("sort muses")
        .accessibilityValue(sort.label)
    }

    // MARK: Search

    private var searchButton: some View {
        Button {
            MuseHaptics.play(.soft)
            onSearch()
        } label: {
            LibraryCircle(systemName: "magnifyingglass", active: searchOpen)
        }
        .buttonStyle(MusePressStyle())
        .accessibilityLabel(searchOpen ? "close search" : "search muses")
        .accessibilityAddTraits(searchOpen ? .isSelected : [])
    }
}

/// A 38pt circle in a 44pt target: raised with a hairline at rest, flat moss with a ground
/// glyph while active.
private struct LibraryCircle: View {
    let systemName: String
    let active: Bool

    var body: some View {
        Image(systemName: systemName)
            .font(MuseFont.symbol(15, weight: .semibold))
            .foregroundStyle(active ? MuseColor.ground : MuseColor.ink70)
            .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
            .background {
                Circle()
                    .fill(active ? MuseColor.moss : MuseColor.raised)
                    .overlay {
                        if !active { Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75) }
                    }
                    .frame(width: MuseTopChrome.circle, height: MuseTopChrome.circle)
            }
            .contentShape(Circle())
            .animation(MuseMotion.snappy, value: active)
    }
}

#Preview("library controls") {
    @Previewable @State var sort = LibrarySort.newest
    @Previewable @State var open = false
    LibraryControls(sort: $sort, searchOpen: open) { open.toggle() }
        .padding(MuseSpacing.page)
        .background { MuseShelfBackground() }
}
