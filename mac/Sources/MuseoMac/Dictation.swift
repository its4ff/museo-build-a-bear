import AppKit
import Carbon.HIToolbox
import Foundation
import MuseoKit
import Observation

/// Hold the ring, talk, let go: the words are typed into the app in front.
///
/// Listens to `Museo.liveAudio()` for the life of the app and starts a `HoldSpeech` for each
/// hold, the way museo build's `LiveWords` does for its streaming card.
@MainActor
@Observable
final class Dictation {
    static let shared = Dictation()

    /// Type into the app in front. Off: the words are only copied.
    var typesIntoApps: Bool {
        didSet { UserDefaults.standard.set(typesIntoApps, forKey: Self.typesKey) }
    }
    /// The last hold's words, for the menu.
    private(set) var lastWords = ""
    private(set) var lastTyped = false
    /// This mac has no speech model yet: holds still save, nothing is typed.
    private(set) var hasNoRecognizer = false

    @ObservationIgnored private var listening: Task<Void, Never>?
    @ObservationIgnored private var speech: HoldSpeech?
    /// The downloaded model hearing the hold as it goes, when there is one.
    @ObservationIgnored private var parakeet: HoldParakeet?
    /// Its words have reached the island this hold: apple's step aside.
    @ObservationIgnored private var parakeetSpeaks = false
    @ObservationIgnored private var hold = 0
    /// Audio that arrived while the hold's recognizer was still starting, in order.
    @ObservationIgnored private var waiting: [LiveAudioChunk] = []
    /// The whole hold so far, 16 kHz, for a downloaded model to hear again when it ends.
    @ObservationIgnored private var heard: [Int16] = []
    /// When this hold began, to find its recording in the library.
    @ObservationIgnored private var holdStarted = Date.now
    @ObservationIgnored private var endedWhileStarting = false

    private static let typesKey = "museo.mac.typesIntoApps"

    private init() {
        typesIntoApps = UserDefaults.standard.object(forKey: Self.typesKey) as? Bool ?? true
    }

    func start() {
        guard listening == nil else { return }
        listening = Task { [weak self] in
            for await piece in Museo.liveAudio() {
                self?.take(piece)
            }
        }
    }

    // MARK: - A hold

    private func take(_ piece: LiveAudio) {
        switch piece {
        case .began:
            hold += 1
            speech?.cancel()
            speech = nil
            parakeet?.stop()
            parakeetSpeaks = false
            let hold = self.hold
            parakeet = HoldParakeet.begin { [weak self] words in
                guard let self, self.hold == hold else { return }
                parakeetSpeaks = true
                MenuIsland.shared.update(words, fromParakeet: true)
            }
            waiting = []
            heard = []
            holdStarted = .now
            endedWhileStarting = false
            hasNoRecognizer = false
            MenuIsland.shared.listen()
            // The panel open would take the words: it holds the focus. Out of the way, so
            // they land where you were.
            MenuPanelWindow.closeIfOpen()
            start(hold)
        case .samples(let chunk):
            MenuVoice.shared.hear(chunk.samples)
            heard.append(contentsOf: chunk.samples)
            parakeet?.feed(chunk.samples)
            if let speech {
                speech.feed(chunk)
            } else if !hasNoRecognizer {
                waiting.append(chunk)
            }
        case .ended:
            parakeet?.stop()
            parakeet = nil
            if let speech {
                self.speech = nil
                finish(speech, hold)
            } else if hasNoRecognizer {
                // No apple model for the island, but a downloaded one may still hear it.
                finish(nil, hold)
            } else {
                endedWhileStarting = true
            }
        }
    }

    private func start(_ hold: Int) {
        Task {
            let speech = await HoldSpeech.begin { words in
                // Apple's words fill the first moment; once parakeet's arrive, they carry it,
                // and apple's only raise a command's pill early.
                guard self.hold == hold else { return }
                if self.parakeetSpeaks {
                    MenuIsland.shared.hint(words)
                } else {
                    MenuIsland.shared.update(words)
                }
            }
            guard let speech else {
                if self.hold == hold {
                    hasNoRecognizer = true
                    waiting = []
                    if endedWhileStarting { finish(nil, hold) }
                    print("[museo][mac] no apple speech model for the island")
                }
                return
            }
            guard self.hold == hold else {
                speech.cancel()
                return
            }
            for chunk in waiting { speech.feed(chunk) }
            waiting = []
            if endedWhileStarting {
                finish(speech, hold)
            } else {
                self.speech = speech
            }
        }
    }

