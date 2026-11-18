#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import CoreGraphics
import Foundation
import SwiftUI

// The dune, ported from museo dune's `MuseDune`: linen, four pools of color in the corners
// (sage, sand, ochre, moss), a coarse dithered stipple inside them, and a fine paper tooth
// over the whole page. The reading column down the middle stays clear linen.
// Drawn once: the grain is two pairs of tiles made on first use, the pools four gradients.

/// The page's ground on every pocket screen. Put it in `.background { PocketGround() }`.
/// Under Reduce Transparency the grain goes and the pools stay.
struct PocketGround: View {
    /// How much color the pools carry, 0...1.
    var strength: Double = 0.85
    /// How much of the coarse stipple shows inside the pools, 0...1.
    var stipple: Double = 0.8
    /// A finer stipple cell: for a screen read from further back, where the coarse one
    /// reads as noise.
    var fine = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MuseColor.groundWash, MuseColor.ground, MuseColor.groundDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            PocketDunePools(strength: strength)
            if !reduceTransparency {
                tile(PocketGrain.toothDark, blend: .multiply)
                tile(PocketGrain.toothLight, blend: .screen)
                stipple(fine ? PocketGrain.fineDark : PocketGrain.stippleDark, blend: .multiply)
                stipple(fine ? PocketGrain.fineLight : PocketGrain.stippleLight, blend: .screen)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func tile(_ image: Image, blend: BlendMode) -> some View {
        image
            .resizable(resizingMode: .tile)
            .interpolation(.none)
            .blendMode(blend)
    }

    /// The stipple lives only where the pools are.
    private func stipple(_ image: Image, blend: BlendMode) -> some View {
        image
            .resizable(resizingMode: .tile)
            .interpolation(.none)
            .mask { PocketDunePools(strength: 1.25, asMask: true) }
            .opacity(stipple)
            .blendMode(blend)
    }

}

// MARK: - Pools

/// One pool of color: an ellipse in fractions of the page, fading out from its center.
private nonisolated struct PocketDunePool: Sendable {
    let center: UnitPoint
    /// Half its width and height, as fractions of the page.
    let radius: CGSize
    let color: Color
    let alpha: Double

    /// Centers sit off the page so only soft edges reach in. The bottom two sit lowest,
    /// under the navigation, where a page's last line would otherwise land.
    static let corners: [PocketDunePool] = [
        PocketDunePool(center: UnitPoint(x: -0.12, y: -0.06), radius: CGSize(width: 1, height: 0.27), color: PocketColor.duneSage, alpha: 0.95),
        PocketDunePool(center: UnitPoint(x: 1.12, y: -0.02), radius: CGSize(width: 0.78, height: 0.26), color: PocketColor.duneSand, alpha: 0.9),
        PocketDunePool(center: UnitPoint(x: 1.12, y: 1.12), radius: CGSize(width: 0.95, height: 0.3), color: PocketColor.duneOchre, alpha: 0.85),
        PocketDunePool(center: UnitPoint(x: -0.12, y: 1.14), radius: CGSize(width: 1, height: 0.26), color: PocketColor.duneMoss, alpha: 0.9),
    ]
}

/// The pools as color, or (`asMask`) as white for masking the stipple to where they are.
private struct PocketDunePools: View {
    var strength: Double
    var asMask = false

    var body: some View {
        Canvas { context, size in
            for pool in PocketDunePool.corners {
                var layer = context
                layer.translateBy(x: pool.center.x * size.width, y: pool.center.y * size.height)
                layer.scaleBy(x: pool.radius.width * size.width, y: pool.radius.height * size.height)
                let alpha = min(1, pool.alpha * strength)
                layer.fill(
                    Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                    with: .radialGradient(
                        Self.falloff(asMask ? .white : pool.color, alpha: alpha),
                        center: .zero,
                        startRadius: 0,
                        endRadius: 1
                    )
                )
            }
        }
    }

