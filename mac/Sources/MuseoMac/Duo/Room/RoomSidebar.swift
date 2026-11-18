#if DEBUG
import SwiftUI

/// The sidebar as one quiet glass column: the three glyphs, search, the four filters as
/// plain words, the two other sources, the list, and the ring pill at its foot.
struct RoomSidebar<List: View>: View {
    let source: RoomSource
    @ViewBuilder var list: List

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            glyphs
            search
                .padding(.top, MuseSpacing.xs)
            filters
                .padding(.top, MuseSpacing.row)
            sources
                .padding(.top, MuseSpacing.xs)
            ScrollView {
                VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
                    list
                }
                .padding(.bottom, RoomMetrics.listFade)
            }
            .scrollIndicators(.hidden)
            .mask(alignment: .bottom) { fade }
            DuoRingPill(state: PocketFixtures.ring)
                .frame(width: DuoMetrics.cornerWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, MuseSpacing.xxs)
        }
        // The glyphs sit in the window dots' row, so the column has no top gutter.
        .padding([.horizontal, .bottom], RoomMetrics.inset)
        .duoTileGlass(cornerRadius: MuseRadius.card)
    }

    /// The list lets go just above the pill.
    private var fade: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: RoomMetrics.listFade)
        }
    }

    // MARK: - New note, your words, settings

    private var glyphs: some View {
        HStack(spacing: MuseSpacing.xxs / 2) {
            Spacer()
            glyph("plus", "new note")
            glyph("chart.bar", "your words")
            glyph("slider.horizontal.3", "settings")
        }
        .frame(height: RoomMetrics.topRow)
    }

    private func glyph(_ symbol: String, _ label: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(MuseFont.symbol(RoomMetrics.glyphSymbol, weight: .regular))
                .foregroundStyle(MuseColor.ink55)
                .frame(width: RoomMetrics.glyph, height: RoomMetrics.glyph)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: - Search

    /// A paper well in the glass, not glass on glass.
    private var search: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
        return HStack(spacing: MuseSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(MuseFont.symbol(RoomMetrics.glyphSymbol, weight: .regular))
                .foregroundStyle(MuseColor.ink55)
                .accessibilityHidden(true)
            Text("search everything you've said")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MuseSpacing.sm)
        .frame(height: RoomMetrics.field)
        .background(MuseColor.divider, in: shape)
        .overlay { shape.strokeBorder(MuseColor.divider, lineWidth: RoomMetrics.hair) }
        .padding(.horizontal, MuseSpacing.xxs)
    }

    // MARK: - Filters

    /// Plain words, the current one in ink.
    private var filters: some View {
        HStack(spacing: MuseSpacing.md) {
            ForEach(["all", "streamed", "from the ring", "saved"], id: \.self) { title in
                let on = source == .yours && title == "all"
                // Away from your thoughts, "all" is the way back: moss, with a small arrow.
                let back = source != .yours && title == "all"
                HStack(spacing: MuseSpacing.xxs) {
                    if back {
                        Image(systemName: "chevron.left")
                            .font(MuseFont.symbol(RoomMetrics.backSymbol, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(on || back ? MuseType.metaMedium : MuseType.meta)
                }
                .foregroundStyle(on ? MuseColor.ink : (back ? MuseColor.moss600 : MuseColor.ink55))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(back ? "back to all your thoughts" : title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, MuseSpacing.md)
    }

    // MARK: - Places and museo.fm

    private var sources: some View {
        VStack(spacing: 0) {
            sourceRow(.places, PocketTabID.places.duoSymbol, "places", "\(PocketFixtures.places.count)")
            sourceRow(.fm, PocketTabID.fm.duoSymbol, "museo.fm", "\(PocketFixtures.fmPlace.count)")
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(height: RoomMetrics.hair)
                .padding(.horizontal, MuseSpacing.md)
                .padding(.top, MuseSpacing.xs)
        }
        .padding(.bottom, MuseSpacing.xs)
    }

    private func sourceRow(_ value: RoomSource, _ symbol: String, _ title: String, _ count: String) -> some View {
        let on = source == value
        let shape = RoundedRectangle(cornerRadius: MuseRadius.tag, style: .continuous)
        return HStack(spacing: MuseSpacing.xs) {
            Image(systemName: symbol)
                .font(MuseFont.symbol(RoomMetrics.glyphSymbol, weight: on ? .medium : .regular))
                .foregroundStyle(on ? MuseColor.moss600 : MuseColor.ink55)
                .frame(width: RoomMetrics.sourceGlyph)
                .accessibilityHidden(true)
            Text(title)
                .font(on ? MuseType.metaMedium : MuseType.meta)
            Spacer()
            Text(count)
                .font(MuseType.caption)
                .monospacedDigit()
                .foregroundStyle(on ? MuseColor.ink70 : MuseColor.ink55)
        }
        .foregroundStyle(on ? MuseColor.ink : MuseColor.ink55)
        .padding(.horizontal, MuseSpacing.sm)
        .frame(height: RoomMetrics.source)
        // Where the sidebar is looking: a paper well like the search field's, in ink.
        .background {
            if on { shape.fill(RoomColor.well) }
        }
        .padding(.horizontal, MuseSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Rows

/// A day's heading, as on the iphone: the day, then a hairline.
struct RoomDayHeading: View {
    let day: String

    init(_ day: String) {
        self.day = day
    }

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(day)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(height: RoomMetrics.hair)
        }
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.top, MuseSpacing.sm)
        .padding(.bottom, MuseSpacing.xxs)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One quiet line over a list ("6 · 3 sending").
struct RoomListNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(MuseType.caption)
            .monospacedDigit()
            .foregroundStyle(MuseColor.ink55)
            .padding(.horizontal, MuseSpacing.sm)
            .padding(.top, MuseSpacing.xs)
            .padding(.bottom, MuseSpacing.xxs)
    }
}

/// Air between two groups of places.
struct RoomGap: View {
    var body: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: RoomMetrics.hair)
            .padding(.horizontal, MuseSpacing.sm)
            .padding(.vertical, MuseSpacing.xs)
            .accessibilityHidden(true)
    }
}

/// A thought in the list, the mac's way: the small line of when and how first, then the
/// words in Lora, two lines. The open one sits on the moss gradient in white.
struct RoomRow: View {
    let meta: String
    let title: String
    var selected = false
    var ink: PocketInk = .full
    /// A ring recording nobody has opened yet carries the ring's amber dot.
    var isUnseen = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            HStack(spacing: MuseSpacing.xs - MuseSpacing.xxs / 2) {
                if isUnseen {
                    Circle()
                        .fill(MuseColor.ringAmber)
                        .frame(width: RoomMetrics.dot, height: RoomMetrics.dot)
                        .accessibilityLabel("new from the ring")
                }
                Text(meta)
                    .font(MuseType.caption)
                    .monospacedDigit()
                    .foregroundStyle(selected ? DuoColor.onMossQuiet : ink.foot)
                    .lineLimit(1)
            }
            Text(title)
                .font(MuseFont.lora(RoomMetrics.rowTitle))
                .foregroundStyle(selected ? DuoColor.onMoss : ink.title)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.xs)
        .background {
            if selected { shape.fill(MuseColor.primaryGradient) }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A place in the list: its name in Lora, its sentence in the sans, how many it holds.
struct RoomPlaceRow: View {
    let place: PocketPlace
    var selected = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
        HStack(spacing: MuseSpacing.xs) {
            VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
                Text(place.name)
                    .font(MuseFont.lora(RoomMetrics.placeName))
                    .foregroundStyle(selected ? DuoColor.onMoss : MuseColor.ink)
                Text(place.sentence)
                    .font(MuseType.caption)
                    .foregroundStyle(selected ? DuoColor.onMossQuiet : MuseColor.ink55)
                    .lineLimit(1)
            }
            Spacer(minLength: MuseSpacing.xs)
            if place.sends {
                Image(systemName: "arrow.up.right")
                    .font(MuseFont.symbol(MuseSpacing.sm - MuseSpacing.xxs / 2))
                    .foregroundStyle(selected ? DuoColor.onMossQuiet : MuseColor.moss600)
                    .accessibilityLabel("sending")
            }
            Text("\(place.count)")
                .font(MuseType.meta)
                .monospacedDigit()
                .foregroundStyle(selected ? DuoColor.onMossQuiet : MuseColor.ink55)
        }
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.xs)
        .background {
            if selected { shape.fill(MuseColor.primaryGradient) }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
