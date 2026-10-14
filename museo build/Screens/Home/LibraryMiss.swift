import SwiftUI

/// What the library says when a search or a pill turns up nothing. Two quiet lines, left
/// aligned under the pills:
///
/// - search: "nothing close to that" / "try other words, or the feeling behind them."
/// - filter: "none of those" / "try all." (a tap goes back to all)
struct LibraryMiss: View {
    enum Kind {
        case search
        case filter
    }

    let kind: Kind
    /// "try all." on an empty pill.
    var onShowAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: kind == .search ? MuseSpacing.xxs : MuseSpacing.xs) {
            Text(kind == .search ? "nothing close to that" : "none of those")
                .font(kind == .search ? MuseType.headline : MuseType.titleSmall)
                .tracking(MuseType.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .accessibilityAddTraits(.isHeader)
            switch kind {
            case .search:
                Text("try other words, or the feeling behind them.")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink70)
            case .filter:
                Button {
                    MuseHaptics.play(.selection)
                    onShowAll()
                } label: {
                    Text("try all.")
                        .font(MuseType.body)
                        .foregroundStyle(MuseColor.ink70)
                        .frame(minHeight: MuseTopChrome.hitTarget, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.97))
                .accessibilityHint("shows every muse")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, kind == .search ? MuseSpacing.sm : MuseSpacing.md)
        .transition(.opacity)
    }
}

#Preview("misses") {
    VStack(spacing: MuseSpacing.section) {
        LibraryMiss(kind: .search)
        LibraryMiss(kind: .filter)
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity, alignment: .top)
    .background { MuseShelfBackground() }
}
