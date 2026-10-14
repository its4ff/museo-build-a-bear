import SwiftUI

/// The charging case, as the booklet draws it. `.open`: the lid up, the base where the ring
/// sits, the case's own light (green: charged). `.closed`: from above, the ring inside, its
/// light amber while it charges. The cheat card uses both. Decorative.
struct MuseCaseArt: View {
    nonisolated enum Pose: Sendable {
        case open
        case closed
    }

    var pose: Pose = .closed
    var width: CGFloat = 96

    /// Each drawing's width over its height, so its size never depends on the room offered.
    private var aspect: CGFloat { pose == .open ? 373.0 / 720.0 : 400.0 / 396.0 }

    var body: some View {
        Image(pose == .open ? "BookletCaseOpen" : "BookletCaseClosed")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: width / aspect)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: MuseSpacing.section) {
        MuseCaseArt(pose: .open)
        MuseCaseArt(pose: .closed)
    }
    .padding(MuseSpacing.page)
    .background { MuseBackground() }
}
