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
        .background { MuseBackground() }
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
            .background { MuseBackground() }
            .overlay(alignment: .topTrailing) { actions }
    }
    #endif

    private var page: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xl) {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                Text([note.createdAt.musePageDate, note.createdAt.museClock, note.meta].joined(separator: " · "))
                    .font(MuseFont.mono(.caption))
                    .foregroundStyle(MuseColor.ink55)
                Text(note.name ?? "naming it…")
                    .font(note.name == nil ? MuseFont.loraItalic(40) : MuseType.display)
                    .tracking(MuseType.displayTracking)
                    .foregroundStyle(note.name == nil ? MuseColor.ink55 : MuseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(note.words ?? "")
                .font(MuseFont.lora(22))
                .foregroundStyle(MuseColor.ink)
                .lineSpacing(MuseSpacing.xs)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                openWindow(id: NoteWindow.id, value: note.id)
            } label: {
                Text("open the note")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .padding(.horizontal, MuseSpacing.sm)
                    .frame(height: 28)
                    .background(MuseColor.mossTint, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 700, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sectionLabel)
        .padding(.top, 88)
        .padding(.bottom, MuseSpacing.sectionLabel)
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            action("square.and.pencil", "open the note") { openWindow(id: NoteWindow.id, value: note.id) }
                .keyboardShortcut("o")
            action(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy the words") { copy() }
                .keyboardShortcut("c")
            action("trash", "delete this note", tint: MuseColor.clay) { asksToDelete = true }
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
        NSPasteboard.general.setString([note.name, note.words].compactMap { $0 }.joined(separator: "\n\n"), forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
