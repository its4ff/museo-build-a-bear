#if DEBUG
import SwiftUI

/// A sheet drawn at rest, so a screenshot shows it: the page dimmed behind, the sheet
/// raised over it with its top corners rounded and (for sheets with two detents) the
/// grabber. The real app presents these with `.sheet` and `presentationDetents`.
///
/// ```swift
/// LabSheet(.medium) { HomeView() } content: { RingSheet(status: .linked, actions: .preview) }
/// ```
struct LabSheet<Page: View, Content: View>: View {
    enum Detent {
        /// About half the screen, where a two-detent sheet comes to rest.
        case medium
        /// Just under the status bar.
        case large
    }

    let detent: Detent
    let grabber: Bool
    let page: Page
    let content: Content

    /// The gap a large sheet leaves under the status bar.
    private static var largeGap: CGFloat { MuseSpacing.xs + 2 }
    /// Share of the screen a medium sheet covers.
    private static var mediumShare: CGFloat { 0.52 }

    init(
        _ detent: Detent = .large,
        grabber: Bool = true,
        @ViewBuilder page: () -> Page,
        @ViewBuilder content: () -> Content
    ) {
        self.detent = detent
        self.grabber = grabber
        self.page = page()
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let screen = CGSize(
                width: geo.size.width + insets.leading + insets.trailing,
                height: geo.size.height + insets.top + insets.bottom
            )
            let height = sheetHeight(screen: screen, topInset: insets.top)
            ZStack {
                page
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                MuseColor.ink.opacity(0.22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    sheet(bottomInset: insets.bottom)
                        .frame(width: screen.width, height: height)
                }
                .frame(width: screen.width, height: screen.height)
                .ignoresSafeArea()
            }
        }
    }

    private func sheetHeight(screen: CGSize, topInset: CGFloat) -> CGFloat {
        switch detent {
        case .large: screen.height - topInset - Self.largeGap
        case .medium: (screen.height * Self.mediumShare).rounded()
        }
    }

    private func sheet(bottomInset: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: MuseRadius.sheet,
            topTrailingRadius: MuseRadius.sheet,
            style: .continuous
        )
        return content
            .safeAreaPadding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MuseColor.raised)
            .overlay(alignment: .top) {
                if grabber {
                    Capsule()
                        .fill(MuseColor.ink.opacity(0.18))
                        .frame(width: 36, height: 5)
                        .padding(.top, MuseSpacing.xxs + 1)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(shape)
            .museElevation(.e2)
    }
}
#endif
