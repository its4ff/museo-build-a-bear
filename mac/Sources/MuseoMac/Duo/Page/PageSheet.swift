#if DEBUG
import SwiftUI

/// The Page window: one sheet of paper on the dune with a margin of thoughts. No sidebar
/// panel, no fills: the margin is type on the dune, one hairline, then the page. The three
/// quiet actions sit at the margin's top, the ring pill at its foot.
///
/// ```swift
/// PageSheet { PageThoughtMargin(open: "window") } page: { PageThoughtLeaf(thought: PocketFixtures.window) }
/// ```
struct PageSheet<Margin: View, Leaf: View>: View {
    var ring: PocketRingState
    let margin: Margin
    let leaf: Leaf

    init(
        ring: PocketRingState = PocketFixtures.ring,
        @ViewBuilder margin: () -> Margin,
        @ViewBuilder page: () -> Leaf
    ) {
        self.ring = ring
        self.margin = margin()
        self.leaf = page()
    }

    var body: some View {
        HStack(spacing: 0) {
            marginColumn
                .frame(width: PageMetrics.margin)
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(width: PageMetrics.hair)
                .accessibilityHidden(true)
            leaf
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { PocketGround() }
        .preferredColorScheme(.light)
    }

    private var marginColumn: some View {
        // The list is taller than the window: hang it from the top and let it run out.
        Color.clear.overlay(alignment: .top) { marginStack }
        .clipped()
        .mask { listFade }
        .overlay(alignment: .bottom) {
            DuoRingPill(state: ring)
                .frame(width: DuoMetrics.cornerWidth)
                .padding(.bottom, DuoMetrics.margin)
        }
    }

    private var marginStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                DuoWindowChrome()
                Spacer(minLength: 0)
                PageMarginGlyphs()
                    .padding(.trailing, PageMetrics.gutter - MuseSpacing.xs)
            }
            .frame(height: DuoMetrics.chromeHeight + MuseSpacing.xs)
            margin
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The list runs out into the paper before it reaches the ring pill.
    private var listFade: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: PageMetrics.listFade)
            Color.clear
                .frame(height: PageMetrics.pillRoom)
        }
    }
}

// MARK: - The margin's three actions

/// New note, your words, settings: today's three glyphs, kept, as quiet ink.
struct PageMarginGlyphs: View {
    var body: some View {
        HStack(spacing: 0) {
            glyph("plus", "new note")
            glyph("chart.bar", "your words")
            glyph("slider.horizontal.3", "settings")
        }
    }

    private func glyph(_ symbol: String, _ label: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .museSymbol(PageMetrics.glyph, weight: .regular)
                .foregroundStyle(MuseColor.ink55)
                .frame(width: PageMetrics.glyphBox, height: PageMetrics.glyphBox)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Small type the whole sheet shares

/// A quiet spaced label: a day in the margin, a section on a page.
struct PageEyebrow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MuseType.eyebrow)
            .tracking(MuseType.eyebrowTracking)
            .foregroundStyle(MuseColor.ink55)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A day in the margin: the word, then a hairline. The same heading Room's list wears.
struct PageDayHeading: View {
    let day: String

    init(_ day: String) { self.day = day }

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(day)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            PageHairline()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A hairline across whatever it is given.
struct PageHairline: View {
    var body: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: PageMetrics.hair)
            .accessibilityHidden(true)
    }
}

/// The reading column: one measure, centered on the page, with empty paper above it.
struct PageColumn<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .frame(maxWidth: PageMetrics.measure, alignment: .leading)
            .padding(.top, PageMetrics.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The huge Lora title.
struct PageTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MuseFont.lora(PageMetrics.title))
            .tracking(PageMetrics.titleTracking)
            .lineSpacing(PageMetrics.titleLeading)
            .foregroundStyle(MuseColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One mono line: a thought's when and how, or the keys.
struct PageMono: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MuseFont.mono(.caption))
            .foregroundStyle(MuseColor.ink55)
            .lineLimit(1)
    }
}

/// The page's last line: a hairline, what is true on the left, the keys on the right.
struct PageFoot: View {
    let left: String
    let keys: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: MuseSpacing.md)
            Text(keys)
                .font(MuseFont.mono(.caption2))
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(1)
        }
        .padding(.top, MuseSpacing.md)
        .overlay(alignment: .top) { PageHairline() }
    }
}

/// The player as one thin line on the paper: a play glyph, the recording as dots, its
/// length. No capsule: lighter than Room's.
struct PagePlayerLine: View {
    let length: String
    let seed: String

    var body: some View {
        HStack(spacing: MuseSpacing.row) {
            Button {} label: {
                Image(systemName: "play.fill")
                    .museSymbol(PageMetrics.play, weight: .medium)
                    .foregroundStyle(MuseColor.moss)
                    .frame(width: PageMetrics.play, height: PageMetrics.glyphBox)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("listen")
            DuoDottedWave(seed: seed, ink: MuseColor.moss600.opacity(PageMetrics.waveInk))
                .frame(height: PageMetrics.wave)
            PageMono(length)
        }
    }
}
#endif
