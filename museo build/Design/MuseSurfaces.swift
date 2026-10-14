import SwiftUI
import UIKit

// The page and everything that sits on it. One table (`MuseStock`) decides fill, hairline
// and lift for every surface, so a card here is a card everywhere.
//
// Rules: grain only on the page wash (and inside the orb). Never two different radii
// touching. Rows that are just a list get hairlines, not a card each.

// MARK: - Grain

/// Paper tooth: a seamless, procedural grain tile (no image asset). Drawn once, 384px at
/// 3x (128pt), seeded "MUSE" (0x4D555345) so it is identical on every launch.
nonisolated enum MuseGrain {
    /// The page wash.
    static let pageOpacity = 0.56

    /// The tile, made on first use (thread safe: a `static let` initializes once).
    static let tile: Image = makeTile()

    /// Draws the tile off the main thread so the first frame doesn't pay for it (about
    /// 0.1s in a Debug build, a few ms in Release). Optional: call it from `App.init`.
    static func warm() {
        Task.detached(priority: .userInitiated) { _ = MuseGrain.tile }
    }

    private static let seed: UInt32 = 0x4D555345

    private static func makeTile() -> Image {
        let size = 384
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let n = tooth(x: x, y: y)
                let g = UInt8(clamping: Int(((n - 0.5) * 1.35 + 0.5) * 255))
                let i = (y * size + x) * 4
                pixels[i] = g
                pixels[i + 1] = g
                pixels[i + 2] = g
            }
        }
        let image: UIImage? = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cgImage = context.makeImage() else { return nil }
            return UIImage(cgImage: cgImage, scale: 3, orientation: .up)
        }
        return Image(uiImage: image ?? UIImage())
    }

    /// 40% white-noise grain plus 60% of three octaves (8, 16, 32; amplitude x0.56) sampled
    /// on whole lattice points: a fine tooth that tiles
    /// seamlessly because every pixel is independent.
    private static func tooth(x: Int, y: Int) -> Float {
        let grain = hash(x, y, seed)
        var fiber: Float = 0
        var amplitude: Float = 1
        var norm: Float = 0
        var frequency = 8
        for octave in 0..<3 {
            fiber += amplitude * hash(x * frequency, y * frequency, seed &+ UInt32(octave) &* 2_654_435_761)
            norm += amplitude
            amplitude *= 0.56
            frequency *= 2
        }
        return grain * 0.40 + (fiber / norm) * 0.60
    }

    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
        var n = UInt32(truncatingIfNeeded: x) &* 1_597_334_677
        n &+= UInt32(truncatingIfNeeded: y) &* 3_812_015_801
        n &+= seed &* 1_979_128_329
        n ^= n >> 16
        n &*= 2_246_822_519
        n ^= n >> 13
        return Float(n) / Float(UInt32.max)
    }
}

