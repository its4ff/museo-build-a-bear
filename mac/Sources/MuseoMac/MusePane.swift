import AppKit
import SwiftUI

/// One muse on linen: when and how it came in, its words, and its voice. Actions float in a
/// small glass capsule at the top right instead of a toolbar.
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
        .background { MuseBackground() }
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
            .background { MuseBackground() }
            .overlay(alignment: .topTrailing) { actions }
    }
    #endif

    private var page: some View {
            VStack(alignment: .leading, spacing: MuseSpacing.xl) {
                VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                    Text(eyebrow)
                        .font(MuseFont.mono(.caption))
                        .foregroundStyle(MuseColor.ink55)
                    Text(muse.title)
                        .font(MuseType.display)
                        .tracking(MuseType.displayTracking)
                        .foregroundStyle(MuseColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    tags
                }
                listen
                words
                footer
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(.horizontal, MuseSpacing.sectionLabel)
            .padding(.top, 88)
            .padding(.bottom, MuseSpacing.sectionLabel)
            .frame(maxWidth: .infinity)
    }

    /// "saturday nov 14 · 8:21p · streamed · 0:06".
    private var eyebrow: String {
        [muse.createdAt.musePageDate, muse.createdAt.museClock, muse.isFromRing ? "from the ring" : "streamed", muse.duration.museDuration]
            .joined(separator: " · ")
    }

    // MARK: - Pieces

    /// Where it went and what heard it: "typed into Notes", "apple speech".
    private var tags: some View {
        HStack(spacing: MuseSpacing.xs) {
            if muse.isFromRing {
                tag("from the ring", dot: MuseColor.ochre)
            }
            if let app = muse.typedInto {
                Text(muse.wasSent == true ? "sent to \(app)" : "typed into \(app)")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(MuseColor.mossTint, in: Capsule())
            }
            if let model = muse.model {
                tag(model)
            }
        }
    }

    private func tag(_ title: String, dot: Color? = nil) -> some View {
        HStack(spacing: 5) {
            if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
            Text(title)
        }
        .font(MuseType.captionMedium)
        .foregroundStyle(MuseColor.ink70)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
    }

    /// Play and pause beside the recording's shape, the played part in moss.
    private var listen: some View {
        HStack(spacing: MuseSpacing.md) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(MuseFont.symbol(14, weight: .semibold))
                    .foregroundStyle(MuseColor.ground)
                    .frame(width: 42, height: 42)
                    .background(MuseColor.primaryGradient, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(MusePressStyle())
            .disabled(!player.canPlay)
            .accessibilityLabel(player.isPlaying ? "pause" : "play")

            // Spread across the whole player, one bar per stretch.
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(shape.enumerated()), id: \.offset) { index, peak in
                    Capsule()
                        .fill(Double(index) / Double(max(shape.count, 1)) < player.progress ? MuseColor.moss600 : MuseColor.ink.opacity(0.16))
                        .frame(width: 3, height: 4 + 24 * peak)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30)
            .accessibilityHidden(true)

            Text(muse.duration.museDuration)
                .font(MuseFont.mono(.caption))
                .foregroundStyle(MuseColor.ink55)
                .monospacedDigit()
        }
        .padding(.leading, MuseSpacing.xxs)
        .padding(.trailing, MuseSpacing.lg)
        .padding(.vertical, MuseSpacing.xxs)
        .background(MuseColor.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
        .museElevation(.e1)
    }

    /// The waveform, or an even line until it's read.
    private var shape: [Double] {
        player.peaks.isEmpty ? Array(repeating: 0.15, count: MacPlayer.bins) : player.peaks
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
                .font(MuseFont.lora(22))
                .foregroundStyle(MuseColor.ink)
                .lineSpacing(MuseSpacing.xs)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Text("kept on this mac")
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Spacer()
            Text("⌘C copy · ⌘S save · ⌘⌫ delete")
                .font(MuseFont.mono(.caption2))
                .foregroundStyle(MuseColor.ink55)
        }
        .padding(.top, MuseSpacing.md)
        .overlay(alignment: .top) { Rectangle().fill(MuseColor.hairline).frame(height: 1) }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 2) {
            action(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy the words") { copy() }
                .keyboardShortcut("c")
                .disabled((muse.words ?? "").isEmpty)
            action("waveform", "show the audio in finder") {
                NSWorkspace.shared.activateFileViewerSelecting([MacLibrary.shared.audioURL(for: muse)])
            }
            let saved = MacLibrary.shared.muses.first { $0.id == muse.id }?.isSaved ?? false
            action(saved ? "bookmark.fill" : "bookmark", saved ? "saved · click to unsave" : "save this muse") {
                MacLibrary.shared.toggleSaved(muse.id)
            }
            .keyboardShortcut("s")
            action("trash", "delete this muse", tint: MuseColor.clay) { asksToDelete = true }
                .keyboardShortcut(.delete)
        }
        .padding(.horizontal, MuseSpacing.xxs)
        .frame(height: 40)
        .glassEffect(.regular.tint(MuseColor.raised.opacity(0.5)), in: .capsule)
        .padding(MuseSpacing.lg)
    }

    private func action(_ symbol: String, _ label: String, tint: Color = MuseColor.ink70, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: symbol)
                .font(MuseFont.symbol(14))
                .foregroundStyle(tint)
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
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
