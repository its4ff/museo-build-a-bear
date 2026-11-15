import SwiftUI

/// No muse open: the orb and two lines.
struct LibraryEmpty: View {
    let hasMuses: Bool

    var body: some View {
        VStack(spacing: MuseSpacing.md) {
            MuseOrb(size: MuseOrb.Size.voice)
            Text(hasMuses ? "pick a muse on the left." : "nothing here yet.")
                .font(MuseType.headline)
                .foregroundStyle(MuseColor.ink)
            Text("hold the ring and talk. it lands here.")
                .font(MuseType.serif)
                .foregroundStyle(MuseColor.ink70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { MuseBackground() }
    }
}
