import SwiftUI

/// Muses by day, newest first: when, how it came in, then the start of what was said. A
/// recording from the ring nobody has opened yet carries an amber dot.
struct LibrarySidebar: View {
    let muses: [MacMuse]
    @Binding var filter: MacLibrary.Filter
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            Section {
                filters
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
            }
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.muses) { muse in
                        row(muse).tag(muse.id)
                    }
                } header: {
                    MuseEyebrow(group.day.museDayTitle)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var filters: some View {
        HStack(spacing: MuseSpacing.xxs) {
            chip("all", .all)
            chip("streamed", .streamed)
            chip("from the ring", .ring, amber: true)
        }
    }

    private func chip(_ title: String, _ value: MacLibrary.Filter, amber: Bool = false) -> some View {
        let on = filter == value
        return Button {
            filter = value
        } label: {
            HStack(spacing: 5) {
                if amber { Circle().fill(MuseColor.ochre).frame(width: 5, height: 5) }
                Text(title).font(MuseType.captionMedium)
            }
            .foregroundStyle(on ? MuseColor.ground : MuseColor.ink70)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(on ? AnyShapeStyle(MuseColor.moss) : AnyShapeStyle(MuseColor.raised.opacity(0.6)), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : MuseColor.hairline, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    private func row(_ muse: MacMuse) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            HStack(spacing: 5) {
                if muse.isUnseen {
                    Circle().fill(MuseColor.ochre).frame(width: 6, height: 6)
                        .accessibilityLabel("new from the ring")
                }
                Text(meta(muse))
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
            }
            Text(muse.words.map { $0.isEmpty ? "blank muse" : $0 } ?? "hearing it…")
                .font(MuseFont.lora(15))
                .foregroundStyle(muse.words?.isEmpty == false ? MuseColor.ink : MuseColor.ink55)
                .lineLimit(2)
        }
        .padding(.vertical, MuseSpacing.xxs)
    }

    /// "8:21p · streamed · into Notes", "7:02p · from the ring · 0:42".
    private func meta(_ muse: MacMuse) -> String {
        var parts = [muse.createdAt.museClock, muse.isFromRing ? "from the ring" : "streamed"]
        if let app = muse.typedInto {
            parts.append("into \(app)")
        } else if muse.isFromRing {
            parts.append(muse.duration.museDuration)
        }
        return parts.joined(separator: " · ")
    }

    private var days: [(day: Date, muses: [MacMuse])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: muses) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.createdAt > $1.createdAt })
        }
    }
}
