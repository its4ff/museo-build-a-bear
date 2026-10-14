import SwiftUI

extension EnvironmentValues {
    /// True inside `MuseListCard`: rows drop their own card and share one.
    @Entry var museInListCard: Bool = false
}

/// One card holding several rows, with dividers between them. A lone `MuseListRow` or
/// `MuseToggleRow` draws its own card; put two or more in here instead of a card each.
struct MuseListCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id {
                        Rectangle()
                            .fill(MuseColor.divider)
                            .frame(height: 1)
                            .padding(.leading, MuseSpacing.card)
                            .accessibilityHidden(true)
                    }
                    subview
                }
            }
        }
        .environment(\.museInListCard, true)
        .museCardSurface()
    }
}

/// Gives a lone row its own card; inside `MuseListCard` it stays bare.
struct MuseStandaloneRow: ViewModifier {
    let inCard: Bool

    func body(content: Content) -> some View {
        if inCard {
            content
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous))
                .museCardSurface()
        }
    }
}
