import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

/// Puts words where the cursor is: onto the clipboard, then a ⌘V into the text field that has
/// focus. Pressing keys in another app needs Accessibility (System Settings › Privacy &
/// Security › Accessibility). With no text field in focus, or without Accessibility, the words
/// are only copied, ready to paste.
enum TextInserter {
    /// This app may press keys in other apps.
    static var canType: Bool { AXIsProcessTrusted() }

    /// A text field has the cursor: something that takes typing, by its role or because its
    /// value can be set (web pages and editors report their own roles).
    static var isTypingSomewhere: Bool {
        focusedField() != nil
    }

    /// The app whose text field has the cursor, by name; nil when no text field does.
    ///
    /// Asked of the focused field itself, not of "the frontmost app": a click on the desktop
    /// or into a panel that never takes focus (Spotlight, Raycast, museo's own) leaves the
    /// last app frontmost while nothing there would take the paste.
    static var typingTarget: String? {
        guard canType, let field = focusedField() else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(field, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    /// Shows macOS's Accessibility prompt (once; after that it points to System Settings).
    static func askToType() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// What happened to the words: typed (and into which app, when that can be known), or
    /// only copied.
    nonisolated enum Landing: Equatable, Sendable {
        case typed(into: String?)
        case copied
    }

    /// Types `text` where the cursor is (a ⌘V), or leaves it on the clipboard when museo may
    /// not press keys.
    ///
    /// The paste never waits on finding the text field: Electron and Chromium apps (Claude,
    /// Slack, browsers) often don't show their fields to Accessibility. The app's name comes
    /// from the focused field when it can be read, and is left out when it can't, so it's
    /// never a guess.
    @discardableResult
    static func insert(_ text: String) -> Landing {
        let board = NSPasteboard.general
        let earlier = snapshot(board)
        copy(text)
        let ours = board.changeCount
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"

        guard canType else {
            print("[museo][paste] copied only: museo may not type (accessibility is off)")
            return .copied
        }
        // A password field, a password manager or a terminal's secure keyboard entry: macOS
        // drops keystrokes from other apps, so a ⌘V would vanish. Say "copied" instead.
        guard !IsSecureEventInputEnabled() else {
            print("[museo][paste] copied only: secure input is on (\(front) in front)")
            return .copied
        }
        let target = typingTarget
        pressCommandV()
        print("[museo][paste] ⌘V into \(target ?? front)\(target == nil ? " (field not readable)" : "")")

        // Put back what was on the clipboard once the paste has had time to land. Busy Electron
        // and Chromium apps read the clipboard late, so not too soon; and never over something
        // copied since (the change count moved on).
        if !earlier.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreAfter) {
                guard board.changeCount == ours else { return }
                board.clearContents()
                board.writeObjects(earlier)
            }
        }
        return .typed(into: target)
    }

    /// How long the words stay on the clipboard before the earlier contents come back.
    private static let restoreAfter: TimeInterval = 1.5

    /// ⌘V as a person types it: Command down, V down, V up, Command up. Some web and Electron
    /// apps ignore a V that only carries the Command flag. The events come from a private
    /// source, so a key the person is holding right now doesn't leak into them.
    private static func pressCommandV() {
        let source = CGEventSource(stateID: .privateState)
        let command = CGKeyCode(kVK_Command)
        let v = CGKeyCode(kVK_ANSI_V)
        let events = [
            CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: true),
            CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
            CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false),
            CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: false),
        ]
        for (index, event) in events.enumerated() {
            // Command is held for the first three; the last lets it go.
            event?.flags = index < 3 ? .maskCommand : []
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Presses `key` with `modifiers` held, the way a person does: each modifier down, the key
    /// down and up, the modifiers up in reverse. False when museo may not press keys, or
    /// secure input would swallow them.
    @discardableResult
    static func press(_ key: CGKeyCode, holding modifiers: [CGKeyCode] = []) -> Bool {
        guard canType, !IsSecureEventInputEnabled() else { return false }
        let source = CGEventSource(stateID: .privateState)
        let flag: [CGKeyCode: CGEventFlags] = [
            CGKeyCode(kVK_Command): .maskCommand,
            CGKeyCode(kVK_Shift): .maskShift,
            CGKeyCode(kVK_Option): .maskAlternate,
            CGKeyCode(kVK_Control): .maskControl,
        ]
        var held: CGEventFlags = []
        func post(_ code: CGKeyCode, down: Bool) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = held
            event?.post(tap: .cghidEventTap)
        }
        for modifier in modifiers {
            held.insert(flag[modifier] ?? [])
            post(modifier, down: true)
        }
        post(key, down: true)
        post(key, down: false)
        for modifier in modifiers.reversed() {
            held.remove(flag[modifier] ?? [])
            post(modifier, down: false)
        }
        return true
    }

    /// Everything on the clipboard (text, images, files), to put back after the paste.
    private static func snapshot(_ board: NSPasteboard) -> [NSPasteboardItem] {
        (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    /// The words on the clipboard, nothing more.
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// The focused element, when it takes typing.
    private static func focusedField() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let role = role as? String, ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role) {
            return element
        }
        var settable: DarwinBoolean = false
        let editable = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
        return editable ? element : nil
    }
}
