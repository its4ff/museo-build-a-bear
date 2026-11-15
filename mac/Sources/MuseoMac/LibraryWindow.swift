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
            LibrarySidebar(muses: found, filter: $filter, selection: $library.selection)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if let muse = library.muses.first(where: { $0.id == library.selection }) {
                MusePane(muse: muse)
                    .id(muse.id)
            } else {
                LibraryEmpty(hasMuses: !library.muses.isEmpty)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "search everything you've said")
        .tint(MuseColor.moss)
        // museo is paper: light only, whatever the mac is set to.
        .preferredColorScheme(.light)
        .onAppear {
            if library.selection == nil { library.selection = library.muses.first?.id }
            // A dock icon while the library is open, so it can be found with ⌘Tab.
            NSApp.setActivationPolicy(.regular)
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
        .onChange(of: library.selection, initial: true) { _, id in
            if let id { library.markSeen(id) }
        }
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