/// The grain as a layer. Hidden under Reduce Transparency. Put it on the page wash, never
/// under running text on a card.
struct MuseGrainOverlay: View {
    var opacity: Double = MuseGrain.pageOpacity
    var blend: BlendMode = .overlay

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if !reduceTransparency {
            MuseGrain.tile
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .blendMode(blend)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Background

/// The page: a linen wash lit from the top, with grain. Put it behind every screen:
/// `ZStack { MuseBackground(); ScrollView { … } }` or `.background { MuseBackground() }`.
struct MuseBackground: View {
    var body: some View {
        EllipticalGradient(
            stops: [
                .init(color: MuseColor.groundWash, location: 0),
                .init(color: MuseColor.ground, location: 0.55),
                .init(color: MuseColor.groundDeep, location: 1),
            ],
            center: UnitPoint(x: 0.5, y: 0),
            startRadiusFraction: 0,
            endRadiusFraction: 1
        )
        .overlay { MuseGrainOverlay(opacity: MuseGrain.pageOpacity) }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Stock

/// The one table behind every surface: fill, hairline and lift.
nonisolated enum MuseStock: Sendable, CaseIterable {
    /// Raised, hairline, e1. Muse cards, app cards.
    case card
    /// Raised, hairline, e1. Tiles and default pills.
    case tile
    /// Inset, softer hairline, flat. Fields, code, rows inside a card.
    case inset
    /// Raised, hairline, flat. Chrome capsules and circles at the top of a page.
    case chrome
    /// White, hairline, e2. The composer.
    case composer
    /// Shelf khaki, no hairline, flat. Fill-only chips.
    case chip

    var fill: Color {
        switch self {
        case .card, .tile, .chrome: MuseColor.raised
        case .inset: MuseColor.inset
        case .chip: MuseColor.shelf
        case .composer: MuseColor.composer
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .card, .tile, .chrome, .composer: 0.09
        case .inset: 0.07
        case .chip: 0
        }
    }

    var elevation: MuseElevation {
        switch self {
        case .card, .tile: .e1
        case .composer: .e2
        case .inset, .chrome, .chip: .e0
        }
    }
}

// MARK: - Surfaces

extension View {
    /// Any stock in any shape. The named surfaces below cover almost everything.
    func museStock<S: InsettableShape>(_ stock: MuseStock = .tile, in shape: S) -> some View {
        self
            .background { shape.fill(stock.fill) }
            .overlay {
                if stock.strokeOpacity > 0 {
                    shape.strokeBorder(MuseColor.ink.opacity(stock.strokeOpacity), lineWidth: 0.75)
                }
            }
            .museElevation(stock.elevation)
    }

    /// A raised card with a hairline and a little lift. The muse card, an app card.
    func museCardSurface(cornerRadius: CGFloat = MuseRadius.card) -> some View {
        museStock(.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Same as a card. Use for smaller repeated tiles (results, grid cells).
    func museTileSurface(cornerRadius: CGFloat = MuseRadius.tile) -> some View {
        museStock(.tile, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// A pressed-in well: fields, code blocks, rows inside a card.
    func museInsetSurface(cornerRadius: CGFloat = MuseRadius.control) -> some View {
        museStock(.inset, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// The white composer: where you type or speak.
    func museComposerSurface() -> some View {
        museStock(.composer, in: RoundedRectangle(cornerRadius: MuseRadius.sheet, style: .continuous))
    }

    /// A capsule in any stock. `selected` turns it flat moss (switch the label to `ground`).
    func musePill(_ stock: MuseStock = .tile, selected: Bool = false) -> some View {
        self
            .background {
                Capsule().fill(selected ? MuseColor.moss : stock.fill)
            }
            .overlay {
                if !selected, stock.strokeOpacity > 0 {
                    Capsule().strokeBorder(MuseColor.ink.opacity(stock.strokeOpacity), lineWidth: 0.75)
                }
            }
            .museElevation(selected ? .e0 : stock.elevation)
    }

    /// A 34pt raised capsule for the chrome row (status pills, the ring pill).
    func museTopChrome() -> some View {
        self
            .frame(height: MuseTopChrome.height)
            .musePill(.chrome)
    }

    /// The soft milky fade at the home indicator. Put it on the ScrollView, and never ignore
    /// the bottom safe area on that scroll. Pass `hostBar: false` when the scroll already
    /// has a `safeAreaBar`.
    func museBottomBlur(wash: Color = MuseColor.ground, hostBar: Bool = true) -> some View {
        modifier(MuseBottomBlur(wash: wash, hostBar: hostBar))
    }
}

/// iOS 26 soft scroll-edge blur, hosted by a chrome-less bar so pages without a tab bar
/// still get the fade. Reduce Transparency falls back to a short paper wash.
private struct MuseBottomBlur: ViewModifier {
    var wash: Color
    var hostBar: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .scrollEdgeEffectHidden(true, for: .bottom)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            .init(color: wash.opacity(0), location: 0),
                            .init(color: wash.opacity(0.7), location: 0.55),
                            .init(color: wash.opacity(1), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: MuseSpacing.section)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        } else if hostBar {
            content
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: MuseSpacing.xs)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        } else {
            content
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
    }
}

// MARK: - Glass

/// Frosted paper for things that float over content: toasts, a floating bar.
struct MuseGlassSurface: View {
    var cornerRadius: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.thinMaterial)
            .overlay { shape.fill(MuseColor.raised.opacity(0.88)) }
            .overlay { shape.strokeBorder(MuseColor.hairline, lineWidth: 0.75) }
            .museElevation(.e2)
    }
}
