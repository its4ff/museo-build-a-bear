import SwiftUI

/// A muse's notes on its page, above the words. What shows depends on the kind
/// (`MuseNotes.kind`):
///
/// - a brief: the eyebrow "notes" and three to five bullets on an inset well.
/// - a long thought: the bullets under "the thought · light" (or heavy, or level), then
///   "threads", "moments" and "to do". Without bullets the overview stands in for them.
///
/// ```swift
/// if let notes = muse.notes { MuseNotesView(notes: notes) }
/// ```
///
/// The to-dos are plain lines: they're what was said out loud, and nothing is scheduled.
struct MuseNotesView: View {
    let notes: MuseNotes

    var body: some View {
        switch notes.kind {
        case .brief:
            NoteBullets(bullets: notes.bullets, eyebrow: "notes")
        case .longThought:
            longThought
        }
    }

    // MARK: Long thought

    private var longThought: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
            if !notes.bullets.isEmpty {
                NoteBullets(bullets: notes.bullets, eyebrow: thoughtEyebrow)
            } else if let overview = notes.overview?.trimmingCharacters(in: .whitespacesAndNewlines), !overview.isEmpty {
                section(thoughtEyebrow) {
                    Text(overview)
                        .font(MuseFont.lora(17, weight: .medium))
                        .lineSpacing(MuseType.serifLineSpacing)
                        .foregroundStyle(MuseColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !notes.threads.isEmpty {
                section("threads") { threads }
            }
            if !notes.moments.isEmpty {
                section("moments") {
                    VStack(alignment: .leading, spacing: MuseSpacing.md) {
                        ForEach(notes.moments, id: \.self) { moment in
                            MomentRow(moment: moment)
                        }
                    }
                }
            }
            if !notes.actions.isEmpty {
                section("to do") {
                    VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                        ForEach(notes.actions, id: \.self) { action in
                            ActionLine(text: action)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "the thought · light", or "the thought" without a mood.
    private var thoughtEyebrow: String {
        notes.moodWord.map { "the thought \u{00B7} \($0)" } ?? "the thought"
    }

    /// The threads share one well, a divider between each (a card per row would be loud).
    private var threads: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(notes.threads.enumerated()), id: \.offset) { index, thread in
                if index > 0 {
                    Rectangle()
                        .fill(MuseColor.divider)
                        .frame(height: 1)
                        .padding(.horizontal, MuseSpacing.md)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                    Text(thread.title)
                        .font(MuseFont.lora(17, weight: .medium))
                        .foregroundStyle(MuseColor.ink)
                    if !thread.detail.isEmpty {
                        Text(thread.detail)
                            .font(MuseType.body)
                            .lineSpacing(MuseType.bodyLineSpacing)
                            .foregroundStyle(MuseColor.ink70)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MuseSpacing.md)
                .accessibilityElement(children: .combine)
            }
        }
        .museInsetSurface(cornerRadius: MuseRadius.tile)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            MuseEyebrow(title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bullets

/// The bones of a muse as bullets: a small moss dot and a Lora line each, on an inset
/// well, under a tracked eyebrow. Briefs use it whole; a long thought opens with it.
private struct NoteBullets: View {
    let bullets: [String]
    let eyebrow: String

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            MuseEyebrow(eyebrow)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    BulletLine(text: bullet)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MuseSpacing.md)
        .museInsetSurface(cornerRadius: MuseRadius.tile)
    }
}

/// One bullet. The dot sits mid-letter on the first line, at any text size.
private struct BulletLine: View {
    let text: String
    /// Half Lora's x-height at 15pt.
    @ScaledMetric(relativeTo: .subheadline) private var midLetter: CGFloat = 3.8
    @ScaledMetric(relativeTo: .subheadline) private var dot: CGFloat = 5

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
            Circle()
                .fill(MuseColor.moss300)
                .frame(width: dot, height: dot)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + midLetter }
                .accessibilityHidden(true)
            Text(text)
                .font(MuseFont.lora(15))
                .lineSpacing(MuseType.bodyLineSpacing + 1)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Moments and to-dos

/// A line worth keeping: a thin moss rule, the quote in Lora italic, the note under it.
private struct MomentRow: View {
    let moment: MuseNotes.Moment

    var body: some View {
        HStack(alignment: .top, spacing: MuseSpacing.sm) {
            Capsule()
                .fill(MuseColor.moss300)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                Text(moment.quote.museQuoted)
                    .font(MuseFont.loraItalic(17))
                    .lineSpacing(MuseType.serifLineSpacing - 1)
                    .foregroundStyle(MuseColor.ink)
                if let note = moment.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Something they said they'd do. A plain line with a small circle: nothing is scheduled.
private struct ActionLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
            Image(systemName: "circle")
                .museSymbol(12, weight: .regular)
                .foregroundStyle(MuseColor.ink55)
                .accessibilityHidden(true)
            Text(text)
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - While they're written

/// "writing it up…" (a long thought) or "skimming…" (a brief) beside a small spinner,
/// while the on-device model writes the notes.
struct MuseNotesWriting: View {
    let kind: MuseNotes.Kind

    var body: some View {
        HStack(spacing: MuseSpacing.xs) {
            ProgressView()
                .controlSize(.mini)
                .tint(MuseColor.moss600)
            Text(kind == .longThought ? "writing it up\u{2026}" : "skimming\u{2026}")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
        }
        .frame(minHeight: MuseSpacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind == .longThought ? "writing the notes" : "skimming for notes")
    }
}

// MARK: - Previews

#Preview("notes · brief") {
    ScrollView {
        MuseNotesView(notes: SampleMuses.make().first { $0.id == SampleMuses.cardID }?.notes ?? MuseNotes(kind: .brief, bullets: []))
            .padding(MuseSpacing.page)
    }
    .background { MuseBackground() }
}

#Preview("notes · long thought") {
    ScrollView {
        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
            MuseNotesWriting(kind: .longThought)
            MuseNotesView(notes: SampleMuses.make().first { $0.id == SampleMuses.marketID }?.notes ?? MuseNotes(kind: .longThought, bullets: []))
        }
        .padding(MuseSpacing.page)
    }
    .background { MuseBackground() }
}
