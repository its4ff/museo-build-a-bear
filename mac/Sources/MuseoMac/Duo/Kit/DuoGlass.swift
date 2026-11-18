import SwiftUI

// The mac's glass. Captured (and in a window that isn't key) Liquid Glass reads cooler and
// greyer on the mac than on the iphone, where a tile is warm cream. These modifiers carry
// the warmth themselves: the glass is tinted with warm paper and a thin wash of the same
// paper sits over it, so a mac tile and an iphone tile are one material. Under Reduce
// Transparency (or `.duoOpaqueGlass()`), opaque paper and a hairline.

nonisolated enum DuoColor {
    /// Warm cream: the house paper leaning a little toward the sand.
    static let cream = MuseColor.raised.mix(with: MuseColor.ochreTint, by: 0.16)
    /// What the glass itself is tinted with.
    static let glassTint = cream.opacity(0.7)
    /// The paper washed over a tile's glass.
    static let tileWash = MuseColor.composer.mix(with: MuseColor.ochreTint, by: 0.3).opacity(0.84)
    /// The lighter wash on a control.
    static let controlWash = MuseColor.composer.mix(with: MuseColor.ochreTint, by: 0.2).opacity(0.88)
    /// The light edge glass wears along its top.
    static let edge = MuseColor.composer.opacity(0.85)
    static let edgeFar = MuseColor.composer.opacity(0.18)
    /// The opaque stand in.
    static let paper = MuseColor.raised
    /// The selected row's words, and its quiet line.
    static let onMoss = MuseColor.composer
    static let onMossQuiet = MuseColor.composer.opacity(0.72)
    /// The lozenge under the current place in the corner: sage, a step off the cream.
    static let lozenge = MuseColor.mossTint.mix(with: MuseColor.moss300, by: 0.18)
    /// The faint line a tile's lower edge wears, so it holds its shape on linen.
    static let tileEdge = MuseColor.ink.opacity(0.11)
    static let tileEdgeNear = MuseColor.ink.opacity(0.03)
    /// A row under the pointer.
    static let hover = MuseColor.ink.opacity(0.045)
}

extension EnvironmentValues {
    /// True draws every duo glass as opaque paper (what Reduce Transparency does).
    @Entry var duoOpaqueGlass = false
}

extension View {
    /// The tile surface: warm Liquid Glass in a rounded rectangle. For tiles, rows, panels
    /// and columns; never on a block of text. Apply last, after padding and frame.
    func duoTileGlass(cornerRadius: CGFloat = MuseRadius.tile) -> some View {
        modifier(DuoGlass(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            wash: DuoColor.tileWash,
            interactive: false,
            lifts: false
        ))
    }

    /// The control surface: warm, a little lighter, interactive, with a soft lift. A
    /// capsule by default; `in: Circle()` for a round one.
    func duoControlGlass(in shape: some InsettableShape = Capsule()) -> some View {
        modifier(DuoGlass(shape: shape, wash: DuoColor.controlWash, interactive: true, lifts: true))
    }

    /// Opaque paper in place of glass, for a render of the Reduce Transparency look.
    func duoOpaqueGlass(_ isOpaque: Bool = true) -> some View {
        environment(\.duoOpaqueGlass, isOpaque)
    }
}

private struct DuoGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let wash: Color
    let interactive: Bool
    let lifts: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.duoOpaqueGlass) private var opaque

    func body(content: Content) -> some View {
        if reduceTransparency || opaque {
            content
                .background(DuoColor.paper, in: shape)
                .overlay { shape.strokeBorder(MuseColor.hairline) }
        } else {
            content
                .background {
                    shape.fill(wash)
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [DuoColor.edge, DuoColor.edgeFar],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    if !lifts {
                        // A tile has no shadow: its foot gets the faintest ink instead.
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [DuoColor.tileEdgeNear, DuoColor.tileEdge],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    }
                }
                .glassEffect(.regular.tint(DuoColor.glassTint).interactive(interactive), in: shape)
                .museElevation(lifts ? .e1 : .e0)
        }
    }
}

// MARK: - A glass circle

/// A round glass control with one symbol: search, settings, add, back. `label` is what
/// VoiceOver says, lowercase.
struct DuoGlassCircle: View {
    let systemName: String
    let label: String
    var action: () -> Void = {}

    init(_ systemName: String, label: String, action: @escaping () -> Void = {}) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .museSymbol(DuoMetrics.symbol, weight: .regular)
                .foregroundStyle(MuseColor.ink70)
                .frame(width: DuoMetrics.bar, height: DuoMetrics.bar)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .duoControlGlass(in: Circle())
        .accessibilityLabel(label)
    }
}

// MARK: - A quiet glass button

/// A glass capsule with a few words: "send to…". The quiet second choice beside the
/// listen capsule; never the window's primary.
struct DuoQuietButton: View {
    let title: String
    var action: () -> Void = {}

    init(_ title: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink70)
                .lineLimit(1)
                .padding(.horizontal, MuseSpacing.card)
                .frame(height: DuoMetrics.bar)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .duoControlGlass()
    }
}
