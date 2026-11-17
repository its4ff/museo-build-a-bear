#if DEBUG
import AppKit
import MuseoKit
import SwiftUI

/// Draws the library window and the panel offscreen into pngs, for checking them against the
/// design without a ring or a screenshot: `museo -renderScreens /some/folder`.
enum ScreenSheet {
    static func write(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        MacLibrary.shared.loadForPreview()
        MacLibrary.shared.selection = MacLibrary.shared.muses.first(where: { !($0.words ?? "").isEmpty })?.id
        // The split view doesn't draw offscreen, so its two halves side by side.
        let library = MacLibrary.shared
        let open = library.muses.first { $0.id == library.selection }
        let halves = HStack(spacing: 0) {
            LibrarySidebar(muses: library.muses, query: .constant(""), filter: .constant(.all), selection: .constant(library.selection), picked: .constant([]))
                .still
                .frame(width: 310, height: 720, alignment: .top)
                .clipped()
            if let open { MusePane(muse: open).still }
        }
        // SwiftUI's own renderer: the AppKit snapshot comes back blank for these views.
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        let renderer = ImageRenderer(content: halves.frame(width: 1080, height: 720).environment(\.colorScheme, .light))
        renderer.scale = 2
        if let image = renderer.cgImage {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                .write(to: folder.appendingPathComponent("library.png"))
            print("[museo][mac] wrote library.png")
        }
        // Three picked with ⌘ click: the sidebar and the pane for many.
        let three = Set(library.muses.prefix(3).map(\.id))
        let picking = HStack(spacing: 0) {
            LibrarySidebar(muses: library.muses, query: .constant(""), filter: .constant(.all), selection: .constant(library.muses.first?.id), picked: .constant(three))
                .still
                .frame(width: 310)
            MusesPickedPane(ids: three).still
        }
        let pickedRenderer = ImageRenderer(content: picking.frame(width: 1080, height: 720).environment(\.colorScheme, .light))
        pickedRenderer.scale = 2
        if let image = pickedRenderer.cgImage {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                .write(to: folder.appendingPathComponent("picked.png"))
            print("[museo][mac] wrote picked.png")
        }
        // The sync row (s1) in its three states, on paper.
        var waiting = RingStatus.linked
        waiting.waiting = 1
        waiting.olderWaiting = 8
        waiting.waitingBytes = 1_900_000
        var bringing = RingStatus.linked
        bringing.isSyncing = true
        bringing.waiting = 7
        bringing.syncTotal = 9
        bringing.syncProgress = 0.4
        bringing.syncBytesLeft = 1_500_000
        let rows = VStack(spacing: MuseSpacing.md) {
            RingSyncRow(ring: waiting, actions: .preview) {}
            RingSyncRow(ring: bringing, actions: .preview) {}
        }
        .padding(MuseSpacing.md)
        .frame(width: 310)
        .background { MuseBackground() }
        save(rows, size: NSSize(width: 310, height: 190), as: "sync.png", in: folder)
        save(MenuPanel(), size: NSSize(width: 310, height: 900), as: "panel.png", in: folder)
        save(YourWordsPopover(), size: NSSize(width: 290, height: 230), as: "words.png", in: folder)
        save(LibrarySettingsPopover(), size: NSSize(width: 290, height: 150), as: "library-settings.png", in: folder)
        RingNames.shared.setNickname("naveed's ring", for: "Museo_test")
        let names = VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            RingNameField(ringName: "Museo_bd27", isEditing: .constant(false), showsPencil: true)
            RingNameField(ringName: "Museo_test", isEditing: .constant(false), showsPencil: true)
            RingNameField(ringName: "Museo_test", isEditing: .constant(true))
        }
        .padding(MuseSpacing.md)
        .frame(width: 310, alignment: .leading)
        .background { MuseBackground() }
        save(names, size: NSSize(width: 310, height: 130), as: "ring-name.png", in: folder)
        // The ring line's room: 16 characters beside the disconnect pill.
        for name in ["museo 10 is m", "naveed's ring", "the work ring"] {
            RingNames.shared.setNickname(name, for: "Museo_\(name.count)\(name.prefix(2))")
        }
        let fits = VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            ForEach(["museo 10 is m", "naveed's ring", "the work ring"], id: \.self) { name in
                HStack(spacing: MuseSpacing.sm) {
                    Circle().fill(MuseColor.moss).frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        RingNameField(ringName: "Museo_\(name.count)\(name.prefix(2))", isEditing: .constant(false), showsPencil: true)
                        Text("linked · 13%").font(MuseType.caption).foregroundStyle(MuseColor.ink55)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                    Capsule().strokeBorder(MuseColor.hairline).frame(width: 104, height: 26)
                }
            }
        }
        .padding(MuseSpacing.md)
        .frame(width: 310, alignment: .leading)
        .background { MuseBackground() }
        save(fits, size: NSSize(width: 310, height: 190), as: "ring-name-fits.png", in: folder)
        // Voice commands, two to a row, and with the pointer on "send".
        save(CommandsSection().padding(MuseSpacing.md).background { MuseBackground() }, size: NSSize(width: 310, height: 330), as: "commands.png", in: folder)
        save(CommandsSection(hovering: "open claude").padding(MuseSpacing.md).background { MuseBackground() }, size: NSSize(width: 310, height: 330), as: "commands-open.png", in: folder)
        save(CommandsSection(editing: "send").padding(MuseSpacing.md).background { MuseBackground() }, size: NSSize(width: 310, height: 470), as: "commands-edit.png", in: folder)
        save(CommandsSection(hovering: "send").padding(MuseSpacing.md).background { MuseBackground() }, size: NSSize(width: 310, height: 330), as: "commands-hover.png", in: folder)
        // A note on the eye line, an empty one, and naming it.
        let sample = "The ring is best when you forget it's there. You hold, you say the thing, you let go, and it's already on the page.\n\nHalfway down the hill I worked out the launch. Small rings of people first, the ones who already wear it, then their friends. Not a big day. A slow, warm week where every post is someone"
        save(NotePage(text: .constant(sample), isLookingBack: .constant(false)).background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note.png", in: folder)
        save(NotePage(text: .constant(sample), isLookingBack: .constant(true)).background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note-back.png", in: folder)
        save(NotePage(text: .constant(""), isLookingBack: .constant(false)).background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note-empty.png", in: folder)
        // Holding in a note: the words forming at the line, the island in the window; then landed.
        let holding = NotePage(text: .constant(sample), isLookingBack: .constant(false), previewForming: "and the island sits right at the top")
            .overlay(alignment: .top) { NoteIsland(preview: .some(nil)) }
            .background { MuseBackground() }
        save(holding, size: NSSize(width: 1080, height: 720), as: "note-holding.png", in: folder)
        // Let go: the last words soaking in, left to right. And what you can say in a note.
        save(NotePage(text: .constant(sample), isLookingBack: .constant(false), previewLanding: true).background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note-landing.png", in: folder)
        save(NoteShortcutList().background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note-shortcuts.png", in: folder)
        save(NoteIsland(preview: "in your note · 12 words").padding(20).background(MuseColor.ground), size: NSSize(width: 320, height: 80), as: "note-island-landed.png", in: folder)
        // The sidebar with notes in it, a note open.
        if let note = library.muses.first(where: \.isNote) {
            save(LibrarySidebar(muses: library.muses, query: .constant(""), filter: .constant(.all), selection: .constant(note.id), picked: .constant([])).still.frame(width: 310, height: 720, alignment: .top).clipped(), size: NSSize(width: 310, height: 720), as: "sidebar-notes.png", in: folder)
        }
        save(NoteNaming(id: UUID(), words: sample, back: {}, done: {}).background { MuseBackground() }, size: NSSize(width: 1080, height: 720), as: "note-name.png", in: folder)
        // Charging: the menu bar icon on a light and a dark bar, and the panel's ring.
        let charging = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(nsImage: DotRingIcon.image(for: .linked(typed: false)))
                Image(nsImage: DotRingIcon.image(for: .charging))
            }
            .padding(10).background(Color.white).environment(\.colorScheme, .light)
            HStack(spacing: 16) {
                Image(nsImage: DotRingIcon.image(for: .linked(typed: false)))
                Image(nsImage: DotRingIcon.image(for: .charging))
            }
            .padding(10).background(Color.black).environment(\.colorScheme, .dark)
            HStack(spacing: MuseSpacing.sm) {
                Image(nsImage: DotRingIcon.small(.charging, size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("museo 10 silver").font(MuseFont.lora(16)).foregroundStyle(MuseColor.ink)
                    Text("charging · 79%").font(MuseType.caption).foregroundStyle(MuseColor.ink55)
                }
            }
            .padding(12).background(MuseColor.ground)
        }
        .padding(12)
        save(charging, size: NSSize(width: 220, height: 190), as: "charging.png", in: folder)
        // Your stats beside the sidebar, the chart button on.
        CommandTally.shared.preview(["send": 142, "hey claude": 64, "scratch that": 38, "switch tab": 21, "new line": 9])
        library.showsStats = true
        for span in LibraryStats.Span.allCases {
            let stats = HStack(spacing: 0) {
                LibrarySidebar(muses: library.muses, query: .constant(""), filter: .constant(.all), selection: .constant(library.selection), picked: .constant([]))
                    .still
                    .frame(width: 310, height: 720, alignment: .top)
                    .clipped()
                StatsPane().still(span)
            }
            save(stats, size: NSSize(width: 1080, height: 720), as: "stats-\(span).png", in: folder)
        }
        library.showsStats = false
        NotchIsland.renderStates(to: folder)
    }

    private static func save(_ view: some View, size: NSSize, as name: String, in folder: URL) {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        // Scroll views draw only in a window that's ordered in: put it far off screen.
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        // Let SwiftUI settle (fonts, the waveform read, first layout passes).
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name))
        print("[museo][mac] wrote \(name)")
    }
}
#endif
