#if DEBUG
import AppKit
import MuseoKit
import SwiftUI

/// The README's pictures of museo for mac, drawn offscreen from made-up muses, so nobody's
/// own words end up in a public repo: `museo -renderReadme docs/images/mac`.
enum ReadmeShots {
    static func write(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let library = MacLibrary.shared
        library.useSamples(samples)
        CommandTally.shared.preview(["send": 142, "hey claude": 64, "scratch that": 38, "switch tab": 21, "new line": 9])

        // The menu bar panel, a linked ring.
        var ring = RingStatus.linked
        ring.battery = 82
        MenuPanel.previewRing = ring
        fitted(MenuPanel(), width: 310, as: "panel.png", in: folder)

        // The library: the sidebar beside one muse, and beside your stats.
        let open = samples[1]
        // The muse page only draws through SwiftUI's renderer, and the sidebar's search field
        // only through a window: each half its own way, side by side.
        if let side = image(sidebar(selection: open.id), size: NSSize(width: 310, height: 720)),
           let page = swiftUIImage(MusePane(muse: open).still.frame(width: 770, height: 720)) {
            png(beside(side, page), as: "library.png", in: folder)
        }
        library.showsStats = true
        render(HStack(spacing: 0) {
            sidebar(selection: nil)
            StatsPane().still(.week)
        }, as: "stats.png", in: folder)
        library.showsStats = false

        // A museo note: the words forming at the line while you hold, the island in the window.
        let note = NotePage(text: .constant(noteWords), isLookingBack: .constant(false), previewForming: "and every post is someone who already wears it")
            .overlay(alignment: .top) { NoteIsland(preview: .some(nil)) }
            .background { MuseBackground() }
        fixed(note, size: NSSize(width: 1080, height: 720), as: "note.png", in: folder)

        // The island under the notch: words forming, a prompt for Claude, typed.
        if let image = NotchIsland.readmeImage() {
            png(image, as: "island.png", in: folder)
        }
    }

    // MARK: - Made-up muses

    private static let noteWords = "The ring is best when you forget it's there. You hold, you say the thing, you let go, and it's already on the page.\n\nHalfway down the hill I worked out the launch. Small rings of people first, then their friends. Not a big day. A slow, warm week"

    private static var samples: [MacMuse] {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            MacMuse(id: UUID(), createdAt: ago(4), duration: 6, origin: "streamed", audioFile: "",
                    words: "Can you move the standup to 10 tomorrow and tell the team?", model: "parakeet", typedInto: "Slack", wasSent: true),
            MacMuse(id: UUID(), createdAt: ago(12), duration: 41, origin: "streamed", audioFile: "",
                    words: "Hey Claude, I want the library to feel like a shelf of notebooks. Sort it by day, keep the titles in Lora, and let me search everything I've said. Start with the sidebar, then we'll do the page for one muse.",
                    model: "parakeet", typedInto: "Claude", wasSent: true),
            MacMuse(id: UUID(), createdAt: ago(38), duration: 0, origin: "note", audioFile: "",
                    words: noteWords, model: nil, name: "the launch, slow and warm", nameIsTheirs: false),
            MacMuse(id: UUID(), createdAt: ago(95), duration: 19, origin: "streamed", audioFile: "",
                    words: "Three things before Friday: the price card, the case photos, and a note to the factory about the clasp.",
                    model: "parakeet", typedInto: "Notes"),
            MacMuse(id: UUID(), createdAt: ago(60 * 20), duration: 312, origin: "memory", audioFile: "",
                    words: "Walking back from the coffee place. The thing I keep coming back to is that the ring should never ask for attention. It listens when you hold it and stays quiet when you don't.",
                    model: "parakeet", unseen: true),
            MacMuse(id: UUID(), createdAt: ago(60 * 22), duration: 9, origin: "streamed", audioFile: "",
                    words: "Book the table for four at seven thirty.", model: "parakeet", typedInto: "Messages"),
            MacMuse(id: UUID(), createdAt: ago(60 * 23), duration: 27, origin: "streamed", audioFile: "",
                    words: "Hey Cursor, rename the sync row to bring in and keep the count beside it.",
                    model: "parakeet", typedInto: "Cursor", wasSent: true),
        ]
    }

    // MARK: - Drawing

    private static func sidebar(selection: UUID?) -> some View {
        LibrarySidebar(muses: MacLibrary.shared.muses, query: .constant(""), filter: .constant(.all), selection: .constant(selection), picked: .constant([]))
            .still
            .frame(width: 310, height: 720, alignment: .top)
            .clipped()
    }

    /// A library window: the sidebar and its page, 1080 by 720.
    private static func render(_ view: some View, as name: String, in folder: URL) {
        fixed(view, size: NSSize(width: 1080, height: 720), as: name, in: folder)
    }

    /// A view at its own height, for the panel.
    private static func fitted(_ view: some View, width: CGFloat, as name: String, in folder: URL) {
        let probe = NSHostingView(rootView: view.frame(width: width))
        let height = probe.fittingSize.height
        fixed(view, size: NSSize(width: width, height: height), as: name, in: folder)
    }

    /// Through a window far off screen: scroll and text views draw only in one.
    private static func fixed(_ view: some View, size: NSSize, as name: String, in folder: URL) {
        if let image = image(view, size: size) { png(image, as: name, in: folder) }
    }

    private static func image(_ view: some View, size: NSSize) -> CGImage? {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        host.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil) }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap.cgImage
    }

    private static func swiftUIImage(_ view: some View) -> CGImage? {
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        return renderer.cgImage
    }

    private static func beside(_ left: CGImage, _ right: CGImage) -> CGImage {
        let height = max(left.height, right.height)
        let context = CGContext(data: nil, width: left.width + right.width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(left, in: CGRect(x: 0, y: height - left.height, width: left.width, height: left.height))
        context.draw(right, in: CGRect(x: left.width, y: height - right.height, width: right.width, height: right.height))
        return context.makeImage()!
    }

    private static func png(_ image: CGImage, as name: String, in folder: URL) {
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
            .write(to: folder.appendingPathComponent(name))
        print("[museo][mac] wrote \(name)")
    }
}
#endif
