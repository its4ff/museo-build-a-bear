#if DEBUG
import SwiftUI

// MARK: - Measures

/// The shelf's own measures: a pointer sized grid, a step under the iphone's.
nonisolated enum ShelfMetrics {
    /// From the window's sides to the shelf.
    static let gutter: CGFloat = 56
    /// Tiles across.
    static let columns = 5
    /// A thought's tile, and its title.
    static let tileHeight: CGFloat = 116
    static let tileTitle: CGFloat = 17
    /// Someone else's thought on museo.fm: more words, a little smaller.
    static let fmTileHeight: CGFloat = 140
    static let fmTileWords: CGFloat = 15
    /// The thought given room on museo.fm.
    static let fmWords: CGFloat = 30
    static let fmWordsWidth: CGFloat = 660
    static let fmWave: CGFloat = 300
    /// A place's tile, and its name.
    static let placeHeight: CGFloat = 184
    static let placeName: CGFloat = 28
    static let placeSentence: CGFloat = 15
    static let placeColumns = 3
    /// The dash of the one suggestion.
    static let dash: [CGFloat] = [5, 5]
    /// The thought brought forward.
    static let panelWidth: CGFloat = 528
    static let panelInset: CGFloat = 40
    /// The quiet close glyph in the panel's corner, and its hit box.
    static let close: CGFloat = 11
    static let closeBox: CGFloat = 28
    /// How far the shelf steps back behind it.
    static let backBlur: CGFloat = 5
    static let backDim: Double = 0.5
    /// The rule beside what came back.
    static let rule: CGFloat = 2
    /// The keys line sits on the cluster's center line.
    static let keysFoot: CGFloat = DuoMetrics.margin + MuseSpacing.sm
    /// The shelf's own foot fade: the dune is whole from just above the corner down, and
    /// clear a short step higher, so a row is either all there or not there at all.
    static let fadeSolid: CGFloat = DuoMetrics.cornerHeight + DuoMetrics.margin + MuseSpacing.xxs
    static let fadeEnd: CGFloat = fadeSolid + MuseSpacing.lg
    /// What a shelf page leaves under its last row: the fade and a breath.
    static let footRoom: CGFloat = fadeEnd + MuseSpacing.xxs
    /// A small glyph inside a line of type.
    static let glyph: CGFloat = 10
}

// MARK: - The window with its keys line

/// `DuoWindow` plus the one thing the mac adds: a quiet line of keys at the very foot.
struct ShelfWindow<Content: View>: View {
    let current: PocketTabID
    let keys: [String]
    let content: Content

    init(current: PocketTabID, keys: [String], @ViewBuilder content: () -> Content) {
        self.current = current
        self.keys = keys
        self.content = content()
    }

    var body: some View {
        DuoWindow(current: current, fade: .none) {
            content.overlay { ShelfFootFade() }
        }
            .overlay(alignment: .bottom) {
                Text(keys.joined(separator: "  ·  "))
                    .font(MuseFont.mono(.caption))
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
                    .padding(.bottom, ShelfMetrics.keysFoot)
                    .accessibilityLabel("keys: " + keys.joined(separator: ", "))
            }
    }
}

/// The dune drawn again over the shelf's foot. Tighter than the kit's band: the grid
/// stops whole above it, and the next row waits wholly behind it.
struct ShelfFootFade: View {
    var body: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1)
            PocketGround()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 1 - ShelfMetrics.fadeEnd / height),
                            .init(color: .black, location: 1 - ShelfMetrics.fadeSolid / height),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - A day

/// One word and a hairline: "today", "yesterday", "sunday".
struct ShelfDayRule: View {
    let day: String
    var ink: PocketInk = .full

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(day)
                .font(MuseType.meta)
                .foregroundStyle(ink.foot)
            Rectangle()
                .fill(MuseColor.hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - A tile

/// The kit's glass tile at the shelf's size, with the mac's one extra state: under the
/// keys or the pointer it turns to the moss gradient with white words.
struct ShelfTile: View {
    let title: String
    var foot: String?
    var voice = false
    var ink: PocketInk = .full
    var selected = false
    var titleSize: CGFloat = ShelfMetrics.tileTitle
    var lines = 3
    var height: CGFloat = ShelfMetrics.tileHeight

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.tile, style: .continuous)
        let label = VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(MuseFont.lora(titleSize))
                .foregroundStyle(selected ? DuoColor.onMoss : ink.title)
                .lineLimit(lines)
                .multilineTextAlignment(.leading)
            Spacer(minLength: MuseSpacing.xxs)
            if let foot {
                HStack(spacing: MuseSpacing.xs) {
                    Circle()
                        .fill(selected ? DuoColor.onMossQuiet : MuseColor.moss600)
                        .frame(width: DuoMetrics.footDot, height: DuoMetrics.footDot)
                        .accessibilityHidden(true)
                    Text(foot)
                        .font(MuseType.meta)
                        .foregroundStyle(selected ? DuoColor.onMossQuiet : ink.foot)
                        .lineLimit(1)
                    if voice {
                        Spacer(minLength: 0)
                        Image(systemName: "waveform")
                            .museSymbol(ShelfMetrics.glyph, weight: .regular)
                            .foregroundStyle(MuseColor.ink55)
                            .accessibilityLabel("has a voice")
                    }
                }
            }
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)

        Group {
            if selected {
                label
                    .background(MuseColor.primaryGradient, in: shape)
                    .museElevation(.e1)
            } else {
                label.duoTileGlass()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The shelf's columns.
nonisolated enum ShelfGrid {
    static func columns(_ count: Int = ShelfMetrics.columns) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: MuseSpacing.sm), count: count)
    }
}
#endif
