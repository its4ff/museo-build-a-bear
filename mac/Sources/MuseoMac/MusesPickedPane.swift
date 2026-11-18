import AppKit
import SwiftUI

/// Several muses picked in the library (⌘ or shift click): how many, their words in order,
/// and the same glass capsule as one muse's page, to copy them all or delete them together.
struct MusesPickedPane: View {
    let ids: Set<UUID>

    @State private var asksToDelete = false
    @State private var copied = false

    private var muses: [MacMuse] {
        MacLibrary.shared.muses.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            page
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { actions }
        .confirmationDialog("delete \(ids.count) muses?", isPresented: $asksToDelete) {
            Button("delete", role: .destructive) { MacLibrary.shared.remove(ids) }
            Button("keep them", role: .cancel) {}
        } message: {
            Text("their words and audio leave this mac. the ring keeps its own copies.")
        }
    }

    #if DEBUG
    /// The page without its scroll view, for `ScreenSheet` (scroll views don't draw offscreen).
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
                    LeafMono(eyebrow)
                    LeafTitle("\(ids.count) muses.")
                }
                VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                    ForEach(muses) { muse in
                        let hasWords = muse.words?.isEmpty == false
                        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                            Text("\(muse.createdAt.museClock) · \(muse.meta)")
                                .font(MuseType.caption)
                                .foregroundStyle(MuseColor.ink55)
                            Text(muse.words.map { $0.isEmpty ? "blank muse" : $0 } ?? "hearing it…")
                                .font(hasWords ? MuseFont.lora(LibraryMetrics.pickedWords) : MuseFont.loraItalic(LibraryMetrics.pickedWords))
                                .foregroundStyle(hasWords ? MuseColor.ink : MuseColor.ink55)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                LeafFoot(left: "copied oldest first, a line between each", keys: LibraryWords.pickedKeys)
                    .padding(.top, MuseSpacing.xs)
            }
        }
    }

    /// "picked · 12:31 in all".
    private var eyebrow: String {
        let total = muses.reduce(0) { $0 + $1.duration }
        return "picked · \(total.museDuration) in all"
    }

    // MARK: - Actions

    private var actions: some View {
        LeafActions {
            LeafAction(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy all their words") { copy() }
                .keyboardShortcut("c")
            LeafAction("xmark", "let them go") { MacLibrary.shared.picked = [] }
                .keyboardShortcut(.escape, modifiers: [])
            LeafAction("trash", "delete these muses", tint: MuseColor.clay) { asksToDelete = true }
                .keyboardShortcut(.delete)
        }
    }

    private func copy() {
        TextInserter.copy(MacLibrary.shared.words(of: ids))
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
