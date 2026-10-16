import Foundation
import SwiftUI
import MuseoKit

/// Hold to stream: the booklet's hand shows where the thumb goes. Hold the ring, say a
/// sentence, let go. The streaming card counts while they
/// speak, their words forming in it as they say them, holds as "keeping it", then the muse
/// itself lands with its words typing in. "streamed in." holds a moment and memory comes up
/// (or they tap next).
struct OnboardingStreamStep: View {
    let model: Onboarding

    @Environment(\.museLiveWords) private var liveWords

    var body: some View {
        OnboardingPage(
            title: landedWithWords ? "streamed in." : "hold to stream.",
            line: landedWithWords
                ? "sent straight to this iphone."
                : "press with your thumb and talk. let go to send.",
            note: note,
            recipe: RingRecipeLine(gesture: .hold, name: "hold", light: .white, result: "sent straight to your iphone")
        ) {
            stage
                .frame(minHeight: OnboardingMetrics.well)
                .museAnimation(MuseMotion.drift, value: stageKey)
        } buttons: {
            if case .landed = model.stream {
                OnboardingPrimary("next") { model.next() }
            } else {
                MuseQuietButton("skip for now") { model.next() }
            }
        }
    }

    // MARK: Stage

    @ViewBuilder
    private var stage: some View {
        switch model.stream {
        case .waiting, .tooShort, .blank:
            // How to hold it, as the booklet draws it: on the index finger, the button
            // toward the thumb.
            MuseHandArt(width: 300)
                .transition(.opacity)
        case .listening(let since):
            holding(since: since, endedAt: nil)
        case .keeping(let since, let endedAt):
            holding(since: since, endedAt: endedAt)
        case .landed(let muse):
            OnboardingMuseCard(muse: muse, onTyped: model.wordsShown)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    /// The band with its white light on while they hold, the streaming card counting under it
    /// with their words. One view for listening and keeping, so letting go only dims the light.
    private func holding(since: Date, endedAt: Date?) -> some View {
        VStack(spacing: MuseSpacing.md) {
            MuseRingBand(light: .white, lit: endedAt == nil, height: 120)
            StreamingMuseCard(
                since: since,
                endedAt: endedAt,
                heard: liveWords?.heard ?? "",
                hearing: liveWords?.hearing ?? ""
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    /// Changes only when the stage swaps what it shows, not when its words land.
    private var stageKey: Int {
        switch model.stream {
        case .waiting, .tooShort, .blank: 0
        case .listening, .keeping: 1
        case .landed: 2
        }
    }

    private var landedWithWords: Bool {
        guard case .landed(let muse) = model.stream else { return false }
        return muse.isTranscribed && !muse.isBlank && !muse.words.isEmpty
    }

    // MARK: Words

    private var note: String? {
        switch model.stream {
        case .tooShort: return "hold a little longer, then talk."
        case .blank: return "nothing came through. hold it closer and try again."
        case .landed(let muse):
            return model.isSlow && !muse.isTranscribed ? "the words are on their way. you can go on." : nil
        case .waiting:
            return model.ring.isLinked ? nil : "bring your ring close. it links on its own."
        case .listening, .keeping:
            return nil
        }
    }
}
