import SwiftUI

// Space, corners, motion, lift and the top chrome row. A 4pt base; never two different
// radii touching; three levels of lift; 44pt hit targets everywhere.

// MARK: - Spacing

/// Every gap and inset. Reach for the role, not the number.
nonisolated enum MuseSpacing {
    /// 4. Hairline gaps: icon to label inside a chip.
    static let xxs: CGFloat = 4
    /// 8. Tight stacks: title to meta.
    static let xs: CGFloat = 8
    /// 12. Between sibling rows, cards or chips.
    static let sm: CGFloat = 12
    /// 14. Inside a row.
    static let row: CGFloat = 14
    /// 16. Card padding along the short side.
    static let md: CGFloat = 16
    /// 18. Inside a card.
    static let card: CGFloat = 18
    /// 20. General large gap.
    static let lg: CGFloat = 20
    /// 20. The page gutter on iphone.
    static let page: CGFloat = 20
    /// 24. Generous gaps inside a section.
    static let xl: CGFloat = 24
    /// 28. Between sections.
    static let section: CGFloat = 28
    /// 40. Above a section label, and the page's bottom breath.
    static let sectionLabel: CGFloat = 40
}

// MARK: - Radius

/// Corner radii. Pills, buttons and dots are `Capsule()` / `Circle()`.
nonisolated enum MuseRadius {
    /// 10. Tags, so they never read as buttons.
    static let tag: CGFloat = 10
    /// 14. List rows, inset fields, code blocks.
    static let control: CGFloat = 14
    /// 20. Cards.
    static let card: CGFloat = 20
    /// 20. Tiles (same as cards).
    static let tile: CGFloat = 20
    /// 28. Sheets and the composer.
    static let sheet: CGFloat = 28
}

// MARK: - Motion

/// One motion vocabulary so every screen moves like the same product.
nonisolated enum MuseMotion {
    /// Toggles, segments, chrome state; the Reduce Motion fallback.
    static let snappy = Animation.interactiveSpring(response: 0.24, dampingFraction: 0.82)
    /// The default state change.
    static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Page covers, scrolling to the top, a value easing to its new level.
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)
    /// A playful settle. Use rarely.
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.68)
    /// A muse arriving or leaving: slow, a little bounce, then still.
    static let drift = Animation.spring(response: 0.84, dampingFraction: 0.78)
    /// Copy changing in place. Springs reflow the line as it fades; this does not.
    static let dissolve = Animation.easeInOut(duration: 0.42)
    /// Something getting crossed out: slow, even, no bounce.
    static let crossing = Animation.easeInOut(duration: 0.68)
    /// A selection sliding to its new place (segments, tabs).
    static let select = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// The press-down spring every tappable thing shares.
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.6)

    /// `animation`, or `snappy` when Reduce Motion is on.
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? snappy : animation
    }
}

extension View {
    /// `.animation(_:value:)` that swaps long springs for `MuseMotion.snappy` under
    /// Reduce Motion.
    func museAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MuseAdaptiveAnimation(animation: animation, value: value))
    }
}

private struct MuseAdaptiveAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(MuseMotion.adaptive(animation, reduceMotion: reduceMotion), value: value)
    }
}

// MARK: - Elevation

/// Three levels of lift. Shadows are green-black at low alpha, never grey.
nonisolated enum MuseElevation: Sendable {
    /// Hairline only, inside scrolling content.
    case e0
    /// Tappable cards.
    case e1
    /// The composer, sheets, toasts, the orb.
    case e2
}

extension View {
    /// Lifts a surface off the page: `.museElevation(.e1)`.
    @ViewBuilder
    func museElevation(_ level: MuseElevation) -> some View {
        switch level {
        case .e0:
            self
        case .e1:
            self
                .shadow(color: MuseColor.ink.opacity(0.05), radius: 1, x: 0, y: 1)
                .shadow(color: MuseColor.ink.opacity(0.16), radius: 10, x: 0, y: 6)
        case .e2:
            self
                .shadow(color: MuseColor.ink.opacity(0.06), radius: 4, x: 0, y: 2)
                .shadow(color: MuseColor.ink.opacity(0.22), radius: 22, x: 0, y: 10)
        }
    }
}

// MARK: - Top chrome

/// The row of chrome at the top of a page (build, the ring button).
nonisolated enum MuseTopChrome {
    /// Height of a chrome capsule (`museTopChrome()`).
    static let height: CGFloat = 34
    /// Where a scrolling title starts under the chrome row: an 8pt inset plus a 44pt target.
    static let headerClearance: CGFloat = 52
    /// A chrome circle (`MuseChromeIcon`, the ring button).
    static let circle: CGFloat = 38
    /// The smallest thing a finger should have to hit.
    static let hitTarget: CGFloat = 44
}
