import SwiftUI

/// Capsule buttons. One `.primary` per screen; `.tinted` for reversible actions;
/// `.destructive` is text-only clay. Make it full width by giving the label
/// `.frame(maxWidth: .infinity)`. Heights under 36 draw as a compact chip.
struct MuseButtonStyle: ButtonStyle {
    nonisolated enum Kind: CaseIterable, Sendable {
        /// Moss gradient, ground label. The one thing the screen wants you to do.
        case primary
        /// Raised paper with a hairline.
        case secondary
        /// Moss on moss tint. Reversible, low stakes.
        case tinted
        /// Clay text, no fill. Delete, remove, disconnect.
        case destructive
    }

    var kind: Kind
    var height: CGFloat

    init(_ kind: Kind = .primary, height: CGFloat = 44) {
        self.kind = kind
        self.height = height
    }

    func makeBody(configuration: Configuration) -> some View {
        MuseButtonBody(configuration: configuration, kind: kind, height: height)
    }
}

extension ButtonStyle where Self == MuseButtonStyle {
    /// `.buttonStyle(.muse(.tinted))`
    static func muse(_ kind: MuseButtonStyle.Kind = .primary, height: CGFloat = 44) -> MuseButtonStyle {
        MuseButtonStyle(kind, height: height)
    }
}

private struct MuseButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: MuseButtonStyle.Kind
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled

    private var compact: Bool { height < 36 }

    var body: some View {
        let pressed = configuration.isPressed
        fitted(configuration.label.font(compact ? MuseType.metaMedium : MuseType.label))
            .padding(.horizontal, compact ? MuseSpacing.sm : MuseSpacing.lg)
            .frame(minHeight: height)
            .foregroundStyle(foreground)
            .background { background }
            .overlay { border }
            .contentShape(Capsule().inset(by: compact ? -(MuseTopChrome.hitTarget - height) / 2 : 0))
            .opacity(isEnabled ? (pressed ? 0.86 : 1) : 0.42)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(MuseMotion.press, value: pressed)
            .onChange(of: pressed) { _, down in
                if down { MuseHaptics.prepare() }
            }
    }

    /// A chip stays one line and shrinks a little before it truncates. A full button wraps
    /// to a second line at the large text sizes and grows taller instead of cutting off.
    @ViewBuilder
    private func fitted(_ label: some View) -> some View {
        if compact {
            label
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } else {
            label
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, MuseSpacing.xs)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: MuseColor.ground
        case .secondary: MuseColor.ink
        case .tinted: MuseColor.moss600
        case .destructive: MuseColor.clay
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .primary: Capsule().fill(MuseColor.primaryGradient)
        case .secondary: Capsule().fill(MuseColor.raised)
        case .tinted: Capsule().fill(MuseColor.mossTint)
        case .destructive: Capsule().fill(Color.clear)
        }
    }

    @ViewBuilder
    private var border: some View {
        if kind == .secondary {
            Capsule().strokeBorder(MuseColor.ink.opacity(0.12), lineWidth: 0.75)
        }
    }
}
