import SwiftUI

/// "how museo works.": the cheat card on its own page. The home's question mark opens it as
/// a sheet (`router.open(.howItWorks)`, with `onClose`); the lab shoots it without.
struct RingCheatPage: View {
    var onClose: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                MuseHeader(
                    title: "how \(AppConfig.appName) works.",
                    subtitle: "the ring in one card.",
                    titleSize: 28
                ) {
                    if let onClose {
                        MuseChromeIcon("xmark", label: "close", action: onClose)
                    }
                }
                RingCheatCard()
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, MuseSpacing.section)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .museBottomBlur()
        .background { MuseBackground() }
    }
}

#Preview("how it works") {
    RingCheatPage()
}

#Preview("as a sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RingCheatPage(onClose: {})
                .presentationDetents([.large])
        }
}
