import SwiftUI

/// An SF Symbol in a small rounded square: an app's icon, a row's icon. `.moss` for things
/// that are yours (apps), `.quiet` for tools and settings.
struct MuseIconTile: View {
    nonisolated enum Tone: Sendable { case moss, quiet }

    let systemName: String
    var size: CGFloat
    var tone: Tone

    init(_ systemName: String, size: CGFloat = 28, tone: Tone = .moss) {
        self.systemName = systemName
        self.size = size
        self.tone = tone
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        Image(systemName: systemName)
            .font(MuseFont.symbol(size * 0.52, weight: .semibold))
            .foregroundStyle(tone == .moss ? MuseColor.moss600 : MuseColor.ink70)
            .frame(width: size, height: size)
            .background(tone == .moss ? MuseColor.mossTint : MuseColor.shelf, in: shape)
            .overlay {
                if tone == .quiet { shape.strokeBorder(MuseColor.hairline, lineWidth: 0.75) }
            }
            .accessibilityHidden(true)
    }
}
