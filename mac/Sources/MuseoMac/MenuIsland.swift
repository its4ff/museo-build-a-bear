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

    @ObservationIgnored private var closing: Task<Void, Never>?

    // MARK: - A hold

    func listen() {
        closing?.cancel()
        words = HoldSpeech.Words()
        cue = nil
        note = nil
        mark = .voice
        inNote = NoteFocus.active != nil
        isListening = true
        isOpen = true
        // Never stuck open: if a hold's end never comes, fold away on its own.
        close(after: 120)
    }

    func update(_ words: HoldSpeech.Words) {
        guard isListening else { return }
        self.words = words
        let said = MacSpeech.joined(words.heard, words.hearing)
        let reading = Dictation.shared.typesIntoApps ? VoiceCommands.shared.read(said) : .words(said)
        if case .words = reading { cue = nil } else { cue = reading }
    }

    /// The hold's words landed (or didn't): say where for a moment, then close.
    func finish(note: String?) {
        isListening = false
        cue = nil
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
