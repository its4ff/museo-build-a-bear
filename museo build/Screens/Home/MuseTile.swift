import SwiftUI

/// One muse on the library shelf: a 2-up paper tile. The title carries the muse; the words
/// wait on its page.
///
/// ```
/// ┌──────────────────────────┐
/// │ 52m ago             0:41 │   when (relative today, "oct 7 · 9:40p" before), how long
/// │ rings floating in the    │   the title in Lora 16, up to three lines
/// │ window                   │
/// │                          │
/// │ streamed · notes     91% │   where it came from, its notes, how sure the words are
/// └──────────────────────────┘
/// ```
///
/// The title slot holds the state while there's no title yet: "transcribing…", a quiet
/// failed line (the page has retry), "blank muse". A fresh muse types its title in
/// (`ArrivalTracker` decides); a title that lands later cross-fades. The library wraps the
/// tile in its button and its menu.
struct MuseTile: View {
    let muse: Muse
    /// Whether the title types in, waits to, or just shows (`ArrivalTracker` decides).
    var ink: ArrivalTracker.Mode = .plain
    /// Its notes are being written right now (`MusePipeline.noting`).
    var isNoting = false
    /// A failed muse says so in clay, unless something else on screen already wears the
    /// page's one clay mark.
    var failsInClay = true
    /// The title finished typing (or the tile left the screen mid-typing).
    var onTyped: () -> Void = {}

    @Environment(\.museLibraryNow) private var pinnedNow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// About 178pt, growing with Dynamic Type so three lines of title still fit.
    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 178

