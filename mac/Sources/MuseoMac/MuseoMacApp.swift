import AppKit
import MuseoKit
import SwiftUI

/// museo for mac. The menu bar is the fast path: hold the ring and talk, and when you let go
/// the words are typed into the app in front, with the flow bar showing them as they form.
/// The glass panel holds the ring, the switch and the last few muses; the library window
/// keeps every muse, in museo's own paper and type.
@main
struct MuseoMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Lora and Satoshi before the first view draws (scripts/mac.sh copies them in).
        FontRegistrar.registerBundledFonts()
        MuseGrain.warm()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
        } label: {
            MenuIcon()
        }
        .menuBarExtraStyle(.window)

        Window("museo", id: LibraryWindow.id) {
            LibraryWindow()
        }
        .defaultSize(width: 980, height: 680)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Line by line, so `scripts/mac.sh log` shows the ring's log as it happens.
        setvbuf(stdout, nil, _IOLBF, 0)
        #if DEBUG
        if let folder = UserDefaults.standard.string(forKey: "renderIcons") {
            IconSheet.write(to: URL(fileURLWithPath: folder))
            exit(0)
        }
        #endif
        // Once, before anything reads the ring.
        Museo.start(name: "museo")
        MacLibrary.shared.start()
        Dictation.shared.start()
        RingWatch.shared.start()
        HotKeys.start()
        Task { await MacSpeech.prepare() }
        // Each hold's pill starts and ends at rest.
        Museo.onEvent { event in
            switch event {
            case .liveStarted, .liveEnded: MenuVoice.shared.reset()
            default: break
            }
        }
        // Memory recordings come over by themselves, so a fresh one can land where you are.
        // (The first experiment turned this off; turn it back on once.)
        if !UserDefaults.standard.bool(forKey: Self.didTurnOnAutoSync) {
            RingActions.live(openFirmware: {}).setAutoSync(true)
            UserDefaults.standard.set(true, forKey: Self.didTurnOnAutoSync)
        }
    }

    /// Closing the library leaves museo in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private static let didTurnOnAutoSync = "museo.mac.didTurnOnAutoSync"
}