    /// A soft edge: alpha × (1 − d)^1.4, sampled at six stops.
    private static func falloff(_ color: Color, alpha: Double) -> Gradient {
        Gradient(stops: stride(from: 0.0, through: 1.0, by: 0.2).map { d in
            .init(color: color.opacity(alpha * pow(1 - d, 1.4)), location: d)
        })
    }
}

// MARK: - Grain

/// The grain tiles, made once on first use at 3 pixels a point, so a cell lands on whole
/// pixels on a 3x screen. Seeded, so every launch draws the same grain.
nonisolated enum PocketGrain {
    /// Fine tooth: 1 pixel cells, 128pt square.
    static let toothDark = speckTile(cells: 384, cellPixels: 1, seed: 0x4D55_5345, dark: true, density: 0.14, strength: 0.16)
    static let toothLight = speckTile(cells: 384, cellPixels: 1, seed: 0x4D55_5345, dark: false, density: 0.18, strength: 0.35)
    /// The dune's stipple: 3 pixel cells.
    static let stippleDark = speckTile(cells: 192, cellPixels: 3, seed: 0x4455_4E45, dark: true, density: 0.36, strength: 0.55)
    static let stippleLight = speckTile(cells: 192, cellPixels: 3, seed: 0x4455_4E45, dark: false, density: 0.30, strength: 0.75)
    /// A finer stipple, for the ring pill's fills: 2 pixel cells.
    static let fineDark = speckTile(cells: 192, cellPixels: 2, seed: 0x4455_4E45, dark: true, density: 0.36, strength: 0.55)
    static let fineLight = speckTile(cells: 192, cellPixels: 2, seed: 0x4455_4E45, dark: false, density: 0.30, strength: 0.75)

    /// Ordered dither (Bayer 8×8) mixed 30/70 with white noise: even enough to read as a
    /// dithered gradient, loose enough to never show a grid. Dark and light tiles from one
    /// seed never share a cell.
    private static func speckTile(cells: Int, cellPixels: Int, seed: UInt32, dark: Bool, density: Float, strength: Float) -> Image {
        let size = cells * cellPixels
        let tint = (dark ? PocketColor.duneUmber : PocketColor.duneCream).resolve(in: EnvironmentValues())
        // Premultiplied: the speck's color at its strength, clear everywhere else.
        let speck: [UInt8] = [
            UInt8(clamping: Int(min(max(tint.red, 0), 1) * strength * 255)),
            UInt8(clamping: Int(min(max(tint.green, 0), 1) * strength * 255)),
            UInt8(clamping: Int(min(max(tint.blue, 0), 1) * strength * 255)),
            UInt8(clamping: Int(strength * 255)),
        ]
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for cy in 0..<cells {
            for cx in 0..<cells {
                let bayer = Float(bayer8[(cy & 7) * 8 + (cx & 7)]) / 64
                let threshold = bayer * 0.3 + hash(cx, cy, seed) * 0.7
                let on = dark ? threshold < density : threshold > 1 - density
                guard on else { continue }
                for py in 0..<cellPixels {
                    let row = (cy * cellPixels + py) * size
                    for px in 0..<cellPixels {
                        let i = (row + cx * cellPixels + px) * 4
                        pixels[i] = speck[0]
                        pixels[i + 1] = speck[1]
                        pixels[i + 2] = speck[2]
                        pixels[i + 3] = speck[3]
                    }
                }
            }
        }
        let image: CGImage? = pixels.withUnsafeMutableBytes { raw in
            CGContext(
                data: raw.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        guard let image else { return Image(systemName: "circle").resizable() }
        return Image(decorative: image, scale: 3)
    }

    private static let bayer8: [Int] = [
        0, 32, 8, 40, 2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44, 4, 36, 14, 46, 6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
        3, 35, 11, 43, 1, 33, 9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47, 7, 39, 13, 45, 5, 37,
        63, 31, 55, 23, 61, 29, 53, 21,
    ]

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
#endif
