#if DEBUG
import SwiftUI

/// The lines Room and Page both say, written once so the two mac first windows read as
/// one family: what stays, and the keys in the action capsule's own order.
nonisolated enum DuoWords {
    static let kept = "kept on this mac"
    /// Copy, save, send to, delete: the capsule's order.
    static let thoughtKeys = "⌘C copy · ⌘S save · ⌘K send to… · ⌘⌫ delete"
    static let placeKeys = "⌘N new place · ⌘↩ send now · ⌘⌫ delete"
    static let fmKeys = "⌘C copy · ⌘S save · space listen"

    /// Under someone else's thought. No name, only where.
    static func given(in city: String) -> String {
        "someone in \(city) gave this to museo.fm"
    }
}

/// The quiet word beside a send that failed. Moss, because it is a way forward.
struct DuoSendAgain: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text("send again")
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss600)
                .fixedSize()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
