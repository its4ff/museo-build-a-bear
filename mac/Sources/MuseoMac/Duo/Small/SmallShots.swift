#if DEBUG
import SwiftUI

/// The small team's shots: the menu bar panel, the notch island, the note and "your words".
enum SmallShots {
    static var all: [DuoShot] {
        [
            DuoShot("small-panel", size: CGSize(width: SmallMetrics.panelWidth + SmallMetrics.panelDesk * 2, height: SmallMetrics.panelHeight)) {
                SmallPanelShot()
            },
            DuoShot("small-island", size: SmallMetrics.islandShot) { SmallIslandShot() },
            DuoShot("small-note", size: SmallMetrics.noteShot) { SmallNote() },
            DuoShot("small-words") { SmallWords() },
        ]
    }
}
#endif
