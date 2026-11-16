import AppKit
import SwiftUI

/// Opens the library from outside a view: a click on museo's dock icon, or a launch from the
/// dock or Finder. SwiftUI hands out `openWindow` only inside views, so the menu bar icon (the
/// one view that is always there) passes it in here when it appears.
@MainActor
enum LibraryOpener {
    private static var openWindow: OpenWindowAction?
    /// Asked for before the menu bar icon had appeared: opened as soon as it does.
    private static var waiting = false

    static func take(_ action: OpenWindowAction) {
        openWindow = action
        if waiting {
            waiting = false
            open()
        }
    }

    static func open() {
        guard let openWindow else {
            waiting = true
            return
        }
        openWindow(id: LibraryWindow.id)
        NSApp.activate()
    }

    /// True when this launch came from login items: museo then stays in the menu bar.
    static var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
