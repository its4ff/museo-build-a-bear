import AppKit
import SwiftUI

/// The menu bar panel's window, from outside SwiftUI.
enum MenuPanelWindow {
    /// The panel's window, once it has opened (`PanelWindowReader` keeps it).
    fileprivate(set) static weak var window: NSWindow?

    /// Closes the panel if it's open, and steps museo aside so the app you were in has the
    /// focus again. A hold types where the cursor is; with the panel open, that was museo.
    static func closeIfOpen() {
        guard let window, window.isVisible else { return }
        window.close()
        // The library may be what you're working in; then museo stays in front.
        if NSApp.isActive, !(NSApp.keyWindow?.isVisible ?? false) {
            NSApp.deactivate()
        }
        print("[museo][mac] closed the panel for a hold")
    }
}

/// Finds the window the panel is drawn in, for `MenuPanelWindow`.
struct PanelWindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            MenuPanelWindow.window = view.window
            // The panel is paper: its fields and switches draw light even on a dark mac.
            view.window?.appearance = NSAppearance(named: .aqua)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if let window = view.window { MenuPanelWindow.window = window }
    }
}
