import SwiftUI

/// A quiet label across the library: "today", "yesterday", "monday oct 6", or a search's
/// "4 muses". Centered between two hairlines that fade out toward the edges. Not sticky:
/// it scrolls away with its muses.
struct DayRule: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            fade(toward: .leading)
            Text(title)
                .font(MuseType.captionMedium)
                .tracking(MuseType.eyebrowTracking)
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(1)
                .fixedSize()
            fade(toward: .trailing)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A hairline at full strength beside the label, clear at the far end.
    private func fade(toward edge: HorizontalEdge) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [MuseColor.hairline, MuseColor.hairline.opacity(0)],
                    startPoint: edge == .leading ? .trailing : .leading,
                    endPoint: edge == .leading ? .leading : .trailing
                )
            )
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    // MARK: Day titles

    /// "today", "yesterday", "monday oct 6", "monday oct 6 2025".
    static func title(for day: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) { return "yesterday" }
        guard calendar.component(.year, from: day) != calendar.component(.year, from: now) else {
            return day.musePageDate
        }
        return day.formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day().year())
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
    }
}

#Preview("day rules") {
    VStack(spacing: MuseSpacing.section) {
        DayRule("today")
        DayRule(DayRule.title(for: .now.addingTimeInterval(-3 * 86_400)))
        DayRule("4 muses")
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseShelfBackground() }
}
