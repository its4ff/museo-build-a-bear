import AppKit
import SwiftUI

/// A note in the library: its name, its words, and a way back into it. Opening it puts it
/// back on the eye line in its own window.
struct NotePane: View {
    let note: MacMuse

    @State private var asksToDelete = false
    @State private var copied = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            page
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { actions }
        .confirmationDialog("delete this note?", isPresented: $asksToDelete) {
            Button("delete", role: .destructive) { MacLibrary.shared.remove(note.id) }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("its words leave this mac.")
        }
    }

    #if DEBUG
    /// The page without its scroll view, for `ScreenSheet`.
    var still: some View {
        page
            .frame(maxHeight: .infinity, alignment: .top)
            .background { PocketGround() }
            .overlay(alignment: .topTrailing) { actions }
    }
    #endif

    private var page: some View {
        LeafColumn {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    LeafMono([note.createdAt.musePageDate, note.createdAt.museClock, note.meta].joined(separator: " · "))
                    LeafTitle(note.name ?? "naming it…", quiet: note.name == nil)
                }
                LeafWords(note.words ?? "")
                LeafFoot(left: LibraryWords.kept, keys: LibraryWords.noteKeys)
                    .padding(.top, MuseSpacing.xs)
            }
        }
    }

    private var actions: some View {
        LeafActions {
            LeafAction("square.and.pencil", "open the note") { openWindow(id: NoteWindow.id, value: note.id) }
                .keyboardShortcut("o")
            LeafAction(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy the words") { copy() }
                .keyboardShortcut("c")
            LeafAction("trash", "delete this note", tint: MuseColor.clay) { asksToDelete = true }
                .keyboardShortcut(.delete)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString([note.name, note.words].compactMap { $0 }.joined(separator: "\n\n"), forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
