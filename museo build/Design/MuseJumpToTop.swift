import SwiftUI

// Back to the top of a long scroll: a small raised
// circle with a chevron at the bottom trailing corner. It shows once the page runs past
// 1.75 screens and you've scrolled most of a screen down, so a short page never has it.
//
// ```swift
// @State private var position = ScrollPosition(idType: UUID.self)
// @State private var showsJump = false
//
// ScrollView { … }
//     .scrollPosition($position)
//     .museJumpTracking($showsJump)
// // on the screen around it, above the safe area:
// .museJumpToTop($position, visible: showsJump)
// ```

// MARK: - Metrics

nonisolated enum MuseJump {
    /// The circle. Its hit target is still 44pt.
    static let circle: CGFloat = 32
    /// The page has to be this many screens long before the button can show.
    static let longPage: CGFloat = 1.75
    /// And scrolled this much of a screen down.
    static let scrolledDown: CGFloat = 0.85
}

extension View {
    /// Shows the jump button at the bottom trailing corner while `visible`. Tapping it plays
    /// `.soft` and eases the scroll back to the top with `MuseMotion.gentle`.
    func museJumpToTop(
        _ position: Binding<ScrollPosition>,
        visible: Bool,
        bottomClearance: CGFloat = MuseSpacing.sm
    ) -> some View {
        overlay(alignment: .bottomTrailing) {
            MuseJumpButton(position: position, visible: visible)
                .padding(.trailing, MuseSpacing.page - (MuseTopChrome.hitTarget - MuseJump.circle) / 2)
                .padding(.bottom, bottomClearance)
        }
    }

    /// Put on the `ScrollView`: keeps `showsJump` true while the page is long and scrolled
    /// well down (`MuseJump`).
    func museJumpTracking(_ showsJump: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            let page = geometry.containerSize.height
            guard page > 0 else { return false }
            let isLong = geometry.contentSize.height > page * MuseJump.longPage
            let scrolled = geometry.contentOffset.y + geometry.contentInsets.top
            return isLong && scrolled > page * MuseJump.scrolledDown
        } action: { _, shows in
            showsJump.wrappedValue = shows
        }
    }
}

// MARK: - Button

private struct MuseJumpButton: View {
    @Binding var position: ScrollPosition
    let visible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            withAnimation(MuseMotion.adaptive(MuseMotion.gentle, reduceMotion: reduceMotion)) {
                position.scrollTo(edge: .top)
            }
        } label: {
            Image(systemName: "chevron.up")
                .font(MuseFont.symbol(12, weight: .bold))
                .foregroundStyle(MuseColor.ink70)
                .frame(width: MuseJump.circle, height: MuseJump.circle)
                .museStock(.tile, in: Circle())
                .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.9))
        .accessibilityLabel("back to the top")
        .accessibilityHidden(!visible)
        .opacity(visible ? 1 : 0)
        // Under Reduce Motion it only fades.
        .scaleEffect(visible || reduceMotion ? 1 : 0.7)
        .allowsHitTesting(visible)
        .animation(MuseMotion.snappy, value: visible)
    }
}
