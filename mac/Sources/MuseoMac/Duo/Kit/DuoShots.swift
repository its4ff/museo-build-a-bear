#if DEBUG
import AppKit
import SwiftUI

/// One picture the duo harness draws: an id (`room-yours`, which is also the file's name),
/// a size in points, and a view.
struct DuoShot {
    let id: String
    let size: CGSize
    let view: AnyView

    init(_ id: String, size: CGSize = DuoMetrics.window, @ViewBuilder view: () -> some View) {
        self.id = id
        self.size = size
        self.view = AnyView(view())
    }
}

/// Draws the duo screens into pngs at 2x: `MuseoMac -renderDuo /some/folder`, and
/// `-duoOnly room` for only the ids that start with "room". Each team lists its shots in
/// its own file (`RoomShots.all`, …); this only gathers them.
enum DuoShots {
    static var all: [DuoShot] {
        // The real library's pictures set up the one shared library: nothing else may touch it.
        if UserDefaults.standard.string(forKey: "libraryShot") != nil { return LibraryShots.all }
        if UserDefaults.standard.bool(forKey: "postShot") { return PostShots.all }
        if UserDefaults.standard.string(forKey: "duoOnly") == "welcome" { return WelcomeShots.all }
        return KitShots.all + RoomShots.all + ShelfShots.all + PageShots.all + SmallShots.all + LibraryShots.all + PanelShots.all + WelcomeShots.all
    }

    static func write(to folder: URL, only prefix: String? = nil) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shots = all.filter { shot in
            guard let prefix, !prefix.isEmpty else { return true }
            return shot.id.hasPrefix(prefix)
        }
        if shots.isEmpty {
            print("[museo][duo] no shots" + (prefix.map { " for \($0)" } ?? ""))
        }
        // A few windows at a time share one settle, so a team's four screens take one wait.
        var start = 0
        while start < shots.count {
            let batch = Array(shots[start..<min(start + batchSize, shots.count)])
            let windows = batch.map(open)
            RunLoop.main.run(until: Date().addingTimeInterval(settle))
            for (shot, window) in zip(batch, windows) {
                save(window, as: shot.id, in: folder)
                window.orderOut(nil)
            }
            start += batchSize
        }
    }

    private static let batchSize = 6
    private static let scale: CGFloat = 2
    private static let retries = 4
    /// Long enough for glass to resolve and the pill's amber to sweep in.
    private static let settle: TimeInterval = 2

    /// A borderless window far off every screen, ordered in so it is composited.
    private static func open(_ shot: DuoShot) -> NSWindow {
        let size = NSSize(width: shot.size.width, height: shot.size.height)
        let host = NSHostingView(rootView: shot.view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        return window
    }

    private static func save(_ window: NSWindow, as id: String, in folder: URL) {
        // Now and then the window server hands back a blank picture at another scale (the
        // display was busy). The right one is exactly 2x; ask again until it is.
        let wanted = Int(window.frame.width * scale)
        var image = windowImage(window)
        var tries = 0
        while image?.width != wanted, tries < retries {
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            image = windowImage(window)
            tries += 1
        }
        guard let image else {
            print("[museo][duo] no picture for \(id)")
            return
        }
        if image.width != wanted {
            print("[museo][duo] \(id) came back at the wrong scale: render it again")
        }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
            .write(to: folder.appendingPathComponent(id + ".png"))
        print("[museo][duo] wrote \(id).png · \(image.width)×\(image.height)")
    }

    /// One of museo's own windows, as the window server composites it, so Liquid Glass and
    /// materials are in it (`cacheDisplay` and `ImageRenderer` both drop glass). The call
    /// is hidden from Swift in this SDK (ScreenCaptureKit replaces it), so it's looked up
    /// by name. A DEBUG render tool only.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let capture = unsafeBitCast(symbol, to: Capture.self)
        // .optionIncludingWindow (8), then .boundsIgnoreFraming (1) | .bestResolution (8).
        return capture(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue()
    }
}
#endif
