import SwiftUI

/// How sure the recognizer was of a muse's words, as a tag whose shade follows the number:
/// ochre when it was unsure, moss when it was sure, and every step between. `.compact` is
/// the tile's "91%"; `.full` the muse page's "transcription confidence score · 91%".
///
/// ```swift
/// if let confidence = muse.wordConfidence { MuseConfidenceTag(confidence, style: .compact) }
/// ```
///
/// The number is Apple speech's own mean word confidence (`Muse.wordConfidence`), a guess
/// rather than a measured accuracy. Voz and typed muses have none, so they get no tag.
struct MuseConfidenceTag: View {
    enum Style {
        case compact
        case full
    }

    let confidence: Double
    var style: Style

    init(_ confidence: Double, style: Style = .full) {
        self.confidence = confidence
        self.style = style
    }

    var body: some View {
        Text(verbatim: label)
            .font(style == .compact ? MuseType.caption : MuseType.meta)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(Self.ink(sureness))
            .padding(.horizontal, style == .compact ? MuseSpacing.xs : MuseSpacing.sm)
            .padding(.vertical, style == .compact ? MuseSpacing.xxs : 6)
            .background(Self.wash(sureness), in: RoundedRectangle(cornerRadius: MuseRadius.tag, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("transcription confidence \(percent)")
    }

    /// "91%".
    var percent: String {
        min(max(confidence, 0), 1).formatted(.percent.precision(.fractionLength(0)))
    }

    private var label: String {
        style == .compact ? percent : "transcription confidence score \u{00B7} \(percent)"
    }

    /// 0 at 50% and under (all ochre), 1 at 95% and over (all moss). The recognizer seldom
    /// says less than half, and past 95 it's sure.
    private var sureness: Double {
        min(max((confidence - 0.5) / 0.45, 0), 1)
    }

    private static func ink(_ sureness: Double) -> Color {
        MuseColor.ochreInk.mix(with: MuseColor.moss600, by: sureness, in: .perceptual)
    }

    private static func wash(_ sureness: Double) -> Color {
        MuseColor.ochreTint.mix(with: MuseColor.mossTint, by: sureness, in: .perceptual)
    }
}
