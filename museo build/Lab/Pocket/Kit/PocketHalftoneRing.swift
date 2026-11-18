#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import CoreGraphics
import Foundation
import SwiftUI

/// The ring's light, when it shows.
nonisolated enum PocketRingLight: Hashable, Sendable {
    /// Recording to itself.
    case amber
    /// Streaming.
    case white
}

/// The ring as print: square dots on a grid, bigger where the metal is darker, the light as
/// a soft glow on the band (none at all when the ring is only linked). Museo dune's dot ring, seen from above, drawn from geometry
/// here so it needs no image: a flat face between an outer bevel and an inner wall, lit from
/// where the lamp sits.
///
/// ```swift
/// PocketHalftoneRing(size: 190)                                   // the ring sheet
/// PocketHalftoneRing(size: 22, ink: PocketColor.printSand)        // the pill's mark, on moss
/// PocketHalftoneRing(size: 120, light: .amber)                    // recording
/// ```
///
/// Decorative: hidden from VoiceOver unless you label it.
struct PocketHalftoneRing: View {
    var size: CGFloat
    var ink: Color = MuseColor.ink
    var light: PocketRingLight?
    /// Cells across. Nil picks one for the size: about 2.5pt a cell, as dune prints it.
    var dots: Int?

    init(size: CGFloat, ink: Color = MuseColor.ink, light: PocketRingLight? = nil, dots: Int? = nil) {
        self.size = size
        self.ink = ink
        self.light = light
        self.dots = dots
    }

    var body: some View {
        let n = dots ?? Self.cells(for: size)
        let tone = PocketHalftoneCache.tone(n)
        let lightColor: Color? = switch light {
        case .amber: MuseColor.ringAmber
        case .white: MuseColor.composer
        case nil: nil
        }
        // The canvas is wider than the ring, so the light's glow thins out past the band
        // instead of stopping at the frame.
        let side = size
        Canvas { context, canvas in
            let origin = CGPoint(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2)
            context.fill(tone.squares(tone.ink, side: side, origin: origin), with: .color(ink))
            // The band is whole under the light: off, the lamp is just more of the metal.
            context.fill(tone.squares(tone.lampBand, side: side, origin: origin), with: .color(ink))
            if let lightColor {
                let center = CGPoint(x: origin.x + tone.lightAt.x * side, y: origin.y + tone.lightAt.y * side)
                if light == .white {
                    // White has no color of its own to glow with on paper, so the ring's ink
                    // gathers softly round it first: a small shadow the light then sits in.
                    // Kept faint and close: any stronger and it reads as a grey smudge on the
                    // band instead of a light.
                    let halo = side * 0.2
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                        with: .radialGradient(
                            Gradient(stops: [
                                .init(color: ink.opacity(0.2), location: 0),
                                .init(color: ink.opacity(0.09), location: 0.5),
                                .init(color: ink.opacity(0), location: 1),
                            ]),
                            center: center, startRadius: 0, endRadius: halo
                        )
                    )
                }
                // The light itself: a bright core that thins out to nothing. No cells, no edge.
                let reach = side * (light == .white ? 0.11 : 0.21)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: lightColor, location: 0),
                            .init(color: lightColor.opacity(0.92), location: 0.3),
                            .init(color: lightColor.opacity(0.4), location: 0.62),
                            .init(color: lightColor.opacity(0), location: 1),
                        ]),
                        center: center, startRadius: 0, endRadius: reach
                    )
                )
            }
        }
        .frame(width: size * Self.glowRoom, height: size * Self.glowRoom)
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The canvas, as a multiple of the ring: room for the glow on every side.
    private static let glowRoom: CGFloat = 1.5

    private static func cells(for size: CGFloat) -> Int {
        min(76, max(11, Int((size / 2.5).rounded())))
    }
}

// MARK: - The screen

