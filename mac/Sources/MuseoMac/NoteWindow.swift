import AppKit
import SwiftUI

/// A museo note: its own window, the library's size, with nothing on it but the words. You
/// write on the eye line, by hand or by holding the ring. ⌘return ends it and asks once,
/// "name it."; return with nothing typed and the name writes itself. Close the window without
/// ending and it's named in the background. Saved as you go, in the library with the muses.
struct NoteWindow: View {
    static let id = "note"

    let id: UUID

    @State private var library = MacLibrary.shared
    @State private var text = ""
    @State private var startedAt = Date.now
    @State private var isLookingBack = false
    @State private var isNaming = false
    @State private var showsMeta = false
    @State private var hideMeta: Task<Void, Never>?
    @State private var showsShortcuts = false
    @State private var hideShortcuts: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.controlActiveState) private var activeState
    private let asks = NoteAsks.shared

    var body: some View {
        ZStack {
            if isNaming {
                NoteNaming(id: id, words: text, back: { isNaming = false }, done: { dismiss() })
                    .transition(.opacity)
            } else {
                NotePage(text: $text, isLookingBack: $isLookingBack)
                    .opacity(showsShortcuts ? 0 : 1)
                    .transition(.opacity)
                    .overlay(alignment: .bottom) { meta }
                if showsShortcuts {
                    NoteShortcutList()
                        .transition(.opacity)
                        .onTapGesture { showsShortcuts = false }
                }
            }
        }
        .museAnimation(MuseMotion.dissolve, value: isNaming)
        .museAnimation(MuseMotion.dissolve, value: showsShortcuts)
        // Said into this note: "name it", "shortcuts".
        .onChange(of: asks.nameIt) { if activeState == .key { finish() } }
        .onChange(of: asks.shortcuts) { if activeState == .key { listShortcuts() } }
        // A hold into this note: its island hangs from the note's top, not the screen's.
        .overlay(alignment: .top) {
            NoteIsland()
                .ignoresSafeArea(edges: .top)
        }
        .background { MuseBackground() }
        .frame(minWidth: 520, minHeight: 360)
        .preferredColorScheme(.light)
        .onContinuousHover { phase in
            if case .active = phase { reveal() }
        }
        .onAppear(perform: load)
        .onDisappear(perform: leave)
        .onChange(of: text) { _, words in
            save(words)
            showsShortcuts = false
        }
        .background {
            // ⌘return: the note is done, name it.
            Button("") { finish() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    /// The word count and the way out, while the pointer moves.
    private var meta: some View {
        let count = MacLibrary.wordCount(text)
        return Text("\(count) \(count == 1 ? "word" : "words") · ⌘return to name it · say \"shortcuts\"")
            .font(MuseType.caption)
            .foregroundStyle(MuseColor.ink55)
            .padding(.bottom, MuseSpacing.lg)
            .opacity(showsMeta && count > 0 && !showsShortcuts ? 1 : 0)
            .museAnimation(MuseMotion.dissolve, value: showsMeta)
            .accessibilityHidden(!showsMeta)
    }

    // MARK: - Keeping it

    private func load() {
        DockPresence.opened()
        if let note = library.note(id) {
            text = note.words ?? ""
            startedAt = note.createdAt
        }
    }

    private func save(_ words: String) {
        if words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        library.saveNote(id, words: words, startedAt: startedAt)
    }

    /// Closed: nothing written isn't kept; something written and not named is named now.
    private func leave() {
        DockPresence.closed()
        hideMeta?.cancel()
        hideShortcuts?.cancel()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            library.dropNote(id)
        } else if library.note(id)?.name == nil {
            NoteNamer.nameLater(id, words: text)
        }
    }

    private func finish() {
        guard !isNaming, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        library.saveNote(id, words: text, startedAt: startedAt)
        isNaming = true
    }

    /// What you can say, over the page for a few seconds, or until you click or write.
    private func listShortcuts() {
        guard !isNaming else { return }
        showsShortcuts = true
        hideShortcuts?.cancel()
        hideShortcuts = Task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            showsShortcuts = false
        }
    }

    private func reveal() {
        showsMeta = true
        hideMeta?.cancel()
        hideMeta = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showsMeta = false
        }
    }
}

