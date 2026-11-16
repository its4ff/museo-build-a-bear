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
        .background { MuseBackground() }
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
                Text("\(ids.count) muses.")
                    .font(MuseType.display)
                    .tracking(MuseType.displayTracking)
                    .foregroundStyle(MuseColor.ink)
            }
            VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                ForEach(muses) { muse in
                    VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                        Text("\(muse.createdAt.museClock) · \(muse.meta)")
                            .font(MuseType.caption)
                            .foregroundStyle(MuseColor.ink55)
                        Text(muse.words.map { $0.isEmpty ? "blank muse" : $0 } ?? "hearing it…")
                            .font(muse.words?.isEmpty == false ? MuseFont.lora(17) : MuseFont.loraItalic(17))
                            .foregroundStyle(muse.words?.isEmpty == false ? MuseColor.ink : MuseColor.ink55)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            footer
        }
        .frame(maxWidth: 700, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sectionLabel)
        .padding(.top, 88)
        .padding(.bottom, MuseSpacing.sectionLabel)
        .frame(maxWidth: .infinity)
    }

    /// "picked · 12:31 in all".
    private var eyebrow: String {
        let total = muses.reduce(0) { $0 + $1.duration }
        return "picked · \(total.museDuration) in all"
    }

    private var footer: some View {
        HStack {
            Text("copied oldest first, a line between each")
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Spacer()
            Text("⌘C copy all · ⌘⌫ delete · esc let go")
                .font(MuseFont.mono(.caption2))
                .foregroundStyle(MuseColor.ink55)
        }
        .padding(.top, MuseSpacing.md)
        .overlay(alignment: .top) { Rectangle().fill(MuseColor.hairline).frame(height: 1) }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 2) {
            action(copied ? "checkmark" : "square.on.square", copied ? "copied" : "copy all their words") { copy() }
                .keyboardShortcut("c")
            action("xmark", "let them go") { MacLibrary.shared.picked = [] }
                .keyboardShortcut(.escape, modifiers: [])
            action("trash", "delete these muses", tint: MuseColor.clay) { asksToDelete = true }
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
        TextInserter.copy(MacLibrary.shared.words(of: ids))
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
