import Foundation
import SwiftUI

/// The muse that just came in during the onboarding, as the home will show it: when, how
/// long, where from, then its words typing in (or a quiet line while they're on their way).
/// Its own small card so the first run doesn't lean on the library's.
struct OnboardingMuseCard: View {
    let muse: Muse
    /// Type the words in when they land. Off, they just show.
    var types = true
    /// The words finished typing (or showed at once).
    var onTyped: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            HStack(alignment: .center, spacing: MuseSpacing.xs) {
                Text(verbatim: "\(muse.createdAt.museClock) · \(muse.duration.museDuration)")
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: MuseSpacing.xs)
                if muse.origin == .offline {
                    Circle()
                        .fill(MuseColor.ochre)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                MuseRingMark(size: 12, color: MuseColor.ink55)
            }
            content
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: muse.transcriptionState)
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: muse.title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder
    private var content: some View {
        let words = muse.words
        if !muse.isTranscribed {
            Text(muse.transcriptionState == .failed ? "the words didn't come through this time." : "words land in a moment…")
                .font(MuseType.serifItalic)
                .foregroundStyle(MuseColor.ink55)
                .transition(.opacity)
        } else if muse.isBlank || words.isEmpty {
            Text("blank muse")
                .font(MuseType.serifItalic)
                .foregroundStyle(MuseColor.ink55)
                .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                if let title = muse.title, !title.isEmpty {
                    Text(title)
                        .font(MuseType.titleSmall)
                        .tracking(MuseType.titleTracking)
                        .foregroundStyle(MuseColor.ink)
                        .lineLimit(2)
                        .transition(.opacity)
                }
                quoted(words)
            }
            .transition(.opacity)
        }
    }

    /// Their words in curly quotes, the opening one hung in the margin like the home's.
    private func quoted(_ words: String) -> some View {
        let text = words + "\u{201D}"
        return Group {
            if types {
                MuseInkText(
                    text,
                    font: MuseType.serif,
                    color: MuseColor.ink,
                    typingLimit: 180,
                    onFinish: onTyped
                )
            } else {
                Text(text)
                    .font(MuseType.serif)
                    .foregroundStyle(MuseColor.ink)
                    .onAppear(perform: onTyped)
            }
        }
        .lineSpacing(MuseType.serifLineSpacing)
        .lineLimit(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            Text(verbatim: "\u{201C}")
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink)
                .alignmentGuide(.leading) { $0[.trailing] }
                .accessibilityHidden(true)
        }
    }

    private var spoken: String {
        var parts = [muse.createdAt.museClock, muse.duration.museDuration, muse.origin.label]
        if !muse.isTranscribed {
            parts.append("words land in a moment")
        } else if muse.isBlank || muse.words.isEmpty {
            parts.append("blank muse")
        } else {
            if let title = muse.title { parts.append(title) }
            parts.append(muse.words)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("onboarding muse") {
    VStack(spacing: MuseSpacing.sm) {
        OnboardingMuseCard(
            muse: Muse(
                createdAt: .now, duration: 4, origin: .stream,
                transcript: "the light on the canal at six is the green we want for the box.",
                transcriptionState: .complete
            )
        )
        OnboardingMuseCard(muse: Muse(createdAt: .now, duration: 6, origin: .offline, transcriptionState: .transcribing))
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseBackground() }
}
