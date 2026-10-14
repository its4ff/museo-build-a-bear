import SwiftUI

/// The ring, exactly as the booklet in the box draws it (`BookletRing`, cut from the booklet's
/// vector art with its see-through hole kept clear). The hello screen's hero. Decorative:
/// hidden from VoiceOver.
struct MuseRingArt: View {
    var width: CGFloat = 240

    /// The drawing's width over its height, so its size never depends on the room offered.
    private static let aspect: CGFloat = 1272.0 / 848.0

    var body: some View {
        Image("BookletRing")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: width / Self.aspect)
            .accessibilityHidden(true)
    }
}

#Preview {
    MuseRingArt()
        .padding(MuseSpacing.page)
        .background { MuseBackground() }
}
