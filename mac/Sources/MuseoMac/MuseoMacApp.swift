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
        .defaultSize(width: 1080, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands { NoteCommands() }

        // The first run: four pages, once.
        Window("welcome", id: WelcomeWindow.id) {
            WelcomeWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // A museo note, the library's size. Opened by the plus, ⌘N, or a note in the library.
        WindowGroup("note", id: NoteWindow.id, for: UUID.self) { $id in
            NoteWindow(id: id)
        } defaultValue: {
            UUID()
        }
        .defaultSize(width: 1080, height: 720)
        .windowStyle(.hiddenTitleBar)
        .restorationBehavior(.disabled)
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
        if let kind = UserDefaults.standard.string(forKey: "speechCheck").flatMap(LocalSpeech.Kind.init(rawValue:)) {
            Task {
                await SpeechCheck.run(kind)
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderCommandOptions") {
            CommandsOptions.write(to: URL(fileURLWithPath: folder))
            exit(0)
        }
        if let folder = UserDefaults.standard.string(forKey: "renderReadme") {
            ReadmeShots.write(to: URL(fileURLWithPath: folder))
            exit(0)
        }
        if let folder = UserDefaults.standard.string(forKey: "renderScreens") {
            ScreenSheet.write(to: URL(fileURLWithPath: folder))
            exit(0)
        }
        if UserDefaults.standard.bool(forKey: "edgeCheck") {
            EdgeCheck.run()
            exit(0)
        }
        if let folder = UserDefaults.standard.string(forKey: "renderDuo") {
            DuoShots.write(to: URL(fileURLWithPath: folder), only: UserDefaults.standard.string(forKey: "duoOnly"))
            exit(0)
        }
        #endif
        // Once, before anything reads the ring. Newest recordings come over first, so a
        // fresh one can land where you are while older ones follow. And only recordings
        // made after this mac first saw the ring: the ones before are the iphone's, and
        // stay on the ring (the panel's ring menu brings them in when asked).
        let ring = Museo.start(name: "museo")
        ring.syncsNewestFirst = true
        ring.bringsInOnlyNewRecordings = true
        MacLibrary.shared.start()
        Dictation.shared.start()
        RingWatch.shared.start()
        NotchIsland.shared.start()
        HotKeys.start()
        Task { await MacSpeech.prepare() }
        // Each hold's pill starts and ends at rest.
        Museo.onEvent { event in
            switch event {
            case .liveStarted:
                MenuVoice.shared.reset()
            case .liveEnded:
                MenuVoice.shared.reset()
            default: break
            }
        }
        // Nothing comes over by itself on a mac: a transfer ties up the ring, and on a mac's
        // slow link a hold would wait behind it. The panel's row brings recordings in when
        // you click, and the iphone keeps bringing them in on its own.
        RingActions.live(openFirmware: {}).setAutoSync(false)
        // Opened from the dock or Finder: the library, like any app. From login items, or
        // relaunched by scripts/mac.sh (-quietLaunch): just the menu bar.
        // The very first time on this mac: the first run, however museo was opened.
        if !WelcomeWindow.isDone {
            LibraryOpener.welcome()
        } else if !LibraryOpener.launchedAtLogin, !UserDefaults.standard.bool(forKey: "quietLaunch") {
            LibraryOpener.open()
        }
    }

    /// A click on museo's dock icon opens the library, or brings it forward. (The notch island
    /// is always a visible window, so `hasVisibleWindows` says nothing here.)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        LibraryOpener.open()
        return false
    }

    /// Closing the library leaves museo in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
