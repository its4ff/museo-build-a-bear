import AppKit
import SwiftUI

/// The library's margin: muses by day, newest first, as type on the dune. No panel behind
/// it. Search and the four filters stay put at its top; under them the list scrolls and
/// runs out into the paper above the ring pill. A row says when and how it came in, then
/// the start of what was said. The open one sits on the moss gradient; a recording from the
/// ring nobody has opened yet carries an amber dot.
///
/// ↑ and ↓ move through them (from the search line too). ⌘ click picks one more (or lets it
/// go), shift click picks everything between, esc lets them all go. ⌘F goes to search.
struct LibrarySidebar: View {
    let muses: [MacMuse]
    @Binding var query: String
    @Binding var filter: MacLibrary.Filter
    @Binding var selection: UUID?
    @Binding var picked: Set<UUID>
    @Environment(\.openWindow) private var openWindow
    @FocusState private var focus: Focus?

    private enum Focus: Hashable {
        case search, list
    }

    var body: some View {
        ScrollViewReader { scroller in
            VStack(alignment: .leading, spacing: 0) {
                topButtons
                search(scroller)
                filters
                    .padding(.top, MuseSpacing.row)
                    .padding(.bottom, MuseSpacing.xs)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
                        rows
                    }
                    .padding(.bottom, LibraryMetrics.pillRoom + LibraryMetrics.listFade)
                }
                .scrollIndicators(.hidden)
                .mask { listFade }
                .focusable()
                .focused($focus, equals: .list)
                .focusEffectDisabled()
                .onKeyPress(.downArrow) { step(1, scroller) }
                .onKeyPress(.upArrow) { step(-1, scroller) }
                .onKeyPress(.escape) {
                    guard !picked.isEmpty else { return .ignored }
                    picked = []
                    return .handled
                }
            }
            .overlay(alignment: .bottom) { ringPill }
            .background { searchKey }
            .onAppear { focus = .list }
        }
    }

    #if DEBUG
    /// The margin without its scroll view, for `ScreenSheet` (scroll views don't draw offscreen).
    var still: some View {
        VStack(alignment: .leading, spacing: 0) {
            topButtons
            ScrollViewReader { search($0) }
            filters
                .padding(.top, MuseSpacing.row)
                .padding(.bottom, MuseSpacing.xs)
            VStack(alignment: .leading, spacing: 0) { rows }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .background { PocketGround() }
    }
    #endif

    // MARK: - The top

    /// New note, your words, settings: in the traffic lights' row, at the margin's right.
    private var topButtons: some View {
        HStack(spacing: MuseSpacing.xxs / 2) {
            Spacer(minLength: 0)
            NewNoteButton()
            StatsButton()
            LibrarySettingsButton()
        }
        .padding(.trailing, LibraryMetrics.gutter - MuseSpacing.xs)
        .frame(height: LibraryMetrics.chrome)
    }

    /// The search line: no box, a hairline under it.
    private func search(_ scroller: ScrollViewProxy) -> some View {
        VStack(spacing: MuseSpacing.xs) {
            HStack(spacing: MuseSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(MuseFont.symbol(LibraryMetrics.searchGlyph, weight: .regular))
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
                TextField(LibraryWords.search, text: $query, prompt: Text(LibraryWords.search).foregroundStyle(MuseColor.ink55))
                    .textFieldStyle(.plain)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink)
                    .tint(MuseColor.moss)
                    .focused($focus, equals: .search)
                    // The arrows walk the list while you type; esc clears, then steps out.
                    .onKeyPress(.downArrow) { step(1, scroller) }
                    .onKeyPress(.upArrow) { step(-1, scroller) }
                    .onKeyPress(.escape) {
                        if query.isEmpty { focus = .list } else { query = "" }
                        return .handled
                    }
                    .onSubmit { focus = .list }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(MuseFont.symbol(LibraryMetrics.searchGlyph))
                            .foregroundStyle(MuseColor.ink55)
                    }
                    .buttonStyle(.plain)
                    .help("clear the search")
                    .accessibilityLabel("clear the search")
                }
            }
            LeafHairline()
        }
        .padding(.horizontal, LibraryMetrics.gutter)
        .padding(.top, MuseSpacing.xs)
    }

    /// ⌘F, with nothing to see.
    private var searchKey: some View {
        Button("search") { focus = .search }
            .keyboardShortcut("f")
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    /// The four filters as four plain words, the current one in full ink.
    private var filters: some View {
        HStack(spacing: MuseSpacing.sm) {
            word("all", .all)
            word("streamed", .streamed)
            word("from the ring", .ring, amber: MacLibrary.shared.unseenCount > 0)
            word("saved", .saved)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LibraryMetrics.gutter)
    }

    private func word(_ title: String, _ value: MacLibrary.Filter, amber: Bool = false) -> some View {
        let on = filter == value
        return Button {
            filter = value
        } label: {
            HStack(spacing: MuseSpacing.xxs) {
                // Something from the ring is waiting to be opened.
                if amber {
                    Circle()
                        .fill(MuseColor.ringAmber)
                        .frame(width: LibraryMetrics.dot - 1, height: LibraryMetrics.dot - 1)
                        .accessibilityLabel("new")
                }
                Text(title)
                    .font(on ? MuseType.metaMedium : MuseType.meta)
                    .foregroundStyle(on ? MuseColor.ink : MuseColor.ink55)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - The list

    /// The muses by day: the day's word, a hairline, then its rows.
    private var rows: some View {
        ForEach(days, id: \.day) { group in
            HStack(spacing: MuseSpacing.sm) {
                Text(group.day.museDayTitle)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize()
                LeafHairline()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, LibraryMetrics.gutter)
            .padding(.top, MuseSpacing.lg)
            .padding(.bottom, MuseSpacing.xxs)
            ForEach(group.muses) { muse in
                row(muse).id(muse.id)
            }
        }
    }

    private func row(_ muse: MacMuse) -> some View {
        let on = picked.count > 1 ? picked.contains(muse.id) : selection == muse.id && !MacLibrary.shared.showsStats
        return Button {
            pick(muse.id)
        } label: {
            LibraryRow(muse: muse, meta: meta(muse), opening: opening(muse), on: on)
        }
        .buttonStyle(.plain)
        // Double click a note to write in it again.
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if muse.isNote { openWindow(id: NoteWindow.id, value: muse.id) }
        })
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The list softens as it slides under the filters, and runs out before the ring pill.
    private var listFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: LibraryMetrics.listRise)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: LibraryMetrics.listFade)
            Color.clear
                .frame(height: LibraryMetrics.pillRoom)
        }
    }

    private var ringPill: some View {
        LibraryRingPill()
            .frame(width: DuoMetrics.cornerWidth)
            .padding(.bottom, DuoMetrics.margin)
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

    /// A named note's first line, for under its name.
    private func opening(_ muse: MacMuse) -> String? {
        guard muse.isNote, muse.name != nil else { return nil }
        let line = muse.words?.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
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
        focus = .list
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

// MARK: - A row

/// One muse in the margin: a small line, then its words in Lora. No chrome: the open one
/// wears the moss gradient, the one under the pointer the faintest ink. Today's are in full
/// ink; older ones sit back a step.
private struct LibraryRow: View {
    let muse: MacMuse
    let meta: String
    let opening: String?
    let on: Bool

    @State private var isHovered = false

    private var hasWords: Bool { muse.words?.isEmpty == false }
    /// A note shows its name once it has one.
    private var shown: String? { muse.isNote ? (muse.name ?? muse.words) : muse.words }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            HStack(spacing: MuseSpacing.xxs + 1) {
                if muse.isUnseen {
                    Circle()
                        .fill(MuseColor.ringAmber)
                        .frame(width: LibraryMetrics.dot, height: LibraryMetrics.dot)
                        .accessibilityLabel("new from the ring")
                }
                // A note is a page: the mark says so, so "note" leaves the line.
                if muse.isNote {
                    Image(systemName: "doc")
                        .font(MuseFont.symbol(LibraryMetrics.noteMark))
                        .foregroundStyle(quiet)
                        .accessibilityLabel("note")
                }
                Text(meta)
                    .font(MuseType.caption)
                    .foregroundStyle(quiet)
                    .lineLimit(1)
            }
            Text(shown.map { $0.isEmpty ? "blank muse" : $0 } ?? "hearing it…")
                .font(hasWords ? MuseFont.lora(LibraryMetrics.rowWords) : MuseFont.loraItalic(LibraryMetrics.rowWords))
                .lineSpacing(LibraryMetrics.rowLeading)
                .foregroundStyle(ink)
                .lineLimit(muse.isNote && muse.name != nil ? 1 : 2)
                .multilineTextAlignment(.leading)
            if let opening {
                Text(opening)
                    .font(MuseFont.loraItalic(LibraryMetrics.rowOpening))
                    .foregroundStyle(quiet)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LibraryMetrics.gutter - LibraryMetrics.rowInset)
        .padding(.vertical, MuseSpacing.sm - MuseSpacing.xxs / 2)
        .background {
            if on {
                shape.fill(MuseColor.primaryGradient)
            } else if isHovered {
                shape.fill(DuoColor.hover)
            }
        }
        .contentShape(shape)
        .padding(.horizontal, LibraryMetrics.rowInset)
        .onHover { isHovered = $0 }
    }

    private var ink: Color {
        if on { return DuoColor.onMoss }
        guard hasWords else { return MuseColor.ink55 }
        return Calendar.current.isDateInToday(muse.createdAt) ? MuseColor.ink : MuseColor.ink70
    }

    private var quiet: Color { on ? DuoColor.onMossQuiet : MuseColor.ink55 }
}
