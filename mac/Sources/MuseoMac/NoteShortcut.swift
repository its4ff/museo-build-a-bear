import AppKit
import Observation
import SwiftUI

/// What a museo note does when a hold says only this. These are the note's own, always on,
/// and not in commands.json: a note is museo's page, so its shortcuts can't be edited away.
/// Like any command, the phrase is the whole hold, so none fires from inside a sentence.
/// Nothing spoken deletes the note itself: "delete that" takes back your last hold, and
/// "undo" writes it in again.
nonisolated enum NoteShortcut: CaseIterable, Sendable {
    case fullScreen, minimize, close, undo, redo, newLine, newParagraph, deleteThat, copyIt, nameIt, shortcuts

    /// Ways to say it, lowercase, without punctuation.
    var say: [String] {
        switch self {
        case .fullScreen: ["full screen", "fullscreen", "go full screen", "exit full screen", "leave full screen"]
        case .minimize: ["minimize", "minimise", "minimize it", "minimise it"]
        case .close: ["close", "close it", "close the note"]
        case .undo: ["undo", "undo that", "scratch that"]
        case .redo: ["redo", "redo that"]
        case .newLine: ["new line", "next line"]
        case .newParagraph: ["new paragraph", "next paragraph"]
        case .deleteThat: ["delete that", "delete", "take that back"]
        case .copyIt: ["copy it", "copy that", "copy the note"]
        case .nameIt: ["name it", "name the note"]
        case .shortcuts: ["shortcuts", "show shortcuts", "what can i say"]
        }
    }

    /// The shortcut a hold was, from either reading of it (dictation's, and the downloaded
    /// model's): dictation hears short phrases cleanly where a model can mangle them.
    static func read(apple: String, local: String?) -> NoteShortcut? {
        for heard in [apple, local].compactMap({ $0 }) where !heard.isEmpty {
            let said = VoiceCommands.plain(heard)
            if let shortcut = allCases.first(where: { $0.say.contains(said) }) { return shortcut }
        }
        return nil
    }

    /// What to say and what it does, for the list in the note.
    static let list: [(say: String, does: String)] = [
        ("full screen", "the note fills the screen"),
        ("minimize", "tucks the note away"),
        ("undo · redo", "the last thing, back or again"),
        ("new line · new paragraph", "moves down the page"),
        ("delete that", "takes back your last hold"),
        ("copy it", "the whole note"),
        ("name it", "ends the note"),
        ("close", "closes it, kept in the library"),
    ]

    /// The voice commands that work from a note as well, while voice commands are on.
    static let leaving: [(say: String, does: String)] = [
        ("switch app", "the app you were just in"),
        ("open slack", "or any app, by its name"),
    ]
}

/// Shortcuts the note's window answers, not its words: the page watches these.
@MainActor
@Observable
final class NoteAsks {
    static let shared = NoteAsks()
    private(set) var nameIt = 0
    private(set) var shortcuts = 0

    func askToNameIt() { nameIt += 1 }
    func askForShortcuts() { shortcuts += 1 }
}

extension EyeLineTextView {
    /// Does `shortcut` in this note, and says what happened, for the island.
    func run(_ shortcut: NoteShortcut) -> String {
        switch shortcut {
        case .fullScreen:
            let isFull = window?.styleMask.contains(.fullScreen) ?? false
            window?.toggleFullScreen(nil)
            return isFull ? "back to the window" : "full screen"
        case .minimize:
            window?.miniaturize(nil)
            return "minimized"
        case .close:
            window?.performClose(nil)
            return "closed"
        case .undo:
            guard undoManager?.canUndo == true else { return "nothing to undo" }
            undoLast()
            return "undone"
        case .redo:
            guard undoManager?.canRedo == true else { return "nothing to redo" }
            undoManager?.redo()
            return "redone"
        case .newLine:
            insertText("\n", replacementRange: selectedRange())
            return "new line"
        case .newParagraph:
            insertText("\n\n", replacementRange: selectedRange())
            return "new paragraph"
        case .deleteThat:
            return deleteSpoken() ? "deleted" : "nothing to delete"
        case .copyIt:
            let words = committedString
            guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "nothing to copy" }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(words, forType: .string)
            return "copied"
        case .nameIt:
            NoteAsks.shared.askToNameIt()
            return "name it"
        case .shortcuts:
            NoteAsks.shared.askForShortcuts()
            return "shortcuts"
        }
    }
}

/// What you can say in a note, in faint ink over the page. Their phrases in Lora, what each
/// does in Satoshi.
struct NoteShortcutList: View {
    private var rows: [(say: String, does: String)] {
        NoteShortcut.list + (VoiceCommands.shared.isOn ? NoteShortcut.leaving : [])
    }

    var body: some View {
        VStack(spacing: MuseSpacing.xl) {
            MuseEyebrow("hold the ring and say one")
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: MuseSpacing.xl, verticalSpacing: MuseSpacing.sm) {
                ForEach(rows, id: \.say) { row in
                    GridRow {
                        Text(row.say)
                            .font(MuseFont.loraItalic(22))
                            .foregroundStyle(MuseColor.ink)
                        Text(row.does)
                            .font(MuseType.caption)
                            .foregroundStyle(MuseColor.ink55)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