    private func finish(_ speech: HoldSpeech?, _ hold: Int) {
        let audio = heard
        let started = holdStarted
        heard = []
        Task {
            // Apple's words settle first; a downloaded model then hears the whole hold again
            // and its words win. Either one alone is enough.
            // Both at once: the model's pass doesn't wait for apple to settle.
            let heardAgain = Task { await LocalSpeech.shared.words(of: audio) }
            let apple = YourWords.shared.respell(await speech?.finish() ?? "")
            let local = await heardAgain.value.map(YourWords.shared.respell)
            let words = local ?? apple
            guard !words.isEmpty else {
                MenuIsland.shared.finish(note: speech == nil && local == nil ? "getting the speech model" : nil)
                return
            }
            lastWords = words
            // A museo note in front: the words go straight in at its caret, whatever the
            // switch says. A hold that only says one of the note's shortcuts does that instead.
            if let note = NoteFocus.active {
                lastTyped = true
                if let shortcut = NoteShortcut.read(apple: apple, local: local) {
                    let did = note.run(shortcut)
                    MacLibrary.shared.forgetCommandHold(startedAt: started)
                    MenuIsland.shared.finish(note: did)
                    print("[museo][note] hold \(hold): \(did)")
                    return
                }
                // The voice commands that leave the note run from one too: "switch app", and
                // "open" an app. The rest press keys that mean nothing on a page.
                if case .command(let command, let said) = VoiceCommands.shared.read(apple: apple, local: local),
                   command.keys == "cmd+tab" || command.open != nil, VoiceCommands.shared.run(command) {
                    lastTyped = false
                    MacLibrary.shared.forgetCommandHold(startedAt: started)
                    CommandTally.shared.add(command.say.first ?? said)
                    MenuIsland.shared.finish(note: said)
                    print("[museo][note] hold \(hold): \"\(said)\" ran from a note")
                    return
                }
                note.insertSpoken(words)
                MacLibrary.shared.noteTyped(into: "your note")
                let count = MacLibrary.wordCount(words)
                MenuIsland.shared.finish(note: "in your note · \(count) \(count == 1 ? "word" : "words")")
                print("[museo][note] hold \(hold): \(words.count) characters into a note")
                return
            }
            guard typesIntoApps else {
                TextInserter.copy(words + " ")
                land(.copied, hold, words)
                return
            }
            switch VoiceCommands.shared.read(apple: apple, local: local) {
            case .command(let command, let said):
                let ran = VoiceCommands.shared.run(command)
                lastTyped = false
                // A command isn't something you said to keep.
                if ran {
                    MacLibrary.shared.forgetCommandHold(startedAt: started)
                    CommandTally.shared.add(command.say.first ?? said)
                }
                if ran {
                    MenuIsland.shared.finish(note: nil, ran: .command(command, said: said))
                } else {
                    MenuIsland.shared.finish(note: "couldn't \(said)")
                }
                print("[museo][command] hold \(hold): \"\(said)\" \(ran ? "ran" : "couldn't run")")
            case .ask(let agent, let text, let send):
                if await AgentHandoff.hand(text, to: agent, send: send) {
                    lastTyped = true
                    MacLibrary.shared.noteTyped(into: agent.app, sent: send)
                    CommandTally.shared.add("hey \(agent.say)")
                    MenuIsland.shared.finish(note: send ? "sent to \(agent.say)" : "in \(agent.say)")
                    print("[museo][agent] hold \(hold): \(send ? "sent" : "typed") \(text.count) characters to \(agent.app)")
                } else {
                    // Claude didn't come forward: the words go where you were, as any hold's.
                    land(TextInserter.insert(text + " "), hold, text)
                }
            case .typeThenSend(let kept):
                let landing = TextInserter.insert(kept)
                if landing != .copied {
                    // Let the paste land before return goes after it.
                    try? await Task.sleep(for: .milliseconds(250))
                    TextInserter.press(CGKeyCode(kVK_Return))
                }
                land(landing, hold, kept, sent: true)
                CommandTally.shared.add("send")
            case .words(let words):
                // A trailing space so the next hold's words don't run into these.
                land(TextInserter.insert(words + " "), hold, words)
            }
        }
    }

    /// Says where a hold's words went.
    private func land(_ landing: TextInserter.Landing, _ hold: Int, _ words: String, sent: Bool = false) {
        switch landing {
        case .typed(let app):
            lastTyped = true
            RingWatch.shared.flashTyped()
            MacLibrary.shared.noteTyped(into: app, sent: sent)
            // The app only when the focused field told us; never a guess.
            let done = sent ? "sent" : "typed"
            MenuIsland.shared.finish(note: app.map { "\(done) into \($0)" } ?? done)
        case .copied:
            lastTyped = false
            MenuIsland.shared.finish(note: "copied · ⌘V to paste")
        }
        print("[museo][mac] hold \(hold): \(lastTyped ? (sent ? "sent" : "typed") : "copied") \(words.count) characters")
    }
}
