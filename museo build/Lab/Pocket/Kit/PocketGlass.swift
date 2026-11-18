#if DEBUG || os(macOS) // museo for mac draws these in its real windows
import SwiftUI

// The pocket's materials. Tiles are glass so the dune shows through (the dune decision);
// controls are interactive glass; the ring pill is the moss, with its grain. Every one has
// a paper fallback under Reduce Transparency.

// MARK: - Glass

extension View {
    /// The tile surface: Liquid Glass in a rounded rectangle, warmed so it reads as paper
    /// the dune shows through. For tiles and rows, never for a block of text.
    func pocketTileGlass(cornerRadius: CGFloat = MuseRadius.tile) -> some View {
        modifier(PocketTileGlass(cornerRadius: cornerRadius))
    }

    /// Interactive glass for a control: a capsule by default, `.circle` for round ones.
    /// `tint` colors it (moss for a selected one).
    func pocketControlGlass(in shape: some InsettableShape = Capsule(), tint: Color? = nil) -> some View {
        modifier(PocketControlGlass(shape: shape, tint: tint))
    }

    /// The fine grain every pill fill shares, so each state is one material. Gone under
    /// Reduce Transparency.
    func pocketFillGrain() -> some View {
        modifier(PocketFillGrain())
    }
}

private struct PocketTileGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(MuseColor.raised, in: shape)
                .overlay { shape.strokeBorder(MuseColor.hairline) }
        } else {
            content
                .glassEffect(.regular.tint(PocketColor.tileTint), in: shape)
        }
    }
}

private struct PocketControlGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(tint ?? MuseColor.raised, in: shape)
                .overlay { shape.strokeBorder(MuseColor.hairline) }
        } else {
            content
                .glassEffect(.regular.tint(tint ?? PocketColor.tileTint).interactive(), in: shape)
        }
    }
}

private struct PocketFillGrain: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceTransparency {
                ZStack {
                    PocketGrain.fineDark
                        .resizable(resizingMode: .tile)
                        .interpolation(.none)
                        .opacity(0.22)
                        .blendMode(.multiply)
                    PocketGrain.fineLight
                        .resizable(resizingMode: .tile)
                        .interpolation(.none)
                        .opacity(0.3)
                        .blendMode(.screen)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - A glass circle

/// A round glass control with one symbol: settings, search, add. 44pt, so it is its own
/// hit target. `label` is what VoiceOver says, lowercase.
struct PocketGlassCircle: View {
    let systemName: String
    let label: String
    var action: () -> Void = {}

    init(_ systemName: String, label: String, action: @escaping () -> Void = {}) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            Image(systemName: systemName)
                .museSymbol(PocketGlassMetrics.symbol, weight: .medium)
                .foregroundStyle(MuseColor.ink70)
                .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pocketControlGlass(in: Circle())
        .accessibilityLabel(label)
    }
}

nonisolated enum PocketGlassMetrics {
    /// A chrome symbol's size inside a 44pt glass circle.
    static let symbol: CGFloat = 17
}

// MARK: - The moss

/// The premium moss: the house greens as a mesh, lighter where the light lands, with the
/// dune's light speck screened over it and a soft highlight along the top. It fills its
/// bounds; clip it, or use `.pocketMossPill()`. Grain and highlight go under Reduce
/// Transparency.
struct PocketMoss: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.42, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Self.lit, Self.lit, MuseColor.moss,
                MuseColor.moss600, MuseColor.moss600, Self.deep,
                MuseColor.moss, Self.deep, MuseColor.moss900,
            ],
            smoothsColors: true,
            colorSpace: .perceptual
        )
        .overlay {
            if !reduceTransparency {
                ZStack {
                    PocketGrain.fineLight
                        .resizable(resizingMode: .tile)
                        .interpolation(.none)
                        .opacity(0.2)
                        .blendMode(.screen)
                    PocketGrain.fineDark
                        .resizable(resizingMode: .tile)
                        .interpolation(.none)
                        .opacity(0.3)
                        .blendMode(.multiply)
                    LinearGradient(
                        colors: [MuseColor.composer.opacity(0.14), MuseColor.composer.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the light lands.
    private static let lit = MuseColor.moss600.mix(with: MuseColor.moss300, by: 0.22)
    /// The far, shaded end.
    private static let deep = MuseColor.moss900.mix(with: MuseColor.moss, by: 0.45)
}

extension View {
    /// The moss as a capsule behind this view: fill, a light inner edge along the top, and
    /// its lift.
    func pocketMossPill() -> some View {
        background {
            PocketMoss()
                .clipShape(Capsule())
                .overlay { PocketPillEdge(onDark: true) }
                .museElevation(.e1)
        }
    }
}

/// The inner highlight every pill wears along its top edge.
struct PocketPillEdge: View {
    var onDark = false

    var body: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        MuseColor.composer.opacity(onDark ? 0.34 : 0.9),
                        MuseColor.composer.opacity(onDark ? 0.04 : 0.2),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - The other pill fills

/// Away: plain paper.
struct PocketPaperFill: View {
    var body: some View {
        MuseColor.raised
            .pocketFillGrain()
    }
}

/// Streaming: warm off-white, for black words.
struct PocketOffWhiteFill: View {
    var body: some View {
        PocketColor.pillPaper
            .pocketFillGrain()
    }
}

/// Memory: amber sweeps in from the leading edge, then breathes while it lasts. Reduce
/// Motion: the amber, still.
struct PocketAmberFill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIn = false
    @State private var isBreathing = false

    var body: some View {
        LinearGradient(
            colors: [PocketColor.pillAmber, PocketColor.pillAmberGlow],
            startPoint: .leading,
            endPoint: .trailing
        )
        .pocketFillGrain()
        .opacity(isBreathing ? 0.88 : 1)
        .scaleEffect(x: isIn || reduceMotion ? 1 : 0.001, anchor: .leading)
        .background(PocketColor.pillPaper)
        .task {
            guard !reduceMotion else { return }
            withAnimation(MuseMotion.drift) { isIn = true }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

/// A fill from the leading edge to `level` (0...1) over off-white: moss rising while
/// recordings come in, green to the battery's level while it charges.
struct PocketLevelFill: View {
    let level: Double
    let color: Color

    var body: some View {
        LinearGradient(
            colors: [color, color.opacity(0.78)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(alignment: .leading) {
            Rectangle()
                .scaleEffect(x: min(max(level, 0.06), 1), anchor: .leading)
        }
        .background(PocketColor.pillPaper)
        .pocketFillGrain()
        .museAnimation(MuseMotion.gentle, value: level)
    }
}
#endif
