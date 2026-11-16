import AppKit
import SwiftUI

/// The library: every muse in a sidebar by day, the open one on linen paper beside it.
struct LibraryWindow: View {
    static let id = "library"

    @State private var library = MacLibrary.shared
    @State private var query = ""
    @State private var filter = MacLibrary.Filter.all

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(muses: found, query: $query, filter: $filter, selection: $library.selection, picked: $library.picked)
                .navigationSplitViewColumnWidth(min: 270, ideal: 310, max: 380)
                .toolbar(removing: .sidebarToggle)
        } detail: {
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
        .tint(MuseColor.moss)
        // museo is paper: light only, whatever the mac is set to.
        .preferredColorScheme(.light)
        .onAppear {
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
