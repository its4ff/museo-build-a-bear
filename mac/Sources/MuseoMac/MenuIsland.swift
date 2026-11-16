import Foundation
import Observation

/// The menu bar island: while words happen, the ring's pill in the menu bar widens to hold
/// them. While you hold it shows your voice and the words forming; when they land it says
/// where they went ("typed into Notes"), then shrinks back to the ring. A recording from the
/// ring's memory shows here too, with the amber ring.
///
/// Only state lives here. `MenuIcon` draws it.
@MainActor
@Observable
final class MenuIsland {
    static let shared = MenuIsland()

    nonisolated enum Mark: Equatable, Sendable {
        /// Your voice, in cells.
        case voice
        /// The words landed.
        case tick
    }

    /// The island is open.
    private(set) var isOpen = false
    private(set) var mark = Mark.voice
    /// The words so far, this hold.
    private(set) var words = HoldSpeech.Words()
    /// Where the words went: "typed into Notes", "copied".
    private(set) var note: String?
    /// A hold is going.
    private(set) var isListening = false
    /// This hold began with a museo note in front: its island hangs in the note, not at the
    /// screen's notch.
    private(set) var inNote = false
    /// What the words so far would do when you let go: run a command, or be sent. Nil for
    /// plain words.
    private(set) var cue: VoiceCommands.Reading?
    /// A command that just ran: its pill stays, with the tick, as the island closes.
    private(set) var ran: VoiceCommands.Reading?

    /// Apple's words while parakeet's are on the island: read together, the way the hold is
    /// read when you let go, so the pill is the command that will run, as soon as either
    /// recognizer hears it ("Open cloud" from one, "Open Claude." from the other).
    @ObservationIgnored private var appleSaid: String?

    @ObservationIgnored private var closing: Task<Void, Never>?

    // MARK: - A hold

    func listen() {
        closing?.cancel()
        words = HoldSpeech.Words()
        cue = nil
        ran = nil
        appleSaid = nil
        note = nil
        mark = .voice
        inNote = NoteFocus.active != nil
        isListening = true
        isOpen = true
        // Never stuck open: if a hold's end never comes, fold away on its own.
        close(after: 120)
    }

    /// The words on the island, and what they'd do. Parakeet's first words take the island
    /// from apple's, which go on being read beside them (`hint`).
    func update(_ words: HoldSpeech.Words, fromParakeet: Bool = false) {
        guard isListening else { return }
        if fromParakeet, appleSaid == nil {
            appleSaid = MacSpeech.joined(self.words.heard, self.words.hearing)
        }
        self.words = words
        refreshCue()
    }

    /// Apple's words while parakeet's are on the island: not shown, but a command they hear
    /// raises its pill straight away.
    func hint(_ words: HoldSpeech.Words) {
        guard isListening else { return }
        appleSaid = MacSpeech.joined(words.heard, words.hearing)
        refreshCue()
    }

    private func refreshCue() {
        let shown = MacSpeech.joined(words.heard, words.hearing)
        guard Dictation.shared.typesIntoApps, !shown.isEmpty || appleSaid?.isEmpty == false else {
            cue = nil
            return
        }
        let commands = VoiceCommands.shared
        let reading = if let appleSaid {
            commands.read(apple: appleSaid, local: shown.isEmpty ? nil : shown)
        } else {
            commands.read(shown)
        }
        if case .words = reading { cue = nil } else { cue = reading }
    }

    /// The hold's words landed (or didn't): say where for a moment, then close.
    /// A command that ran passes itself as `ran`: its pill stays, with the tick.
    func finish(note: String?, ran: VoiceCommands.Reading? = nil) {
        isListening = false
        cue = nil
        if let ran {
            self.ran = ran
            mark = .tick
            close(after: 1.8)
            return
        }
        guard let note else {
            close(after: 0)
            return
        }
        self.note = note
        mark = .tick
        close(after: 1.8)
    }

    // MARK: - From the ring

    /// A memory recording came over: where it went, by the amber ring.
    private func close(after seconds: Double) {
        closing?.cancel()
        closing = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            isOpen = false
        }
    }
}
