import AppKit
import SwiftUI

/// Muses by day, newest first: when, how it came in, then the start of what was said. The
/// open one sits on the forest gradient in linen; a recording from the ring nobody has opened
/// yet carries an amber dot. ↑ and ↓ move through them. ⌘ click picks one more (or lets it
/// go), shift click picks everything between, esc lets them all go.
struct LibrarySidebar: View {
    let muses: [MacMuse]
    @Binding var query: String
    @Binding var filter: MacLibrary.Filter
    @Binding var selection: UUID?
    @Binding var picked: Set<UUID>
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    search
                        .padding(.horizontal, MuseSpacing.xxs)
                        .padding(.bottom, MuseSpacing.xs)
                    filters
                        .padding(.horizontal, MuseSpacing.xxs)
                        .padding(.bottom, MuseSpacing.xs)
                    rows
                }
                .padding(.horizontal, MuseSpacing.xs)
                .padding(.top, 44)
                .padding(.bottom, MuseSpacing.xs)
            }
            .scrollIndicators(.hidden)
            // In the traffic lights' row, at the sidebar's right.
            .overlay(alignment: .topTrailing) {
                topButtons
                    .padding(.top, MuseSpacing.xs)
                    .padding(.trailing, MuseSpacing.sm)
            }
            // Sage into linen: the sidebar a shade apart from the paper beside it.
            .background(LinearGradient(colors: [MuseColor.mossTint, MuseColor.groundDeep], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { step(1, scroller) }
            .onKeyPress(.upArrow) { step(-1, scroller) }
            .onKeyPress(.escape) {
                guard !picked.isEmpty else { return .ignored }
                picked = []
                return .handled
            }
        }
    }

    /// The muses by day.
    private var rows: some View {
        ForEach(days, id: \.day) { group in
            MuseEyebrow(group.day.museDayTitle)
                .padding(.horizontal, MuseSpacing.sm)
                .padding(.top, MuseSpacing.sm)
                .padding(.bottom, MuseSpacing.xxs)
            ForEach(group.muses) { muse in
                row(muse).id(muse.id)
            }
        }
    }

    #if DEBUG
    /// The sidebar without its scroll view, for `ScreenSheet` (scroll views don't draw offscreen).
    var still: some View {
        VStack(alignment: .leading, spacing: 2) {
            search.padding(.horizontal, MuseSpacing.xxs).padding(.bottom, MuseSpacing.xs)
            filters.padding(.horizontal, MuseSpacing.xxs).padding(.bottom, MuseSpacing.xs)
            rows
        }
        .padding(.horizontal, MuseSpacing.xs)
        .padding(.top, 44)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topTrailing) {
            topButtons
                .padding(.top, MuseSpacing.xs)
                .padding(.trailing, MuseSpacing.sm)
        }
        .clipped()
        .background(LinearGradient(colors: [MuseColor.mossTint, MuseColor.groundDeep], startPoint: .top, endPoint: .bottom))
    }
    #endif

    /// Stats, then settings, in the traffic lights' row.
    private var topButtons: some View {
        HStack(spacing: 2) {
            NewNoteButton()
            StatsButton()
            LibrarySettingsButton()
        }
    }

    // MARK: - Search and filters

    private var search: some View {
        HStack(spacing: MuseSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(MuseFont.symbol(12))
                .foregroundStyle(MuseColor.ink55)
            TextField("search everything you've said", text: $query)
                .textFieldStyle(.plain)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(MuseFont.symbol(12))
                        .foregroundStyle(MuseColor.ink55)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("clear the search")
            }
        }
        .padding(.horizontal, MuseSpacing.sm)
        .frame(height: 36)
        .background(MuseColor.composer.opacity(0.7), in: RoundedRectangle(cornerRadius: MuseRadius.control))
        .overlay(RoundedRectangle(cornerRadius: MuseRadius.control).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
    }

    private var filters: some View {
        HStack(spacing: MuseSpacing.xxs) {
            chip("all", .all)
            chip("streamed", .streamed)
            chip("from the ring", .ring, amber: true)
            chip("saved", .saved)
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
            .background(on ? AnyShapeStyle(MuseColor.primaryGradient) : AnyShapeStyle(MuseColor.raised.opacity(0.6)), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : MuseColor.hairline, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - A muse

    private func row(_ muse: MacMuse) -> some View {
        let on = picked.count > 1 ? picked.contains(muse.id) : selection == muse.id && !MacLibrary.shared.showsStats
        let hasWords = muse.words?.isEmpty == false
        // A note shows its name once it has one.
        let shown = muse.isNote ? (muse.name ?? muse.words) : muse.words
        return Button {
            pick(muse.id)
        } label: {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                HStack(spacing: 5) {
                    if muse.isUnseen {
                        Circle().fill(MuseColor.ochre).frame(width: 6, height: 6)
                            .accessibilityLabel("new from the ring")
                    }
                    // A note is a page: the mark says so, so "note" leaves the line.
                    if muse.isNote {
                        Image(systemName: "doc")
                            .font(MuseFont.symbol(9))
                            .foregroundStyle(on ? MuseColor.ground.opacity(0.72) : MuseColor.ink55)
                            .accessibilityLabel("note")
                    }
                    Text(meta(muse))
                        .font(MuseType.caption)
                        .foregroundStyle(on ? MuseColor.ground.opacity(0.72) : MuseColor.ink55)
                        .lineLimit(1)
                }
                Text(shown.map { $0.isEmpty ? "blank muse" : $0 } ?? "hearing it…")
                    .font(hasWords ? MuseFont.lora(15) : MuseFont.loraItalic(15))
                    .foregroundStyle(on ? MuseColor.ground : (hasWords ? MuseColor.ink : MuseColor.ink55))
                    .lineLimit(muse.isNote && muse.name != nil ? 1 : 2)
                    .multilineTextAlignment(.leading)
                // A named note's first words, under its name.
                if muse.isNote, muse.name != nil, let opening = firstLine(muse.words) {
                    Text(opening)
                        .font(MuseFont.loraItalic(12.5))
                        .foregroundStyle(on ? MuseColor.ground.opacity(0.66) : MuseColor.ink55)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MuseSpacing.sm)
            .padding(.vertical, MuseSpacing.xs)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: MuseRadius.control)
                        .fill(MuseColor.primaryGradient)
                        .shadow(color: MuseColor.moss900.opacity(0.18), radius: 6, y: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Double click a note to write in it again.
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if muse.isNote { openWindow(id: NoteWindow.id, value: muse.id) }
        })
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// "8:21p · streamed · into Notes", "7:02p · from the ring · 0:42".
    private func meta(_ muse: MacMuse) -> String {
        if muse.isNote {
            let count = MacLibrary.wordCount(muse.words ?? "")
            return "\(muse.createdAt.museClock) · \(count) \(count == 1 ? "word" : "words")"
        }
        var parts = [muse.createdAt.museClock, muse.isFromRing ? "from the ring" : "streamed"]
        if let landing = muse.landing {
            parts.append(landing)
        } else if muse.isFromRing {
            parts.append(muse.duration.museDuration)
        }
        if muse.isSaved { parts.append("saved") }
        return parts.joined(separator: " · ")
    }

    /// A note's first line, for under its name.
    private func firstLine(_ words: String?) -> String? {
        let line = words?.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
        return line?.isEmpty == false ? line : nil
    }

    // MARK: - Order

    private var days: [(day: Date, muses: [MacMuse])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: muses) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.createdAt > $1.createdAt })
        }
    }

    // MARK: - Picking

    /// A click opens one muse; ⌘ adds or takes away one; shift takes everything from the
    /// open one to here, in the order shown.
    private func pick(_ id: UUID) {
        let keys = NSEvent.modifierFlags
        if keys.contains(.shift), let anchor = selection {
            let ordered = days.flatMap(\.muses).map(\.id)
            if let from = ordered.firstIndex(of: anchor), let to = ordered.firstIndex(of: id) {
                picked = Set(ordered[min(from, to)...max(from, to)])
                return
            }
        }
        if keys.contains(.command) {
            var next = picked.isEmpty ? Set([selection].compactMap { $0 }) : picked
            if next.contains(id), next.count > 1 {
                next.remove(id)
                if selection == id { selection = ordered(next).first }
            } else {
                next.insert(id)
                selection = id
            }
            picked = next
            return
        }
        picked = []
        selection = id
        MacLibrary.shared.showsStats = false
    }

    /// Picked muses in the order shown.
    private func ordered(_ ids: Set<UUID>) -> [UUID] {
        days.flatMap(\.muses).map(\.id).filter(ids.contains)
    }

    /// ↑ and ↓: the next muse in the order shown.
    private func step(_ by: Int, _ scroller: ScrollViewProxy) -> KeyPress.Result {
        let ordered = days.flatMap(\.muses)
        guard !ordered.isEmpty else { return .ignored }
        let at = ordered.firstIndex { $0.id == selection } ?? (by > 0 ? -1 : ordered.count)
        let next = ordered[min(max(at + by, 0), ordered.count - 1)]
        picked = []
        selection = next.id
        MacLibrary.shared.showsStats = false
        scroller.scrollTo(next.id)
        return .handled
    }
}