/// The page: the words on the eye line, older lines faded above it, a small moss tick at
/// the line (a breathing orb while you hold the ring). Scroll and everything comes back to
/// full ink; type and the page returns to the line.
struct NotePage: View {
    @Binding var text: String
    @Binding var isLookingBack: Bool
    #if DEBUG
    /// For `ScreenSheet`: a hold's words as they'd form, without a ring.
    var previewForming: String?
    /// For `ScreenSheet`: the last words partway through soaking in.
    var previewLanding = false
    #endif
    @Environment(\.controlActiveState) private var activeState
    @State private var size = CGSize(width: 1080, height: 720)
    private let island = MenuIsland.shared

    /// A hold into this note: the words so far show at the caret in soft ink (the editor
    /// wraps them like the rest), and the tick steps aside.
    private var forming: String? {
        #if DEBUG
        if let previewForming { return previewForming }
        #endif
        guard island.isListening, island.inNote, activeState == .key else { return nil }
        return MacSpeech.joined(island.words.heard, island.words.hearing)
    }

    var body: some View {
        let eye = size.height / 2
        let left = max(MuseSpacing.sectionLabel, (size.width - EyeLineEditor.columnWidth) / 2)
        ZStack(alignment: .topLeading) {
            editor
                .mask { fade(height: size.height) }
            if text.isEmpty, forming == nil {
                Text("hold the ring, or type.")
                    .font(MuseFont.loraItalic(EyeLineEditor.fontSize))
                    .foregroundStyle(MuseColor.ink55.opacity(0.6))
                    .offset(x: left + 6, y: eye - EyeLineEditor.lineHeight / 2 + 6)
                    .allowsHitTesting(false)
            }
            Capsule()
                .fill(MuseColor.moss600)
                .frame(width: 10, height: 2)
                .opacity(isLookingBack || forming != nil ? 0 : 1)
                // Lora sits low in its line: the mark meets the words' middle.
                .position(x: left - MuseSpacing.lg, y: eye + 3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .museAnimation(MuseMotion.dissolve, value: forming == nil)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    private var editor: EyeLineEditor {
        var editor = EyeLineEditor(text: $text, isLookingBack: $isLookingBack, forming: forming)
        #if DEBUG
        editor.previewLanding = previewLanding
        #endif
        return editor
    }

    /// Lines above the eye line fade toward the top; looking back, they all come back.
    private func fade(height: CGFloat) -> some View {
        let clearAt = max(0.3, 0.5 - (EyeLineEditor.lineHeight / 2 + 4) / max(height, 1))
        return ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0.04),
                    .init(color: .black.opacity(0.14), location: 0.2),
                    .init(color: .black.opacity(0.45), location: clearAt - 0.03),
                    .init(color: .black, location: clearAt),
                    .init(color: .black, location: 0.86),
                    .init(color: .black.opacity(0), location: 0.98),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Color.black.opacity(isLookingBack ? 1 : 0)
        }
        .museAnimation(MuseMotion.dissolve, value: isLookingBack)
    }
}

/// The notch island, hanging from the top of a museo note: while you hold, the ring and your
/// voice; when the words land, "in your note · 12 words"; then it folds away. The words
/// themselves form at the line (`NotePage`), not here. In full screen the note's top is the
/// screen's, so it sits at the notch.
struct NoteIsland: View {
    private let island = MenuIsland.shared
    private let voice = MenuVoice.shared
    @Environment(\.controlActiveState) private var activeState
    #if DEBUG
    /// For `ScreenSheet`: drawn open, listening or landed, without a ring.
    var preview: String??
    #endif

    private var isShown: Bool {
        #if DEBUG
        if preview != nil { return true }
        #endif
        return island.isOpen && island.inNote && activeState == .key
    }

    /// Where the words went, once they've landed.
    private var landed: String? {
        #if DEBUG
        if let preview { return preview }
        #endif
        return island.isListening ? nil : island.note
    }

