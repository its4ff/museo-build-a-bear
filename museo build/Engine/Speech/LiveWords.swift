import Foundation
import MuseoKit
import Observation
import SwiftUI

/// Words while you hold the ring: what the streaming card and onboarding show as you speak.
///
/// Listens to `Museo.liveAudio()` only while museo build is on screen (`AppStart` turns it on
/// and off), and starts a `LiveSpeech` for each hold. The words stay up after the hold ends,
/// until the next one begins, so the card can hold them while the muse lands.
@MainActor
@Observable
final class LiveWords {
    static let shared = LiveWords()

    /// Words the recognizer has settled on, this hold.
    private(set) var heard = ""
    /// Words still forming at the end; they can change.
    private(set) var hearing = ""

    /// Both, as one line.
    var text: String {
        [heard, hearing].filter { !$0.isEmpty }.joined(separator: " ")
    }

    @ObservationIgnored private var listening: Task<Void, Never>?
    @ObservationIgnored private var speech: LiveSpeech?
    /// The hold the words belong to. A recognizer that starts after its hold moved on is dropped.
    @ObservationIgnored private var hold = 0
    /// Audio that arrived while the hold's recognizer was still starting, in order.
    @ObservationIgnored private var waiting: [LiveAudioChunk] = []
    @ObservationIgnored private var endedWhileStarting = false
    /// This iphone has no speech model for the hold's language yet: its audio is let go.
    @ObservationIgnored private var hasNoRecognizer = false
    @ObservationIgnored private var isPreview = false

    /// Fixed words for previews and lab screens. Never listens.
    static func preview(heard: String, hearing: String = "") -> LiveWords {
        let words = LiveWords()
        words.isPreview = true
        words.heard = heard
        words.hearing = hearing
        return words
    }

    // MARK: - On and off

    /// Starts listening. Safe to call again.
    func listen() {
        guard !isPreview, listening == nil else { return }
        listening = Task { [weak self] in
            for await piece in Museo.liveAudio() {
                self?.take(piece)
            }
        }
    }

    /// Stops listening (museo build left the screen). The ring's recording still comes in.
    func stop() {
        listening?.cancel()
        listening = nil
        speech?.cancel()
        speech = nil
        waiting = []
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
            heard = ""
            hearing = ""
            start(hold)
        case .samples(let chunk):
            if let speech {
                speech.feed(chunk)
            } else if !hasNoRecognizer {
                waiting.append(chunk)
            }
        case .ended:
            if let speech {
                Task { await speech.finish() }
            } else {
                endedWhileStarting = true
            }
        }
    }

    private func start(_ hold: Int) {
        Task {
            let speech = await LiveSpeech.begin { [weak self] words in
                guard let self, self.hold == hold else { return }
                self.heard = words.heard
                self.hearing = words.hearing
            }
            guard let speech else {
                if self.hold == hold {
                    hasNoRecognizer = true
                    waiting = []
                }
                return
            }
            guard self.hold == hold else {
                speech.cancel()
                return
            }
            self.speech = speech
            for chunk in waiting { speech.feed(chunk) }
            waiting = []
            if endedWhileStarting { await speech.finish() }
        }
    }
}

extension EnvironmentValues {
    /// Words while you hold the ring. Nil in previews that don't set it: no words show.
    @Entry var museLiveWords: LiveWords? = nil
}
