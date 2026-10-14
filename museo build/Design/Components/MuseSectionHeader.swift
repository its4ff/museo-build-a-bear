import SwiftUI

/// A section opener: a tracked eyebrow and a hairline rule running off to the right, with
/// optional trailing content (a count, a small action).
struct MuseSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: MuseSpacing.sm) {
            // Full width at normal sizes; wraps instead of running off the page at the
            // accessibility sizes. The rule shrinks first.
            MuseEyebrow(title)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [MuseColor.ink.opacity(0.14), MuseColor.ink.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .accessibilityHidden(true)
            trailing
        }
    }
}

extension MuseSectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

extension MuseSectionHeader where Trailing == MuseSectionCount {
    /// A section with a quiet count on the right: `MuseSectionHeader("today", count: 3)`.
    init(_ title: String, count: Int?) {
        self.init(title) { MuseSectionCount(count: count) }
    }
}

/// The quiet number at the end of a section header.
struct MuseSectionCount: View {
    let count: Int?

    var body: some View {
        if let count {
            Text(count, format: .number)
                .font(MuseType.captionMedium)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
                .contentTransition(.numericText(value: Double(count)))
        }
    }
}
