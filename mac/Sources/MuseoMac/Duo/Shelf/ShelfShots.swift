#if DEBUG
import SwiftUI

/// The shelf team's shots: the iphone's shell B grown up for a mac window.
enum ShelfShots {
    static var all: [DuoShot] {
        [
            DuoShot("shelf-yours") { ShelfYours() },
            DuoShot("shelf-thought") { ShelfThought() },
            DuoShot("shelf-places") { ShelfPlaces() },
            DuoShot("shelf-fm") { ShelfFM() },
        ]
    }
}
#endif
