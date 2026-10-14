import SwiftUI

/// The ring on an index finger, the button toward the thumb, as the booklet draws it
/// (`BookletHand`). The booklet's drawing ends at its panel's edge, so the wrist fades out
/// there. The cheat card's wear section uses it. Decorative: hidden from VoiceOver.
struct MuseHandArt: View {
    var width: CGFloat = 120

    /// The drawing's width over its height, so its size never depends on the room offered.
    private static let aspect: CGFloat = 1000.0 / 729.0

    var body: some View {
        Image("BookletHand")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: width / Self.aspect)
            .mask {
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    MuseHandArt(width: 200)
        .padding(MuseSpacing.page)
        .background { MuseBackground() }
}
