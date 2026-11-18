#if DEBUG
import SwiftUI

/// The page team's shots: one sheet of paper on the dune with a margin of thoughts.
enum PageShots {
    static var all: [DuoShot] {
        [
            DuoShot("page-yours") { yours(mark: .moss) },
            DuoShot("page-yours-rule") { yours(mark: .rule) },
            DuoShot("page-thought") {
                PageSheet {
                    PageThoughtMargin(open: PocketFixtures.dentist.id)
                } page: {
                    PageThoughtLeaf(thought: PocketFixtures.dentist)
                }
            },
            DuoShot("page-places") {
                PageSheet {
                    PagePlacesMargin(open: PocketFixtures.claude.id)
                } page: {
                    PagePlaceLeaf(place: PocketFixtures.claude)
                }
            },
            DuoShot("page-fm") {
                PageSheet {
                    PageFMMargin(open: PocketFixtures.fmThoughts[0].id)
                } page: {
                    PageFMLeaf(thought: PocketFixtures.fmThoughts[0])
                }
            },
            DuoShot("page-palette") {
                PageSheet {
                    PageThoughtMargin(open: PocketFixtures.window.id)
                } page: {
                    // The capsule has faded: the pointer is not on it while the palette is open.
                    PageThoughtLeaf(thought: PocketFixtures.window, showsActions: false)
                }
                .pagePalette()
            },
        ]
    }

    private static func yours(mark: PageMark) -> some View {
        PageSheet {
            PageThoughtMargin(open: PocketFixtures.window.id, mark: mark)
        } page: {
            PageThoughtLeaf(thought: PocketFixtures.window)
        }
    }
}
#endif
