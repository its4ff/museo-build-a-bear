import Carbon.HIToolbox
import Foundation

/// ⌥⌘V, from any app: paste the newest muse where you are. A system hot key, so it works
/// without museo in front and needs no extra permission.
enum HotKeys {
    private static var pasteNewest: EventHotKeyRef?

    static func start() {
        guard pasteNewest == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Hot keys arrive on the main thread.
            MainActor.assumeIsolated { MacLibrary.shared.pasteNewest() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4D55_534F), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &pasteNewest)
    }
}
