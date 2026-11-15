#if DEBUG
import AppKit

/// Draws every menu bar state, light and dark, at 1× and 4×, into one png, for checking the
/// icon without a ring: `museo -renderIcons /some/folder`.
enum IconSheet {
    static func write(to folder: URL) {
        let states: [(String, DotRingIcon.State)] = [
            ("not linked", .faint),
            ("linked", .linked(typed: false, waiting: false)),
            ("holding", .holding([0.2, 0.6, 0.35, 0.9, 0.4])),
            ("typed", .linked(typed: true, waiting: false)),
            ("recording", .recording(42)),
            ("bringing in", .syncing(0.64)),
            ("waiting", .linked(typed: false, waiting: true)),
        ]
        let row: CGFloat = 96
        let size = NSSize(width: 760, height: row * CGFloat(states.count))
        let sheet = NSImage(size: size, flipped: true) { _ in
            for (index, entry) in states.enumerated() {
                let y = CGFloat(index) * row
                for (column, dark) in [false, true].enumerated() {
                    let x = CGFloat(column) * 380
                    (dark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.9, alpha: 1)).setFill()
                    NSRect(x: x, y: y, width: 380, height: row).fill()
                    NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
                        let icon = DotRingIcon.image(for: entry.1)
                        let tinted = icon.isTemplate ? tint(icon, dark ? .white : .black) : icon
                        tinted.draw(in: NSRect(x: x + 24, y: y + 39, width: icon.size.width, height: icon.size.height))
                        tinted.draw(in: NSRect(x: x + 90, y: y + 12, width: icon.size.width * 4, height: icon.size.height * 4))
                    }
                    (entry.0 as NSString).draw(at: NSPoint(x: x + 260, y: y + 40), withAttributes: [.foregroundColor: dark ? NSColor.white : NSColor.black])
                }
            }
            return true
        }
        guard let tiff = sheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? png.write(to: folder.appendingPathComponent("menu-bar-icons.png"))
        print("[museo][mac] wrote menu-bar-icons.png")
    }

    /// A template image in the menu bar's ink.
    private static func tint(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
#endif
