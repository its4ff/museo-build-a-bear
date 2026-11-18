#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import SwiftUI

/// How much ink a tile gets. Ink carries recency: today in full, older a step back.
nonisolated enum PocketInk: Hashable, Sendable {
    case full, receding, far

    /// The title's color.
    var title: Color {
        switch self {
        case .full: MuseColor.ink
        case .receding: MuseColor.ink70
        case .far: MuseColor.ink55
        }
    }

    /// The foot line's color.
    var foot: Color {
        switch self {
        case .full: MuseColor.ink70
        case .receding, .far: MuseColor.ink55
        }
    }
}

/// The two column grid every pocket page uses.
nonisolated enum PocketGrid {
    /// The page gutter.
    static let gutter: CGFloat = MuseSpacing.page
    /// Between columns, and between rows.
    static let spacing: CGFloat = MuseSpacing.sm
    /// A tile's height at the default text size: three title lines and the foot, and low
    /// enough that the library's third row ends just above the ring pill in both shells.
    static let tileHeight: CGFloat = 150
    /// Inside a tile.
    static let tilePaddingH: CGFloat = MuseSpacing.md
    static let tilePaddingV: CGFloat = MuseSpacing.row
    /// The foot's dot.
    static let footDot: CGFloat = 6
    /// Lines a title may take.
    static let titleLines = 4

    /// Two columns; pass `accessibility: true` (from `dynamicTypeSize.isAccessibilitySize`)
    /// for one.
    static func columns(accessibility: Bool = false) -> [GridItem] {
        let column = GridItem(.flexible(), spacing: spacing, alignment: .top)
        return accessibility ? [column] : [column, column]
    }
}

/// The one shared tile: tall, rounded, glass so the dune shows through. The title in Lora
/// and, at the foot, at most one quiet line with an optional small dot.
///
/// ```swift
/// LazyVGrid(columns: PocketGrid.columns(), spacing: PocketGrid.spacing) {
///     PocketTile(title: thought.title, foot: thought.foot, footDot: MuseColor.moss600, ink: thought.ink)
/// }
/// ```
struct PocketTile: View {
    let title: String
    var foot: String?
    /// The dot before the foot line; nil for none.
    var footDot: Color?
    var ink: PocketInk = .full

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = PocketGrid.tileHeight

    init(title: String, foot: String? = nil, footDot: Color? = nil, ink: PocketInk = .full) {
        self.title = title
        self.foot = foot
        self.footDot = footDot
        self.ink = ink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(MuseType.headline)
                .foregroundStyle(ink.title)
                .lineLimit(PocketGrid.titleLines)
                .multilineTextAlignment(.leading)
            Spacer(minLength: MuseSpacing.xs)
            if let foot {
                HStack(spacing: MuseSpacing.xs) {
                    if let footDot {
                        Circle()
                            .fill(footDot)
                            .frame(width: PocketGrid.footDot, height: PocketGrid.footDot)
                            .accessibilityHidden(true)
                    }
                    Text(foot)
                        .font(MuseType.meta)
                        .foregroundStyle(ink.foot)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, PocketGrid.tilePaddingH)
        .padding(.vertical, PocketGrid.tilePaddingV)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .pocketTileGlass()
        .accessibilityElement(children: .combine)
    }
}
#endif
