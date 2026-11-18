import SwiftUI

// What the menu bar panel's pieces share: their measures, and a few quiet controls in the
// duo language (a moss switch, a paper key cap, a choice as plain words).

nonisolated enum PanelMetrics {
    static let width: CGFloat = 310
    /// How much of the dune's color the panel's paper carries.
    static let dune: Double = 0.42
    static let rowHeight: CGFloat = 32

    // MARK: The ring

    /// The "more" glyph beside the pill, and its hit box.
    static let more: CGFloat = 13
    static let moreBox: CGFloat = 28
    /// A quiet text action's hit height.
    static let wordButton: CGFloat = 24

    // MARK: Controls

    static let switchWidth: CGFloat = 30
    static let switchHeight: CGFloat = 18
    static let switchKnob: CGFloat = 14
    static let chevron: CGFloat = 9
    static let power: CGFloat = 13
    /// A small field or picker inside the panel.
    static let field: CGFloat = 24
    static let fieldRadius: CGFloat = 7

    // MARK: Commands

    static let keyCapHeight: CGFloat = 20
    static let keyCapWidth: CGFloat = 34
    static let keyCapRadius: CGFloat = 6
    /// From a key to its phrase: tight enough that "open claude" fits its half of the panel.
    static let keyGap: CGFloat = 6
    static let phrase: CGFloat = 14.5
    static let alternateDot: CGFloat = 3
    static let alternateGap: CGFloat = 2.5
    static let commandRow: CGFloat = 28
    static let hoverRadius: CGFloat = 9
    static let appIcon: CGFloat = 22

    // MARK: Recent

    static let recentWords: CGFloat = 15
    static let unseenDot: CGFloat = 5
}

/// A switch at the panel's size: moss when on, a white knob. Drawn, so it never borrows the
/// system's green. Use as `.toggleStyle(PanelSwitchStyle())`.
struct PanelSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? AnyShapeStyle(MuseColor.primaryGradient) : AnyShapeStyle(MuseColor.ink.opacity(0.14)))
                .frame(width: PanelMetrics.switchWidth, height: PanelMetrics.switchHeight)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(MuseColor.composer)
                        .frame(width: PanelMetrics.switchKnob, height: PanelMetrics.switchKnob)
                        .padding(.horizontal, (PanelMetrics.switchHeight - PanelMetrics.switchKnob) / 2)
                        .museElevation(.e1)
                }
                // The whole row's height takes the click.
                .frame(height: PanelMetrics.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .museAnimation(MuseMotion.snappy, value: configuration.isOn)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// What a command presses: a small paper key with a hairline edge. A rarer, longer label
/// just runs wider.
struct PanelKeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    private static let shape = RoundedRectangle(cornerRadius: PanelMetrics.keyCapRadius, style: .continuous)

    var body: some View {
        Text(text)
            .font(MuseType.captionMedium)
            .foregroundStyle(MuseColor.ink70)
            .lineLimit(1)
            .padding(.horizontal, MuseSpacing.xxs)
            .frame(minWidth: PanelMetrics.keyCapWidth)
            .frame(height: PanelMetrics.keyCapHeight)
            .background(DuoColor.paper.opacity(0.9), in: Self.shape)
            .overlay { Self.shape.strokeBorder(MuseColor.hairline, lineWidth: 1) }
            .fixedSize()
    }
}

/// A row's current choice as plain words and one small glyph: no box round it.
struct PanelChoiceLabel: View {
    let value: String
    var detail: String?
    let symbol: String

    var body: some View {
        HStack(spacing: MuseSpacing.xxs + MuseSpacing.xxs / 2) {
            Text(value)
                .foregroundStyle(MuseColor.ink70)
                .monospacedDigit()
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
            }
            Image(systemName: symbol)
                .museSymbol(PanelMetrics.chevron, weight: .semibold)
                .foregroundStyle(MuseColor.ink55)
        }
        .font(MuseType.meta)
        .frame(height: PanelMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

/// The panel's paper: the dune, quiet. Popovers off the panel wear it too.
struct PanelGround: View {
    var body: some View {
        PocketGround(strength: PanelMetrics.dune, stipple: LibraryWindow.ground.stipple, fine: LibraryWindow.ground.fine)
    }
}

extension View {
    /// A small field or picker inside the panel: paper and a hairline.
    func panelField() -> some View {
        background(DuoColor.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: PanelMetrics.fieldRadius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: PanelMetrics.fieldRadius, style: .continuous).strokeBorder(MuseColor.hairline, lineWidth: 1) }
    }
}
