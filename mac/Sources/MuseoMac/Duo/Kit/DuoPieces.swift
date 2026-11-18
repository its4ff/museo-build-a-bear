#if DEBUG
import Foundation
import SwiftUI

// MARK: - A thought in a list

/// A thought as a mac list row: the title in Lora, one quiet line under it. Selected, it
/// sits on the moss gradient in white. Ink carries recency. Wrap it in a `Button` with
/// `.buttonStyle(.plain)` to make it pressable.
///
/// ```swift
/// DuoThoughtRow(title: thought.title, foot: thought.foot, selected: thought == open, ink: thought.ink)
/// ```
struct DuoThoughtRow: View {
    let title: String
    var foot: String?
    var selected: Bool
    var ink: PocketInk

    @State private var isHovered = false

    init(title: String, foot: String? = nil, selected: Bool = false, ink: PocketInk = .full) {
        self.title = title
        self.foot = foot
        self.selected = selected
        self.ink = ink
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            Text(title)
                .font(MuseFont.lora(DuoMetrics.rowTitle))
                .foregroundStyle(selected ? DuoColor.onMoss : ink.title)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let foot {
                Text(foot)
                    .font(MuseType.caption)
                    .foregroundStyle(selected ? DuoColor.onMossQuiet : ink.foot)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.sm - MuseSpacing.xxs / 2)
        .background {
            if selected {
                shape.fill(MuseColor.primaryGradient)
            } else if isHovered {
                shape.fill(DuoColor.hover)
            }
        }
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - A tile

/// The iphone's tile at the mac's size, on the warm mac glass: the title in Lora and at
/// most one quiet foot line with an optional small dot.
struct DuoTile: View {
    let title: String
    var foot: String?
    var footDot: Color?
    var ink: PocketInk
    var height: CGFloat

    init(
        title: String,
        foot: String? = nil,
        footDot: Color? = nil,
        ink: PocketInk = .full,
        height: CGFloat = DuoMetrics.tileHeight
    ) {
        self.title = title
        self.foot = foot
        self.footDot = footDot
        self.ink = ink
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(MuseFont.lora(DuoMetrics.tileTitle))
                .foregroundStyle(ink.title)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: MuseSpacing.xs)
            if let foot {
                HStack(spacing: MuseSpacing.xs) {
                    if let footDot {
                        Circle()
                            .fill(footDot)
                            .frame(width: DuoMetrics.footDot, height: DuoMetrics.footDot)
                            .accessibilityHidden(true)
                    }
                    Text(foot)
                        .font(MuseType.meta)
                        .foregroundStyle(ink.foot)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.row)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .duoTileGlass()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - A page's title

/// A page's title, centered in Lora, with one quiet count line under it: "your thoughts"
/// over "212 · 3 today". No period, as on the iphone.
struct DuoPageTitle: View {
    let title: String
    var count: String?

    init(_ title: String, count: String? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        VStack(spacing: MuseSpacing.xxs) {
            Text(title)
                .font(MuseType.title)
                .tracking(MuseType.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text(count)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Listen

/// The player as one glass capsule: the play glyph, the recording as dots, its length.
/// It takes the width it is given; frame it (280 to 420 reads well).
struct DuoListenCapsule: View {
    let length: String
    var seed: String
    var isPlaying: Bool
    var action: () -> Void

    init(length: String, seed: String = "museo", isPlaying: Bool = false, action: @escaping () -> Void = {}) {
        self.length = length
        self.seed = seed
        self.isPlaying = isPlaying
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MuseSpacing.sm) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .museSymbol(DuoMetrics.play, weight: .medium)
                    .foregroundStyle(MuseColor.moss)
                    .frame(width: MuseSpacing.lg)
                DuoDottedWave(seed: seed)
                    .frame(height: DuoMetrics.wave)
                Text(length)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
            }
            .padding(.horizontal, MuseSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: DuoMetrics.bar)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .duoControlGlass()
        .accessibilityLabel(isPlaying ? "pause" : "listen")
        .accessibilityValue(length)
    }
}

/// The recording as columns of dots, taller where the voice was. Made up from `seed`, so
/// each thought keeps its own shape.
struct DuoDottedWave: View {
    let seed: String
    var ink: Color = MuseColor.moss600

    var body: some View {
        let ink = ink
        let phase = Double(seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 97)
        Canvas { context, size in
            let dot = DuoMetrics.waveDot
            let pitch = dot + DuoMetrics.waveGap
            let columns = max(Int((size.width + DuoMetrics.waveGap) / pitch), 1)
            let rows = max(Int((size.height + DuoMetrics.waveGap) / pitch), 1)
            let inset = (size.width - (CGFloat(columns) * pitch - DuoMetrics.waveGap)) / 2
            for column in 0..<columns {
                let t = Double(column) + phase
                let swell = abs(sin(t * 0.23)) * abs(cos(t * 0.071 + 1.3))
                let jitter = abs(sin(t * 1.7))
                let level = 0.12 + 0.88 * (0.65 * swell + 0.35 * jitter)
                let lit = max(1, min(rows, Int((level * Double(rows)).rounded())))
                let top = (size.height - (CGFloat(lit) * pitch - DuoMetrics.waveGap)) / 2
                for row in 0..<lit {
                    let rect = CGRect(
                        x: inset + CGFloat(column) * pitch,
                        y: top + CGFloat(row) * pitch,
                        width: dot,
                        height: dot
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(ink))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
#endif