    /// Lora 16: the tile's title.
    static let titleFont = MuseFont.lora(16)
    /// Lora italic 16: the title slot while there's no title to show.
    static let waitingFont = MuseFont.loraItalic(16)
    static let titleLines = 3
    /// Letters typed one by one; three lines of a tile hold fewer than this.
    static let typedLetters = 72
    /// How long a muse from the ring's memory wears its ochre "new" dot.
    static let newWindow: TimeInterval = 600

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            slot
                .padding(.top, MuseSpacing.xs)
            Spacer(minLength: MuseSpacing.xs)
            HStack(alignment: .lastTextBaseline, spacing: MuseSpacing.xs) {
                foot
                Spacer(minLength: 0)
                if let confidence {
                    MuseConfidenceTag(confidence, style: .compact)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.row)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .museTileSurface()
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: slotText)
        .animation(MuseMotion.adaptive(MuseMotion.dissolve, reduceMotion: reduceMotion), value: footLine)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("opens this muse")
        .accessibilityInputLabels(inputLabels)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: MuseSpacing.xxs) {
            when
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: MuseSpacing.xxs)
            newMark
            if let length {
                Text(verbatim: length)
                    .foregroundStyle(MuseColor.ink55)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .font(MuseType.caption)
    }

    /// Today, relative and kept fresh by the minute ("now", "52m ago"). Before today, the day
    /// a shade darker than the clock ("oct 7 · 9:40p").
    @ViewBuilder
    private var when: some View {
        if Calendar.current.isDate(muse.createdAt, inSameDayAs: pinnedNow ?? .now) {
            TimelineView(.everyMinute) { context in
                Text(verbatim: muse.createdAt.museRelative(now: pinnedNow ?? context.date))
                    .foregroundStyle(MuseColor.ink55)
            }
        } else {
            Text("\(Text(verbatim: day).foregroundStyle(MuseColor.ink70)) · \(Text(verbatim: muse.createdAt.museClock).foregroundStyle(MuseColor.ink55))")
        }
    }

    private var day: String {
        muse.createdAt.museShortDate(now: pinnedNow ?? .now)
    }

    /// "0:41". Typed muses have no length.
    private var length: String? {
        guard muse.origin != .typed, muse.duration >= 0.5 else { return nil }
        return muse.duration.museDuration
    }

    /// A muse that came in from the ring's memory in the last ten minutes. It may land below
    /// newer ones (it's placed by when you said it), so it carries a small ochre dot.
    private var isNewFromRing: Bool {
        muse.origin == .offline && muse.isFresh(within: Self.newWindow)
    }

    /// The ochre dot, redrawn once more when its ten minutes are up so it never lingers on a
    /// library that sits still.
    @ViewBuilder
    private var newMark: some View {
        if isNewFromRing {
            TimelineView(.explicit([muse.arrivedAt.addingTimeInterval(Self.newWindow)])) { _ in
                if isNewFromRing {
                    Circle()
                        .fill(MuseColor.ochre)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, MuseSpacing.xxs)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Title slot

    private enum Slot: Equatable {
        case waiting
        case failed
        case blank
        case title(String)
    }

    private var slotState: Slot {
        switch muse.transcriptionState {
        case .pending, .transcribing: .waiting
        case .failed: .failed
        case .complete:
            muse.isBlank || muse.words.isEmpty ? .blank : .title(Self.tileTitle(for: muse))
        }
    }

    private var slotText: String {
        switch slotState {
        case .waiting: "transcribing…"
        case .failed: "didn't come through"
        case .blank: "blank muse"
        case .title(let title): title
        }
    }

    @ViewBuilder
    private var slot: some View {
        switch slotState {
        case .waiting, .blank:
            placeholder(color: MuseColor.ink70)
        case .failed:
            placeholder(color: failsInClay ? MuseColor.clay : MuseColor.ink70)
        case .title(let title):
            if ink != .plain {
                MuseInkText(
                    title,
                    font: Self.titleFont,
                    color: MuseColor.ink,
                    startsTyping: ink == .types,
                    haptics: true,
                    typingLimit: Self.typedLetters,
                    onFinish: onTyped
                )
                .lineLimit(Self.titleLines)
                .onDisappear(perform: onTyped)
                .transition(.opacity)
            } else {
                Text(title)
                    .font(Self.titleFont)
                    .foregroundStyle(MuseColor.ink)
                    .lineLimit(Self.titleLines)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .transition(.opacity)
            }
        }
    }

    private func placeholder(color: Color) -> some View {
        Text(slotText)
            .font(Self.waitingFont)
            .foregroundStyle(color)
            .lineLimit(Self.titleLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    /// The title, or the start of their words while the model hasn't named it.
    static func tileTitle(for muse: Muse) -> String {
        if let title = muse.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return muse.words
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? muse.displayTitle
    }

    // MARK: Foot

    @ViewBuilder
    private var foot: some View {
        if !footLine.isEmpty {
            Text(footLine)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .contentTransition(.opacity)
        }
    }

    /// "streamed", "memory · long thought", "iphone · writing notes…". While words are held up,
    /// the reason instead ("the speech model is still downloading").
    private var footLine: String {
        if muse.transcriptionState == .pending || muse.transcriptionState == .transcribing,
           let reason = muse.transcriptionError?.museQuiet, !reason.isEmpty {
            return reason
        }
        let kind = Self.kindWord(muse.origin)
        if isNoting { return "\(kind) · writing notes…" }
        switch muse.notes?.kind {
        case .longThought: return "\(kind) · long thought"
        case .brief: return "\(kind) · notes"
        case nil: return kind
        }
    }

    /// Apple speech's confidence once the words are in. Blank muses, typed ones and Voz's
    /// have none.
    private var confidence: Double? {
        guard muse.transcriptionState == .complete, !muse.isBlank else { return nil }
        return muse.wordConfidence
    }

    /// Where it came from, in one word.
    static func kindWord(_ origin: MuseOrigin) -> String {
        switch origin {
        case .stream: "streamed"
        case .offline: "memory"
        case .typed: "typed"
        case .sample: "sample"
        }
    }

    // MARK: Accessibility

    /// "rings floating in the window, streamed · notes, 52m ago, 0:41".
    private var spokenLabel: String {
        let now = pinnedNow ?? .now
        let when = Calendar.current.isDate(muse.createdAt, inSameDayAs: now)
            ? muse.createdAt.museRelative(now: now)
            : "\(day), \(muse.createdAt.museClock)"
        var parts = [slotText, footLine, when]
        if let length { parts.append(length) }
        if let confidence {
            parts.append("transcription confidence \(MuseConfidenceTag(confidence).percent)")
        }
        if isNewFromRing { parts.append("new") }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// What Voice Control can say to open it: its title, or its time.
    private var inputLabels: [Text] {
        var labels = [Text(verbatim: muse.createdAt.museClock)]
        if case .title(let title) = slotState { labels.insert(Text(verbatim: title), at: 0) }
        return labels
    }
}

// MARK: - Previews

#Preview("tiles") {
    let now = Date.now
    let titled = Muse(
        createdAt: now.addingTimeInterval(-3_100), duration: 41, origin: .stream,
        transcript: "okay, the shop window. hang the rings on thread so they look like they're floating.",
        transcriptionState: .complete, title: "rings floating in the window",
        notes: MuseNotes(kind: .brief, bullets: ["hang the rings on thread"])
    )
    let untitled = Muse(
        createdAt: now.addingTimeInterval(-90_000), duration: 14, origin: .offline,
        transcript: "remind me to call mum back about sunday lunch, and ask about the lemon tart.",
        transcriptionState: .complete
    )
    let waiting = Muse(createdAt: now.addingTimeInterval(-60), duration: 7, origin: .stream, arrivedAt: now)
    let failed = Muse(
        createdAt: now.addingTimeInterval(-300_000), duration: 9, origin: .offline,
        transcriptionState: .failed, transcriptionError: "this recording can't be read."
    )
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: MuseSpacing.sm), GridItem(.flexible())], spacing: MuseSpacing.lg) {
            MuseTile(muse: titled)
            MuseTile(muse: untitled, isNoting: true)
            MuseTile(muse: waiting)
            MuseTile(muse: failed)
        }
        .padding(MuseSpacing.page)
    }
    .background { MuseShelfBackground() }
}
