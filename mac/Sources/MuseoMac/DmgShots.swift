#if DEBUG
import SwiftUI

/// The picture behind the dmg's window: `MuseoMac -renderDuo <folder> -duoOnly dmg`.
/// `scripts/mac-dmg.sh` lays the two icons over it (museo at 190, applications at 470, both
/// 170 down) and keeps the result in mac/Resources-dmg/. A mid moss, on purpose: Finder
/// writes the icons' names in white on a dark mac and black on a light one, and both have
/// to read.
enum DmgShots {
    static let window = CGSize(width: 660, height: 400)

    static var all: [DuoShot] {
        [DuoShot("dmg-background", size: window) { background }]
    }

    private static var background: some View {
        ZStack {
            MuseColor.moss300.mix(with: MuseColor.moss600, by: 0.55)
            RadialGradient(colors: [MuseColor.mossTint.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [MuseColor.moss900.opacity(0.35), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460)
            MuseGrainOverlay(opacity: 0.5)
            // Between the two icons.
            Image(systemName: "arrow.right")
                .font(MuseFont.symbol(22, weight: .light))
                .foregroundStyle(MuseColor.composer.opacity(0.8))
                .position(x: 330, y: 166)
            Text("drag museo into applications")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.composer.opacity(0.85))
                .position(x: 330, y: 318)
        }
        .frame(width: window.width, height: window.height)
    }
}
#endif