    var body: some View {
        HStack(spacing: MuseSpacing.xs) {
            Image(nsImage: landed == nil ? Self.linen : Self.tick)
                .accessibilityHidden(true)
            if let landed {
                Text(landed)
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.mossTint)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Spacer(minLength: MuseSpacing.xl)
                HStack(spacing: 2) {
                    ForEach(Array(voice.levels.enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .fill(MuseColor.orbHighlight)
                            .frame(width: 2, height: 3 + 10 * level)
                    }
                }
                .frame(height: 14)
                .accessibilityLabel("listening")
            }
        }
        .padding(.horizontal, MuseSpacing.sm)
        .frame(height: 30)
        .frame(minWidth: 140)
        .background(Color.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
        .fixedSize()
        .offset(y: isShown ? 0 : -34)
        .opacity(isShown ? 1 : 0)
        .museAnimation(MuseMotion.smooth, value: isShown)
        .museAnimation(MuseMotion.smooth, value: landed)
        .allowsHitTesting(false)
    }

    private static let linen = DotRingIcon.small(.linen, size: 12)
    private static let tick = DotRingIcon.small(.tick, size: 12)
}

/// "name it.": museo's name waits in faint ink. Type your own and return keeps it; return
/// with nothing typed and museo's name writes itself in. Escape goes back to the words.
struct NoteNaming: View {
    let id: UUID
    let words: String
    var back: () -> Void
    var done: () -> Void

    @State private var typed = ""
    @State private var suggestion: String?
    @State private var isWritingItself = false
    @FocusState private var isTyping: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = MacLibrary.wordCount(words)
        VStack(spacing: MuseSpacing.sm) {
            MuseEyebrow("name it.")
            TextField("the note's name", text: $typed, prompt: Text(""))
                .textFieldStyle(.plain)
                .font(MuseFont.lora(32))
                .foregroundStyle(MuseColor.ink)
                .tint(MuseColor.moss)
                .multilineTextAlignment(.center)
                .focused($isTyping)
                .disabled(isWritingItself)
                .onSubmit(keep)
                .onExitCommand { if !isWritingItself { back() } }
                .frame(width: 460)
                // museo's name in faint ink until you type (a prompt's color isn't ours on a mac).
                .background {
                    if typed.isEmpty {
                        Text(suggestion ?? "naming it…")
                            .font(MuseFont.lora(32))
                            .foregroundStyle(MuseColor.ink55.opacity(0.45))
                            .lineLimit(1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("the note's name")
                .accessibilityValue(typed.isEmpty ? (suggestion ?? "") : typed)
            Rectangle()
                .fill(MuseColor.moss.opacity(0.5))
                .frame(width: 460, height: 1)
            Text(isWritingItself ? "named on this mac" : "return keeps it · or type your own · \(count) \(count == 1 ? "word" : "words")")
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
                .padding(.top, MuseSpacing.xxs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isTyping = true
            if let note = MacLibrary.shared.note(id), note.nameIsTheirs == true, let name = note.name {
                typed = name
            }
        }
        .task { suggestion = await NoteNamer.name(for: words) }
    }

    private func keep() {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            MacLibrary.shared.nameNote(id, name, theirs: true)
            done()
            return
        }
        guard !isWritingItself else { return }
        isWritingItself = true
        Task {
            var name = suggestion
            while name == nil {
                try? await Task.sleep(for: .milliseconds(100))
                name = suggestion
            }
            guard let name else { return }
            // The name writes itself, a letter at a time.
            if reduceMotion {
                typed = name
            } else {
                for letter in name {
                    typed.append(letter)
                    try? await Task.sleep(for: .milliseconds(38))
                }
            }
            MacLibrary.shared.nameNote(id, name, theirs: false)
            try? await Task.sleep(for: .milliseconds(900))
            done()
        }
    }
}

/// museo shows in the dock and ⌘tab while the library or a note is open, and goes back to
/// the menu bar when the last one closes.
@MainActor
enum DockPresence {
    private static var open = 0

    static func opened() {
        open += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func closed() {
        open = max(0, open - 1)
        if open == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}

/// The plus beside stats and settings: a new note.
struct NewNoteButton: View {
    @Environment(\.openWindow) private var openWindow
    @State private var isHovered = false

    var body: some View {
        Button {
            openWindow(id: NoteWindow.id, value: UUID())
        } label: {
            Image(systemName: "plus")
                .font(MuseFont.symbol(12))
                .foregroundStyle(MuseColor.ink55)
                .frame(width: 28, height: 28)
                .background(isHovered ? MuseColor.moss.opacity(0.1) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("new note · ⌘N")
        .accessibilityLabel("new note")
    }
}

/// ⌘N, anywhere in museo: a new note.
struct NoteCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("new note") { openWindow(id: NoteWindow.id, value: UUID()) }
                .keyboardShortcut("n")
        }
    }
}
