import AppKit
import SwiftUI

/// One muse on linen: when and how it came in, its words, and its voice.
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
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                MuseHeader(
                    eyebrow: "\(muse.createdAt.musePageDate) · \(muse.createdAt.museClock)",
                    title: muse.title,
                    subtitle: muse.meta
                )
                tags
                listen
                words
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, MuseSpacing.sectionLabel)
            .padding(.vertical, MuseSpacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background { MuseBackground() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copy()
                } label: {
                    Label(copied ? "copied" : "copy the words", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled((muse.words ?? "").isEmpty)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([MacLibrary.shared.audioURL(for: muse)])
                } label: {
                    Label("show the audio in finder", systemImage: "waveform")
                }
                Button {
                    asksToDelete = true
                } label: {
                    Label("delete this muse", systemImage: "trash")
                }
            }
        }
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

    // MARK: - Pieces

    /// Where it went and what heard it: "typed into Notes", "apple speech".
    private var tags: some View {
        HStack(spacing: MuseSpacing.xs) {
            if let app = muse.typedInto {
                Text("typed into \(app)")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(MuseColor.mossTint, in: Capsule())
            }
            if let model = muse.model {
                Text(model)
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.ink70)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
            }
        }
        .padding(.top, -MuseSpacing.sm)
    }

    /// Play and pause, and how far along it is.
    private var listen: some View {
        HStack(spacing: MuseSpacing.sm) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(MuseFont.symbol(13, weight: .semibold))
                    .foregroundStyle(MuseColor.ground)
                    .frame(width: 34, height: 34)
                    .background(MuseColor.primaryGradient, in: Circle())
                    // The circle stays small; the target is the house 44pt.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle())
            .disabled(!player.canPlay)
            .accessibilityLabel(player.isPlaying ? "pause" : "play")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MuseColor.ink.opacity(0.08))
                    Capsule()
                        .fill(MuseColor.moss600)
                        .frame(width: max(0, proxy.size.width * player.progress))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)

            Text(muse.duration.museDuration)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
                .monospacedDigit()
        }
        .padding(.leading, MuseSpacing.xs)
        .padding(.trailing, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.xxs)
        .museCardSurface()
    }

    @ViewBuilder
    private var words: some View {
        switch muse.words {
        case nil:
            Text("hearing this muse…")
                .font(MuseType.serifItalic)
                .foregroundStyle(MuseColor.ink55)
        case "":
            Text("nothing in it sounded like words. the audio is kept.")
                .font(MuseType.serifItalic)
                .foregroundStyle(MuseColor.ink55)
        case let text?:
            Text(text)
                .font(MuseType.headline)
                .foregroundStyle(MuseColor.ink)
                .lineSpacing(MuseType.serifLineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
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
