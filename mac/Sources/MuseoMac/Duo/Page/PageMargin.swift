#if DEBUG
import SwiftUI

// MARK: - A row of type in the margin

/// One row in the margin: a small line, then words in Lora, then a small line. No chrome.
/// The row you are on wears the moss gradient, or full ink and a short moss rule.
struct PageMarginRow: View {
    var top: String?
    let words: String
    var foot: String?
    var trailing: String?
    var wordSize: CGFloat = PageMetrics.rowWords
    var lines = 2
    var dot = false
    var selected = false
    var ink: PocketInk = .full
    var mark: PageMark = .moss

    private var onMoss: Bool { selected && mark == .moss }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            if let top {
                HStack(spacing: MuseSpacing.xs - MuseSpacing.xxs / 2) {
                    if dot {
                        Circle()
                            .fill(MuseColor.ringAmber)
                            .frame(width: PageMetrics.dot, height: PageMetrics.dot)
                            .accessibilityHidden(true)
                    }
                    small(top)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                Text(words)
                    .font(MuseFont.lora(wordSize))
                    .lineSpacing(PageMetrics.rowLeading)
                    .foregroundStyle(onMoss ? DuoColor.onMoss : (selected ? MuseColor.ink : ink.title))
                    .lineLimit(lines)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing {
                    small(trailing).monospacedDigit()
                }
            }
            if let foot {
                small(foot)
            }
        }
        .padding(.horizontal, PageMetrics.gutter - PageMetrics.rowInset)
        .padding(.vertical, MuseSpacing.sm - MuseSpacing.xxs / 2)
        .background {
            if onMoss {
                RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
                    .fill(MuseColor.primaryGradient)
            }
        }
        .overlay(alignment: .leading) {
            if selected, mark == .rule {
                Capsule()
                    .fill(MuseColor.moss600)
                    .frame(width: PageMetrics.rule)
                    .padding(.vertical, MuseSpacing.row)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, PageMetrics.rowInset)
        // The margin is taller than its list can be: keep every row its own height.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func small(_ text: String) -> some View {
        Text(text)
            .font(MuseType.caption)
            .foregroundStyle(onMoss ? DuoColor.onMossQuiet : MuseColor.ink55)
            .lineLimit(1)
    }
}

// MARK: - The margin's head

/// The search line: no box, a hairline under it.
struct PageSearchLine: View {
    var body: some View {
        VStack(spacing: MuseSpacing.xs + 1) {
            HStack(spacing: MuseSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .museSymbol(PageMetrics.play, weight: .regular)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
                Text("search everything you've said")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: 0)
            }
            PageHairline()
        }
        .padding(.horizontal, PageMetrics.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("search everything you've said")
        .accessibilityAddTraits(.isSearchField)
    }
}

/// The four filters as four plain words, the current one in full ink.
struct PageFilterWords: View {
    var current = "all"

    private let words = ["all", "streamed", "from the ring", "saved"]

    var body: some View {
        HStack(spacing: MuseSpacing.md) {
            ForEach(words, id: \.self) { word in
                Button {} label: {
                    Text(word)
                        .font(word == current ? MuseType.metaMedium : MuseType.meta)
                        .foregroundStyle(word == current ? MuseColor.ink : MuseColor.ink55)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(word == current ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PageMetrics.gutter)
    }
}

/// Where you are when the margin holds something other than your thoughts: "yours › places"
/// and its quiet count. Esc walks back.
struct PageWhereLine: View {
    let place: String
    let count: String

    var body: some View {
        HStack(spacing: MuseSpacing.xs - 2) {
            Text("yours")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
            Image(systemName: "chevron.right")
                .museSymbol(MuseSpacing.xs, weight: .medium)
                .foregroundStyle(MuseColor.ink55)
                .accessibilityHidden(true)
            Text(place)
                .font(MuseType.metaMedium)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: MuseSpacing.xs)
            Text(count)
                .font(MuseType.caption)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
        }
        .lineLimit(1)
        .padding(.horizontal, PageMetrics.gutter)
    }
}

// MARK: - Three margins

/// Your thoughts, by day, receding in ink with age.
struct PageThoughtMargin: View {
    let open: String
    var mark: PageMark = .moss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageSearchLine()
                .padding(.top, MuseSpacing.sm)
            PageFilterWords()
                .padding(.top, MuseSpacing.row)
            ForEach(PocketFixtures.days, id: \.day) { day in
                PageDayHeading(day.day)
                    .padding(.horizontal, PageMetrics.gutter)
                    .padding(.top, MuseSpacing.lg)
                    .padding(.bottom, MuseSpacing.xxs)
                ForEach(day.thoughts) { thought in
                    PageMarginRow(
                        top: RoomFixtures.meta(thought),
                        words: thought.body,
                        dot: RoomFixtures.unseen.contains(thought.id),
                        selected: thought.id == open,
                        ink: thought.ink,
                        mark: mark
                    )
                }
            }
        }
    }
}

/// Your places: the name in Lora, its sentence in the sans.
struct PagePlacesMargin: View {
    let open: String
    var mark: PageMark = .moss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageSearchLine()
                .padding(.top, MuseSpacing.sm)
            PageWhereLine(place: "places", count: PocketFixtures.placesCount)
                .padding(.top, MuseSpacing.row)
                .padding(.bottom, MuseSpacing.lg)
            ForEach(PocketFixtures.places) { place in
                PageMarginRow(
                    words: place.name,
                    foot: place.sentence,
                    trailing: "\(place.count)",
                    wordSize: PageMetrics.placeName,
                    lines: 1,
                    selected: place.id == open,
                    mark: mark
                )
            }
        }
    }
}

/// Other people's thoughts on museo.fm: words, then a city and an hour.
struct PageFMMargin: View {
    let open: String
    var mark: PageMark = .moss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageSearchLine()
                .padding(.top, MuseSpacing.sm)
            PageWhereLine(place: "museo.fm", count: PocketFixtures.fmYoursLine)
                .padding(.top, MuseSpacing.row)
                .padding(.bottom, MuseSpacing.lg)
            ForEach(Array(PocketFixtures.fmThoughts.enumerated()), id: \.element.id) { index, thought in
                PageMarginRow(
                    top: thought.isYours ? "yours · \(thought.foot)" : thought.foot,
                    words: thought.words,
                    lines: 2,
                    selected: thought.id == open,
                    ink: index < 2 ? .full : (index < 4 ? .receding : .far),
                    mark: mark
                )
            }
        }
    }
}
#endif
