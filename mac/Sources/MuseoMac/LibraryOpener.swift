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

    /// The first run, asked for before the menu bar icon had appeared.
    private static var waitingToWelcome = false

    /// The first run's window.
    static func welcome() {
        guard let openWindow else {
            waitingToWelcome = true
            return
        }
        openWindow(id: WelcomeWindow.id)
        NSApp.activate()
    }

    static func take(_ action: OpenWindowAction) {
        openWindow = action
        if waitingToWelcome {
            waitingToWelcome = false
            welcome()
        }
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

    /// A new museo note in its own window, like ⌘N. Nothing happens before the menu bar
    /// icon has appeared, which is a moment after launch.
    static func newNote() {
        guard let openWindow else { return }
        openWindow(id: NoteWindow.id, value: UUID())
        NSApp.activate()
    }

    /// True when this launch came from login items: museo then stays in the menu bar.
    static var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
