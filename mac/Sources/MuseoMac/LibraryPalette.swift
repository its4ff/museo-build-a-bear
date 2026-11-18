import AppKit
import SwiftUI

/// ⌘K: a glass palette over the dimmed library. One line to type in. With nothing typed it
/// offers the few places to go and what can be done with the open muse; typing finds muses
/// by what was said. ↑ and ↓ move, return opens, esc closes.
struct LibraryPalette: View {
    @Binding var isOpen: Bool

    @State private var library = MacLibrary.shared
    @State private var query = ""
    @State private var at = 0
    @FocusState private var isTyping: Bool
    @Environment(\.openWindow) private var openWindow

    /// One line in the palette.
    private struct Item: Identifiable {
        let id: String
        let name: String
        /// Their words are set in Lora; what museo offers, in the sans.
        var isTheirs = false
        var note: String?
        var keys: String?
        let run: () -> Void
    }

    var body: some View {
        let groups = groups
        let flat = groups.flatMap(\.items)
        VStack(alignment: .leading, spacing: 0) {
            field(flat)
            LeafHairline()
            VStack(alignment: .leading, spacing: 0) {
                if flat.isEmpty {
                    Text("nothing you've said matches.")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .padding(.horizontal, MuseSpacing.sm)
                        .frame(height: LibraryMetrics.paletteRow)
                }
                ForEach(groups, id: \.title) { group in
                    MuseEyebrow(group.title)
                        .padding(.horizontal, MuseSpacing.sm)
                        .padding(.top, MuseSpacing.sm)
                        .padding(.bottom, MuseSpacing.xxs)
                    ForEach(group.items) { item in
                        row(item, isOn: flat.indices.contains(at) && flat[at].id == item.id)
                    }
                }
            }
            .padding(MuseSpacing.xs)
            LeafHairline()
            HStack {
                Spacer(minLength: 0)
                Text(LibraryWords.paletteKeys)
                    .font(MuseFont.mono(.caption2))
                    .foregroundStyle(MuseColor.ink55)
            }
            .padding(.horizontal, MuseSpacing.card)
            .frame(height: LibraryMetrics.paletteRow)
        }
        .frame(width: LibraryMetrics.palette)
        .duoTileGlass(cornerRadius: MuseRadius.sheet)
        .museElevation(.e2)
        .onAppear {
            #if DEBUG
            if let typed = LibraryWindow.previewPalette { query = typed }
            #endif
            isTyping = true
        }
        .onChange(of: query) { at = 0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("search, or go")
    }

    // MARK: - Pieces

    private func field(_ flat: [Item]) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            TextField(LibraryWords.palettePrompt, text: $query, prompt: Text(LibraryWords.palettePrompt).foregroundStyle(MuseColor.ink55))
                .textFieldStyle(.plain)
                .font(MuseFont.satoshi(LibraryMetrics.paletteType))
                .foregroundStyle(MuseColor.ink)
                .tint(MuseColor.moss600)
                .focused($isTyping)
                .onKeyPress(.downArrow) { move(1, in: flat) }
                .onKeyPress(.upArrow) { move(-1, in: flat) }
                .onKeyPress(.escape) {
                    isOpen = false
                    return .handled
                }
                .onSubmit {
                    guard flat.indices.contains(at) else { return }
                    run(flat[at])
                }
            Text("⌘K")
                .font(MuseFont.mono(.caption))
                .foregroundStyle(MuseColor.ink55)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, MuseSpacing.card)
        .frame(height: LibraryMetrics.paletteField)
    }

    private func row(_ item: Item, isOn: Bool) -> some View {
        Button {
            run(item)
        } label: {
            HStack(spacing: MuseSpacing.xs) {
                Text(item.name)
                    .font(item.isTheirs ? MuseFont.lora(LibraryMetrics.rowWords) : MuseType.label)
                    .foregroundStyle(isOn ? DuoColor.onMoss : MuseColor.ink)
                    .lineLimit(1)
                Spacer(minLength: MuseSpacing.xs)
                if let trailing = isOn ? "↩" : (item.keys ?? item.note) {
                    Text(trailing)
                        .font(item.keys != nil || isOn ? MuseFont.mono(.caption) : MuseType.caption)
                        .foregroundStyle(isOn ? DuoColor.onMossQuiet : MuseColor.ink55)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityHidden(isOn)
                }
            }
            .padding(.horizontal, MuseSpacing.sm)
            .frame(height: LibraryMetrics.paletteRow)
            .background {
                if isOn {
                    RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                        .fill(MuseColor.primaryGradient)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func move(_ by: Int, in flat: [Item]) -> KeyPress.Result {
        guard !flat.isEmpty else { return .handled }
        at = min(max(at + by, 0), flat.count - 1)
        return .handled
    }

    private func run(_ item: Item) {
        isOpen = false
        item.run()
    }

    // MARK: - What it offers

    private var groups: [(title: String, items: [Item])] {
        let terms = query.lowercased().split(separator: " ")
        func matches(_ name: String) -> Bool {
            terms.allSatisfy { name.lowercased().contains($0) }
        }
        var groups: [(title: String, items: [Item])] = []
        let go = goItems.filter { terms.isEmpty || matches($0.name) }
        if !go.isEmpty { groups.append(("go", go)) }
        let open = openItems.filter { terms.isEmpty || matches($0.name) }
        if !open.isEmpty { groups.append(("this muse", open)) }
        if !terms.isEmpty {
            let found = library.muses
                .filter { matches($0.words ?? "") || matches($0.name ?? "") }
                .prefix(LibraryMetrics.paletteThoughts)
                .map { muse in
                    Item(
                        id: muse.id.uuidString,
                        name: muse.title,
                        isTheirs: true,
                        note: "\(muse.createdAt.museDayTitle) · \(muse.createdAt.museClock)"
                    ) {
                        library.picked = []
                        library.selection = muse.id
                        library.showsStats = false
                    }
                }
            if !found.isEmpty { groups.append(("you said", Array(found))) }
        }
        return groups
    }

    private var goItems: [Item] {
        [
            Item(id: "note", name: "new note", keys: "⌘N") { openWindow(id: NoteWindow.id, value: UUID()) },
            Item(id: "words", name: "your words") { library.showsStats = true },
            Item(id: "newest", name: "the newest muse") {
                library.picked = []
                library.selection = library.muses.first?.id
                library.showsStats = false
            },
        ]
    }

    /// What can be done with the muse that is open.
    private var openItems: [Item] {
        guard !library.showsStats, library.picked.count < 2,
              let muse = library.muses.first(where: { $0.id == library.selection }) else { return [] }
        var items: [Item] = []
        if !(muse.words ?? "").isEmpty {
            items.append(Item(id: "copy", name: "copy the words", keys: "⌘C") {
                TextInserter.copy([muse.isNote ? muse.name : nil, muse.words].compactMap { $0 }.joined(separator: "\n\n"))
            })
        }
        if muse.isNote {
            items.append(Item(id: "open", name: "open the note", keys: "⌘O") { openWindow(id: NoteWindow.id, value: muse.id) })
        } else {
            items.append(Item(id: "save", name: muse.isSaved ? "unsave it" : "save it", keys: "⌘S") { library.toggleSaved(muse.id) })
            if muse.hasAudio {
                items.append(Item(id: "audio", name: "show the audio in finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([library.audioURL(for: muse)])
                })
            }
        }
        return items
    }
}
