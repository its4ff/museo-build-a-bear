import SwiftUI
import WidgetKit

@main
struct MuseoBuildWidgetBundle: WidgetBundle {
    var body: some Widget {
        MuseCaptureLiveActivity()
        MuseSyncLiveActivity()
    }
}
