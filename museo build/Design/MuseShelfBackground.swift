import SwiftUI
import UIKit

// The library's ground: the khaki shelf, a fine
// dot tile, and the page grain. The home's grid of muses sits on it, so the tiles read as
// things on a shelf rather than text on a page. It is the page wash for that screen: grain
// stays on it alone, never under running text on a card.

// MARK: - Background

/// Full-page dotted linen behind the library: `ZStack { MuseShelfBackground(); ScrollView { … } }`.
/// Pair it with `.museBottomBlur(wash: MuseColor.shelf)` on the scroll.
struct MuseShelfBackground: View {
    var body: some View {
        MuseColor.shelf
            .overlay { MuseShelfDots() }
            .overlay { MuseGrainOverlay(opacity: MuseGrain.pageOpacity) }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Dots

/// The shelf's dot grid on its own: one small ink dot every 14pt, tiled.
struct MuseShelfDots: View {
    var body: some View {
        MuseShelfDotTile.tile
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// One 14pt square with a 1.2pt ink dot at 11% in its middle, drawn once.
nonisolated enum MuseShelfDotTile {
    /// The distance between dots.
    static let spacing: CGFloat = 14
    /// The dot's diameter.
    static let dot: CGFloat = 1.2
    /// How much ink the dot carries.
    static let opacity: CGFloat = 0.11

    /// The tile, made on first use (a `static let` initializes once, thread safe).
    static let tile: Image = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: spacing, height: spacing), format: format)
        let image = renderer.image { context in
            UIColor(MuseColor.ink).withAlphaComponent(opacity).setFill()
            let origin = (spacing - dot) / 2
            context.cgContext.fillEllipse(in: CGRect(x: origin, y: origin, width: dot, height: dot))
        }
        return Image(uiImage: image)
    }()
}

#Preview("shelf") {
    VStack(spacing: MuseSpacing.sm) {
        Text("rings floating in the window")
            .font(MuseType.headline)
            .foregroundStyle(MuseColor.ink)
            .padding(MuseSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .museTileSurface()
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseShelfBackground() }
}
