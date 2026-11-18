#if DEBUG
import AppKit
import MuseoKit
import SwiftUI

/// The real small surfaces, drawn from made-up muses: the menu bar panel, the notch island
/// and "your words". Listed in `DuoShots.all`: `MuseoMac -renderDuo <folder> -duoOnly live`.
enum PanelShots {
    static var all: [DuoShot] {
        prepare()
        // The ring line's two plainer ways, for choosing: `-panelRing line` or `quietLine`.
        if let style = UserDefaults.standard.string(forKey: "panelRing") {
            MenuPanel.ringLineStyle = style == "line" ? .line : .quietLine
            return [DuoShot("live-panel-\(style)", size: CGSize(width: PanelMetrics.width + desk * 2, height: 760)) {
                onDesk { MenuPanel() }
            }]
        }
        return [
            DuoShot("live-panel", size: CGSize(width: PanelMetrics.width + desk * 2, height: 760)) {
                onDesk { MenuPanel() }
            },
            DuoShot("live-panel-ring", size: CGSize(width: PanelMetrics.width + desk * 2, height: 620)) {
                onDesk {
                    VStack(spacing: MuseSpacing.sm) {
                        ForEach(Array(rings.enumerated()), id: \.offset) { _, ring in
                            ringLine(ring)
                        }
                        RingSyncRow(ring: waiting, actions: .preview) {}
                        RingSyncRow(ring: bringing, actions: .preview) {}
                    }
                    .padding(MuseSpacing.md)
                    .frame(width: PanelMetrics.width)
                    .background { PanelGround() }
                }
            },
            DuoShot("live-panel-commands", size: CGSize(width: PanelMetrics.width + desk * 2, height: 760)) {
                onDesk {
                    VStack(spacing: MuseSpacing.lg) {
                        CommandsSection(hovering: "send")
                        CommandsSection(editing: "send")
                    }
                    .padding(MuseSpacing.md)
                    .frame(width: PanelMetrics.width)
                    .background { PanelGround() }
                }
            },
            DuoShot("live-panel-words", size: CGSize(width: 290 + desk * 2, height: 300)) {
                onDesk { YourWordsPopover() }
            },
            DuoShot("live-island", size: CGSize(width: 900, height: 700)) {
                VStack(spacing: 0) {
                    band { $0.listen() }
                    band {
                        $0.listen()
                        $0.update(HoldSpeech.Words(heard: "for claude, book the dentist", hearing: "thursday"))
                    }
                    band {
                        $0.listen()
                        $0.update(HoldSpeech.Words(heard: "Hey Claude, book the dentist thursday", hearing: ""))
                    }
                    band {
                        $0.listen()
                        $0.finish(note: "typed into Claude")
                    }
                    band {
                        $0.listen()
                        $0.update(HoldSpeech.Words(heard: "Switch tab.", hearing: ""))
                        $0.finish(note: nil, ran: VoiceCommands.shared.read("Switch tab."))
                    }
                }
                .background { desktop }
                .preferredColorScheme(.light)
            },
            DuoShot("live-words") {
                StatsPane().still(.all)
                    .preferredColorScheme(.light)
            },
        ]
    }

    // MARK: - Made-up things

    private static func prepare() {
        MacLibrary.shared.useSamples(samples)
        CommandTally.shared.preview(["send": 142, "hey claude": 64, "scratch that": 38, "switch tab": 21, "new line": 9])
        YourWords.shared.preview(["museo", "Claude", "Voz", "Lisbon", "Haseab"])
        var ring = RingStatus.linked
        ring.battery = 82
        ring.advertisedName = "Museo_bd27"
        MenuPanel.previewRing = ring
    }

    private static var samples: [MacMuse] {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            MacMuse(id: UUID(), createdAt: ago(4), duration: 8, origin: "streamed", audioFile: "",
                    words: "rings floating in the window, just hung on thread so they turn", model: "parakeet", typedInto: "Notes"),
            MacMuse(id: UUID(), createdAt: ago(28), duration: 6, origin: "streamed", audioFile: "",
                    words: "for claude, book the dentist thursday", model: "parakeet", typedInto: "Claude", wasSent: true),
            MacMuse(id: UUID(), createdAt: ago(95), duration: 19, origin: "streamed", audioFile: "",
                    words: "Three things before Friday: the price card, the window photos, and a note to the shop about the thread. The window is slow on thursday, so the shop can wait.",
                    model: "parakeet", typedInto: "Notes"),
            MacMuse(id: UUID(), createdAt: ago(60 * 20), duration: 312, origin: "memory", audioFile: "",
                    words: "Walking back from the coffee place. The window should be slow, one thread at a time, and the shop stays quiet behind it.",
                    model: "parakeet", unseen: true),
        ]
    }

    /// The ring's line in each state it can be in.
    private static var rings: [RingStatus] {
        var charging = RingStatus.linked
        charging.battery = 64
        charging.isCharging = true
        charging.advertisedName = "Museo_bd27"
        var recording = RingStatus.linked
        recording.battery = 82
        recording.isRecordingOnRing = true
        recording.advertisedName = "Museo_bd27"
        var away = RingStatus.linked
        away.link = .away
        away.advertisedName = "Museo_bd27"
        var joining = away
        joining.link = .joining
        var none = away
        none.link = .notSetUp
        none.advertisedName = nil
        return [charging, recording, away, joining, none]
    }

    private static var waiting: RingStatus {
        var ring = RingStatus.linked
        ring.waiting = 3
        ring.waitingBytes = 1_400_000
        return ring
    }

    private static var bringing: RingStatus {
        var ring = waiting
        ring.isSyncing = true
        ring.syncTotal = 3
        ring.waiting = 2
        ring.syncProgress = 0.4
        ring.syncBytesLeft = 900_000
        return ring
    }

    /// The pill as the panel draws it, without the panel's own reads of the ring.
    private static func ringLine(_ ring: RingStatus) -> some View {
        let state = PocketRingState(ring)
        let detail: String? = switch ring.link {
        case .linked: ring.isRecordingOnRing ? "recording · 0:42" : ring.battery.map { "\($0)%" }
        case .joining: "joining…"
        case .away: "away"
        case .bluetoothOff: "bluetooth is off"
        case .notSetUp: nil
        }
        return PanelRingPill(state: state, ringName: ring.advertisedName, detail: detail, isRenaming: .constant(false))
    }

    // MARK: - The desk

    private static let desk: CGFloat = 22
    private static let menuBar: CGFloat = 32
    private static let deskTop = MuseColor.shelf.mix(with: MuseColor.ink55, by: 0.2)
    private static let deskFoot = MuseColor.shelf.mix(with: MuseColor.ink55, by: 0.34)

    private static var desktop: some View {
        LinearGradient(colors: [deskTop, deskFoot], startPoint: .top, endPoint: .bottom)
    }

    /// A panel as it hangs under the menu bar: rounded, lifted, on a neutral wallpaper.
    private static func onDesk(@ViewBuilder _ content: () -> some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: MuseRadius.card, style: .continuous)
        return content()
            .clipShape(shape)
            .overlay { shape.strokeBorder(DuoColor.edge, lineWidth: 1) }
            .compositingGroup()
            .museElevation(.e2)
            .padding(.top, desk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { desktop }
            .preferredColorScheme(.light)
    }

    /// One island moment under its own slice of dark menu bar.
    private static func band(_ prepare: @escaping (MenuIsland) -> Void) -> some View {
        ZStack(alignment: .top) {
            MuseColor.moss900.mix(with: .black, by: 0.55).opacity(0.86)
                .frame(height: menuBar)
            NotchIsland.preview(prepare)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}
#endif
