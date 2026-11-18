import AppKit
import SwiftUI

/// The library: one sheet of paper on the dune with a margin of thoughts. Every muse by day
/// in the margin, a hairline, then the open one as a page. No sidebar panel and no fills:
/// the margin is type on the same ground as the page. ⌘K opens the palette.
struct LibraryWindow: View {
    static let id = "library"

    @State private var library = MacLibrary.shared
    @State private var query = ""
    @State private var filter = MacLibrary.Filter.all
    @State private var showsPalette = false

    /// How strong the dune is behind the library: the pools' color, the stipple in them,
    /// and whether the stipple is the finer cell.
    static var ground = (strength: 0.6, stipple: 0.4, fine: true)

    #if DEBUG
    /// Opens the palette with this typed in it, for pictures.
    static var previewPalette: String?
    #endif

    var body: some View {
        HStack(spacing: 0) {
            LibrarySidebar(muses: found, query: $query, filter: $filter, selection: $library.selection, picked: $library.picked)
                .frame(width: LibraryMetrics.margin)
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(width: LibraryMetrics.hair)
                .accessibilityHidden(true)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Under the hidden title bar too: the margin's top row shares it with the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .background { PocketGround(strength: Self.ground.strength, stipple: Self.ground.stipple, fine: Self.ground.fine).ignoresSafeArea() }
        .overlay { palette }
        .background { paletteKey }
        .frame(minWidth: LibraryMetrics.minWindow.width, minHeight: LibraryMetrics.minWindow.height)
        .tint(MuseColor.moss)
        // museo is paper: light only, whatever the mac is set to.
        .preferredColorScheme(.light)
        .onAppear {
            #if DEBUG
            if Self.previewPalette != nil { showsPalette = true }
            // After the first selection has closed them.
            if StatsPane.preview != nil { DispatchQueue.main.async { library.showsStats = true } }
            #endif
            if library.selection == nil { library.selection = library.muses.first?.id }
            // A dock icon while the library is open, so it can be found with ⌘Tab.
            DockPresence.opened()
        }
        .onDisappear { DockPresence.closed() }
        .onChange(of: library.selection, initial: true) { _, id in
            if let id { library.markSeen(id) }
            library.showsStats = false
        }
        // Picks hold only what's shown: a new search or filter lets them go.
        .onChange(of: query) { library.picked = [] }
        .onChange(of: filter) { library.picked = [] }
    }

    /// What the page holds: your words, several picked, a note, a muse, or nothing yet.
    @ViewBuilder
    private var page: some View {
        if library.showsStats {
            StatsPane()
        } else if library.picked.count > 1 {
            MusesPickedPane(ids: library.picked)
        } else if let muse = library.muses.first(where: { $0.id == library.selection }) {
            if muse.isNote {
                NotePane(note: muse)
                    .id(muse.id)
            } else {
                MusePane(muse: muse)
                    .id(muse.id)
            }
        } else {
            LibraryEmpty(hasMuses: !library.muses.isEmpty)
        }
    }

    // MARK: - The palette

    /// The page dims and the palette sits a little above the middle. A click on the dim
    /// closes it.
    @ViewBuilder
    private var palette: some View {
        if showsPalette {
            ZStack {
                MuseColor.ink.opacity(LibraryMetrics.veil)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { showsPalette = false }
                    .accessibilityHidden(true)
                LibraryPalette(isOpen: $showsPalette)
                    .offset(y: -LibraryMetrics.paletteLift)
            }
            .transition(.opacity)
        }
    }

    /// ⌘K, with nothing to see.
    private var paletteKey: some View {
        Button("search, or go") {
            withAnimation(MuseMotion.snappy) { showsPalette.toggle() }
        }
        .keyboardShortcut("k")
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// The muses in this filter whose words hold every word typed in the search.
    private var found: [MacMuse] {
        let terms = query.lowercased().split(separator: " ")
        let muses = library.muses(filter)
        guard !terms.isEmpty else { return muses }
        return muses.filter { muse in
            let words = (muse.words ?? "").lowercased()
            return terms.allSatisfy { words.contains($0) }
        }
    }
}
