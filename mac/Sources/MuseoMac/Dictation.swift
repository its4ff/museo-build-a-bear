import AppKit
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
    @ObservationIgnored private var hold = 0
    /// Audio that arrived while the hold's recognizer was still starting, in order.
    @ObservationIgnored private var waiting: [LiveAudioChunk] = []
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
            waiting = []
            endedWhileStarting = false
            hasNoRecognizer = false
            FlowBar.shared.listen()
            start(hold)
        case .samples(let chunk):
            MenuVoice.shared.hear(chunk.samples)
            if let speech {
                speech.feed(chunk)
            } else if !hasNoRecognizer {
                waiting.append(chunk)
            }
        case .ended:
            if let speech {
                self.speech = nil
                finish(speech, hold)
            } else {
                endedWhileStarting = true
            }
        }
    }

    private func start(_ hold: Int) {
        Task {
            let speech = await HoldSpeech.begin { words in
                guard self.hold == hold else { return }
                FlowBar.shared.update(words)
            }
            guard let speech else {
                if self.hold == hold {
                    hasNoRecognizer = true
                    waiting = []
                    FlowBar.shared.finish(note: "getting the speech model · this one is saved")
                    print("[museo][mac] no speech model yet: this hold saves, nothing typed")
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

    private func finish(_ speech: HoldSpeech, _ hold: Int) {
        Task {
            let words = await speech.finish()
            guard !words.isEmpty else {
                FlowBar.shared.finish(note: nil)
                return
            }
            lastWords = words
            let app = NSWorkspace.shared.frontmostApplication?.localizedName
            // A trailing space so the next hold's words don't run into these.
            lastTyped = typesIntoApps && TextInserter.insert(words + " ")
            if lastTyped {
                RingWatch.shared.flashTyped()
                MacLibrary.shared.noteTyped(into: app)
                FlowBar.shared.finish(note: app.map { "typed into \($0)" } ?? "typed")
            } else {
                FlowBar.shared.finish(note: "copied · ⌘V to paste")
            }
            print("[museo][mac] hold \(hold): \(lastTyped ? "typed" : "copied") \(words.count) characters")
        }
    }
}
