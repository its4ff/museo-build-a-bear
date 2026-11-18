import AppKit
import SwiftUI

/// One muse as a page: when and how it came in, its title set large, a thin player line,
/// its words with air, then what is kept and the keys. Actions float in a glass capsule at
/// the top right. The page draws no ground: the library's dune shows through.
struct MusePane: View {
    let muse: MacMuse

    @State private var player: MacPlayer
    @State private var asksToDelete = false
    @State private var copied = false

    init(muse: MacMuse) {
        self.muse = muse
        _player = State(initialValue: MacPlayer(url: MacLibrary.shared.audioURL(for: muse)))
    }

    var body: some View {
        ScrollView {
            page
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { actions }
        .confirmationDialog("delete this muse?", isPresented: $asksToDelete) {
            Button("delete", role: .destructive) {
                player.stop()
                MacLibrary.shared.remove(muse.id)
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("its words and audio leave this mac. the ring keeps its own copy.")
        }
        .onDisappear { player.stop() }
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
                    LeafTitle(muse.title, quiet: (muse.words ?? "").isEmpty)
                }
                if muse.hasAudio {
                    LeafPlayerLine(player: player, length: muse.duration.museDuration)
                }
                words
                LeafFoot(left: kept, keys: LibraryWords.museKeys)
                    .padding(.top, MuseSpacing.xs)
            }
        }
    }

    /// "saturday nov 14 · 8:21p · streamed · 0:06".
    private var eyebrow: String {
        [muse.createdAt.musePageDate, muse.createdAt.museClock, muse.isFromRing ? "from the ring" : "streamed", muse.duration.museDuration]
            .joined(separator: " · ")
    }

    /// "kept on this mac · typed into Notes · apple speech": what stays, where its words
    /// went, and what heard it.
    private var kept: String {
        var parts = [LibraryWords.kept]
        if let app = muse.typedInto {
            parts.append(muse.wasSent == true ? "sent to \(app)" : "typed into \(app)")
        }
        if let model = muse.model { parts.append(model) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Pieces

    @ViewBuilder
    private var words: some View {
        switch muse.words {
        case nil:
            quiet("hearing this muse…")
        case "":
            quiet("nothing in it sounded like words. the audio is kept.")
        case let text?:
            LeafWords(text)
        }
    }

    private func quiet(_ line: String) -> some View {
        Text(line)
            .font(MuseType.serifItalic)
            .foregroundStyle(MuseColor.ink55)
    }

    // MARK: - Actions

    private var actions: some View {
        LeafActions {
            LeafAction(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy the words") { copy() }
                .keyboardShortcut("c")
                .disabled((muse.words ?? "").isEmpty)
            LeafAction("waveform", "show the audio in finder") {
                NSWorkspace.shared.activateFileViewerSelecting([MacLibrary.shared.audioURL(for: muse)])
            }
            .disabled(!muse.hasAudio)
            let saved = MacLibrary.shared.muses.first { $0.id == muse.id }?.isSaved ?? false
            LeafAction(saved ? "bookmark.fill" : "bookmark", saved ? "saved · click to unsave" : "save this muse") {
                MacLibrary.shared.toggleSaved(muse.id)
            }
            .keyboardShortcut("s")
            LeafAction("trash", "delete this muse", tint: MuseColor.clay) { asksToDelete = true }
                .keyboardShortcut(.delete)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(muse.words ?? "", forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
