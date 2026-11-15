import AppKit
import Observation
import SwiftUI

/// The flow bar: a small glass capsule at the bottom of the screen, there only while words
/// happen. While you hold it shows your voice and the words forming; when they land it says
/// where they went, then fades. A memory recording that comes over shows here in amber.
///
/// It floats over every app without taking focus or clicks, so typing goes on underneath.
@MainActor
@Observable
final class FlowBar {
    static let shared = FlowBar()

    /// The words so far, this hold.
    private(set) var words = HoldSpeech.Words()
    /// Shown after the words: "typed into Notes", "copied · ⌘V to paste".
    private(set) var note: String?
    /// A recording from the ring's memory, not a hold.
    private(set) var fromRing = false
    /// A hold is going.
    private(set) var isListening = false

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var hiding: Task<Void, Never>?

    private static let size = NSSize(width: 760, height: 84)

    // MARK: - A hold

    func listen() {
        words = HoldSpeech.Words()
        note = nil
        fromRing = false
        isListening = true
        show()
    }

    func update(_ words: HoldSpeech.Words) {
        guard isListening else { return }
        self.words = words
    }

    /// The hold's words landed (or didn't): say so for a moment, then fade.
    func finish(note: String?) {
        isListening = false
        self.note = note
        hide(after: note == nil ? 0.2 : 1.6)
    }

    // MARK: - From the ring

    /// A memory recording came over: its words and where they went, in amber.
    func ring(_ text: String, note: String) {
        isListening = false
        fromRing = true
        words = HoldSpeech.Words(heard: text, hearing: "")
        self.note = note
        show()
        hide(after: 3)
    }

    // MARK: - The panel

    private func show() {
        hiding?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place(panel)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.16
            panel.animator().alphaValue = 1
        }
    }

    private func hide(after seconds: Double) {
        hiding?.cancel()
        hiding = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let panel else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0 : 0.28
                panel.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    if FlowBar.shared.panel?.alphaValue == 0 { FlowBar.shared.panel?.orderOut(nil) }
                }
            }
        }
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: FlowBarView(bar: self))
        return panel
    }

    /// Bottom center of the screen the pointer is on.
    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: area.midX - Self.size.width / 2, y: area.minY + 28))
    }
}

/// What the flow bar draws.
private struct FlowBarView: View {
    let bar: FlowBar
    private let voice = MenuVoice.shared

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            mark
            words
            if let note = bar.note {
                Text(note)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.leading, MuseSpacing.xs)
        .padding(.trailing, MuseSpacing.lg)
        .frame(height: 46)
        .glassEffect(.regular.tint(MuseColor.raised.opacity(0.55)), in: .capsule)
        .shadow(color: MuseColor.moss900.opacity(0.16), radius: 18, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .light)
    }

    /// The voice while you hold; the amber ring for a recording from memory.
    private var mark: some View {
        HStack(spacing: 3) {
            if bar.fromRing {
                Circle().fill(MuseColor.ringAmber).frame(width: 7, height: 7)
                    .shadow(color: MuseColor.ringAmber.opacity(0.8), radius: 4)
            } else {
                ForEach(voice.levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(MuseColor.ground)
                        .frame(width: 3, height: 5 + 15 * (bar.isListening ? voice.levels[index] : 0.2))
                }
            }
        }
        .frame(width: 52, height: 32)
        .background(MuseColor.primaryGradient, in: Capsule())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var words: some View {
        if bar.words.heard.isEmpty, bar.words.hearing.isEmpty {
            Text(bar.isListening ? "listening…" : "nothing heard")
                .font(MuseType.serifItalic)
                .foregroundStyle(MuseColor.ink55)
        } else {
            Text(line)
                .font(MuseType.serif)
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    /// Settled words in ink, the ones still forming lighter.
    private var line: AttributedString {
        var heard = AttributedString(bar.words.heard)
        heard.foregroundColor = MuseColor.ink
        var hearing = AttributedString(bar.words.hearing.isEmpty ? "" : (bar.words.heard.isEmpty ? "" : " ") + bar.words.hearing)
        hearing.foregroundColor = MuseColor.ink55
        return heard + hearing
    }
}