/// The ring measured on an n by n grid: where each dot sits and how heavy it prints.
nonisolated struct PocketHalftone: Sendable {
    let n: Int
    /// The metal: x, y (0...1) and weight (0...1), three numbers a dot.
    let ink: [Float]
    /// The cells under the light, printed as the band they are part of.
    let lampBand: [Float]
    /// Where the light sits, 0...1.
    let lightAt: CGPoint

    /// The band's outer edge, as a fraction of half the frame.
    private static let outer: Float = 0.95
    /// Its inner edge: dune's slim band at size, a heavier one for a small mark, so the
    /// band is always a few cells wide and prints as a ring, not a dotted line.
    private static func inner(_ n: Int) -> Float { n < 30 ? 0.6 : 0.75 }
    /// The light: on the band, up and to the right.
    private static let lightAngle: Float = -52 * .pi / 180

    init(n: Int) {
        let small = n < 30
        let outer = Self.outer, inner = Self.inner(n)
        let mid = (outer + inner) / 2
        // Toward the lamp, which is also where the daylight comes from.
        let towardX = cos(Self.lightAngle), towardY = sin(Self.lightAngle)
        let lx = towardX * mid, ly = towardY * mid
        let cell = 2 / Float(n)
        let lampReach = max(cell * 0.75, 0.085)
        var ink: [Float] = []
        var lamp: [Float] = []
        let taps = 4
        for y in 0..<n {
            for x in 0..<n {
                // How much of the cell the band covers.
                var hit = 0
                for sy in 0..<taps {
                    for sx in 0..<taps {
                        let u = (Float(x) + (Float(sx) + 0.5) / Float(taps)) * cell - 1
                        let v = (Float(y) + (Float(sy) + 0.5) / Float(taps)) * cell - 1
                        let r = (u * u + v * v).squareRoot()
                        if r <= outer && r >= inner { hit += 1 }
                    }
                }
                guard hit > 0 else { continue }
                let cover = Float(hit) / Float(taps * taps)
                let u = (Float(x) + 0.5) * cell - 1, v = (Float(y) + 0.5) * cell - 1
                let cx = (Float(x) + 0.5) / Float(n), cy = (Float(y) + 0.5) / Float(n)
                let underLamp = ((u - lx) * (u - lx) + (v - ly) * (v - ly)).squareRoot() < lampReach
                let r = max((u * u + v * v).squareRoot(), 0.001)
                let across = min(1, max(0, (r - inner) / (outer - inner)))
                // 1 where the band faces the light, -1 on the far side.
                let facing = (u * towardX + v * towardY) / r
                let dark: Float
                if small {
                    // A small mark has no room for bevels: one slow turn from lit to shaded.
                    dark = 0.76 - 0.3 * facing
                } else {
                    // The ring from above is three surfaces: the flat face, an outer bevel
                    // that catches the light on the near side and falls dark on the far
                    // one, and an inner wall that does the opposite.
                    let outerBevel = Self.smooth(0.56, 1, across)
                    let innerWall = 1 - Self.smooth(0, 0.4, across)
                    dark = 0.66 - 0.08 * facing
                        + outerBevel * (0.16 - 0.5 * facing)
                        + innerWall * (-0.16 + 0.5 * facing)
                }
                let tone = min(1, max(small ? 0.42 : 0.12, dark))
                let edge = 4 * cover * (1 - cover)
                let weight = min(1, cover * tone + edge * (small ? 0.1 : 0.16))
                guard weight > 0.05 else { continue }
                if underLamp {
                    lamp += [cx, cy, weight]
                } else {
                    ink += [cx, cy, weight]
                }
            }
        }
        self.n = n
        self.ink = ink
        self.lampBand = lamp
        self.lightAt = CGPoint(x: CGFloat(lx + 1) / 2, y: CGFloat(ly + 1) / 2)
    }

    private static func smooth(_ from: Float, _ to: Float, _ x: Float) -> Float {
        let t = min(1, max(0, (x - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }

    /// Dots as square cells on a frame `side` wide, one path for one fill.
    func squares(_ dots: [Float], side: CGFloat, origin: CGPoint = .zero, spread: CGFloat = 1) -> Path {
        var path = Path()
        let most = side / CGFloat(n) * spread * 0.92
        var i = 0
        while i + 2 < dots.count {
            let width = most * CGFloat(dots[i + 2]).squareRoot()
            if width >= 0.4 {
                path.addRect(CGRect(
                    x: origin.x + CGFloat(dots[i]) * side - width / 2,
                    y: origin.y + CGFloat(dots[i + 1]) * side - width / 2,
                    width: width,
                    height: width
                ))
            }
            i += 3
        }
        return path
    }
}

/// Each grid measured once: the same few are asked for on every redraw.
@MainActor
private enum PocketHalftoneCache {
    private static var tones: [Int: PocketHalftone] = [:]

    static func tone(_ n: Int) -> PocketHalftone {
        if let made = tones[n] { return made }
        let tone = PocketHalftone(n: n)
        tones[n] = tone
        return tone
    }
}
#endif
