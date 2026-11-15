import AppKit
import ApplicationServices
import Foundation

/// Puts words into whatever app is in front: onto the clipboard, then a ⌘V. Pressing keys in
/// another app needs Accessibility (System Settings › Privacy & Security › Accessibility).
/// Without it the words are still copied, ready to paste.
enum TextInserter {
    /// This app may press keys in other apps.
    static var canType: Bool { AXIsProcessTrusted() }

    /// A text field has the cursor in the app in front: something that takes typing, by its
    /// role or because its value can be set (web pages and editors report their own roles).
    static var isTypingSomewhere: Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = focused as! AXUIElement
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let role = role as? String, ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role) {
            return true
        }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
    }

    /// Shows macOS's Accessibility prompt (once; after that it points to System Settings).
    static func askToType() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Types `text` into the app in front, or leaves it on the clipboard when it can't.
    /// Returns true when it was typed.
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let board = NSPasteboard.general
        let earlier = board.string(forType: .string)
        board.clearContents()
        board.setString(text, forType: .string)
        guard canType else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Give the paste a beat to land, then put back what was on the clipboard.
        if let earlier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard board.string(forType: .string) == text else { return }
                board.clearContents()
                board.setString(earlier, forType: .string)
            }
        }
        return true
    }
}
