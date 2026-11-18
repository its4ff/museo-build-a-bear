#if DEBUG
import SwiftUI

/// A page's title, centered, in Lora, with one quiet count line under it: "your thoughts"
/// over "212 · 3 today". No period, as in dune. A glass circle can sit at either end of the
/// title's row (settings on the left, add on the right).
///
/// ```swift
/// PocketPageTitle("your thoughts", count: "212 · 3 today", leading: {
///     PocketGlassCircle("gearshape", label: "settings")
/// })
/// ```
/// Always name the slot (`leading:`, `trailing:`): a bare trailing closure is easy to
/// misread, and settings lives top left on every page.
struct PocketPageTitle<Leading: View, Trailing: View>: View {
    let title: String
    let count: String?
    let leading: Leading
    let trailing: Trailing

    init(
        _ title: String,
        count: String? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.count = count
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: MuseSpacing.xs) {
            Text(title)
                .font(MuseType.title)
                .tracking(MuseType.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .overlay(alignment: .leading) { leading }
                .overlay(alignment: .trailing) { trailing }
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text(count)
                    .font(MuseType.body)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
