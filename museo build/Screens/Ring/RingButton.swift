import SwiftUI
import MuseoKit

// The one ring icon: battery, link and sync in a single glyph, top right of the home.
// A tap always opens the ring sheet.
//
//   RingButton(status: ring.status, style: AppConfig.ringButtonStyle) { router.open(.ring) }
//
// It reads only `RingStatus` (never `Museo.manager`), so it redraws when something on
// screen would change, not for every packet while a muse streams in.
//
// The glyph is the ring seen from above: a closed band with its stone at 12 o'clock, a
// faint track all the way round, and the battery running clockwise from the stone.
// How a status reads (the same rules as `MuseRingGlyph`):
//   linked        moss band and stone, the band's length is the battery
//   away, joining the last reading at half strength, a grey stone
//   not set up    dashed outline, hollow stone, no band (bluetooth off adds a "!")
//   streaming     inverted: a linen band and stone on a moss plate, breathing
//   syncing       the band is the recording in flight, the count inside
//   low battery   clay band
//   attention     "!" inside (bluetooth off, or the ring is nearly full)

/// How the ring icon looks. The default lives in `AppConfig.ringButtonStyle`.
typealias RingButtonStyle = AppConfig.RingButtonStyle

/// The ring icon. `.island` (the default) is a capsule that says what the ring is doing and
/// settles back to the battery, `.glyph` is a 38pt chrome circle with the ring glyph,
/// `.glyphPercent` adds the battery percent in a capsule, `.pill` is a text pill:
/// "ring · linked".
struct RingButton: View {
    let status: RingStatus
    var style: RingButtonStyle
    let action: () -> Void

    init(status: RingStatus, style: RingButtonStyle = .glyph, action: @escaping () -> Void) {
        self.status = status
        self.style = style
        self.action = action
    }

    var body: some View {
        Button {
            MuseHaptics.play(.soft)
            action()
        } label: {
            face
                .fixedSize()
                .frame(minWidth: MuseTopChrome.hitTarget, minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle())
        // The chrome row has a fixed height, so the words stop growing at xxxLarge.
        // VoiceOver reads the whole state, and a long press shows it large.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .museAnimation(MuseMotion.smooth, value: status)
        .accessibilityLabel(status.accessibilityLabel)
        .accessibilityHint("opens your ring")
        .accessibilityShowsLargeContentViewer {
            Text(status.shortLine)
        }
    }

    @ViewBuilder
    private var face: some View {
        switch style {
        case .glyph:
            RingButtonFace(status: status)
        case .glyphPercent:
            RingPercentFace(status: status)
        case .pill:
            RingPillFace(status: status)
        case .island:
            RingIslandFace(status: status)
        }
    }
}

// MARK: - Faces

/// The gauge on its plate: raised paper with a hairline, or moss while a muse streams in.
/// The `.glyph` button's face; use it anywhere the ring's state should show at a glance.
struct RingButtonFace: View {
    let status: RingStatus
    var diameter: CGFloat = MuseTopChrome.circle
    var glyphSize: CGFloat = 21

    var body: some View {
        let style = status.glyphStyle
        status.glyph(size: glyphSize)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(style.plate)
                    .overlay {
                        if style.platesHairline {
                            Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                        }
                    }
            }
    }
}

/// The gauge and the battery percent in a 34pt chrome capsule. Moss while streaming.
private struct RingPercentFace: View {
    let status: RingStatus

    var body: some View {
        let streaming = status.glyphStyle == .streaming
        HStack(spacing: MuseSpacing.xs) {
            status.glyph()
            HStack(spacing: 2) {
                if status.isCharging, status.isLinked, status.battery != nil {
                    Image(systemName: "bolt.fill")
                        .font(MuseFont.symbol(8, weight: .heavy))
                        .accessibilityHidden(true)
                }
                Text(percentText)
                    .font(MuseType.metaMedium)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(status.battery ?? 0)))
            }
            .foregroundStyle(textColor)
        }
        .padding(.leading, MuseSpacing.xs)
        .padding(.trailing, MuseSpacing.sm)
        .frame(height: MuseTopChrome.height)
        .musePill(.chrome, selected: streaming)
    }

    /// "82%", or a word until the ring has answered once.
    private var percentText: String {
        switch status.link {
        case .notSetUp: return "set up"
        case .bluetoothOff: return "off"
        case .joining: return status.battery.map { "\($0)%" } ?? "joining"
        case .away: return status.battery.map { "\($0)%" } ?? "away"
        case .linked: return status.battery.map { "\($0)%" } ?? "linked"
        }
    }

    private var textColor: Color {
        switch status.glyphStyle {
        case .streaming: MuseColor.ground
        case .away, .setup: MuseColor.ink55
        case .linked, .low: MuseColor.ink70
        }
    }
}

/// The text pill: a 7pt dot and "ring · linked" (the lab's C0 pill).
private struct RingPillFace: View {
    let status: RingStatus

    var body: some View {
        HStack(spacing: MuseSpacing.xs) {
            MuseLiveDot(color: dotColor, size: 7, pulses: dotPulses)
            Text("ring · \(word)")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, MuseSpacing.row)
        .museTopChrome()
    }

    /// The word after "ring · ".
    private var word: String {
        if status.isFirmwareUpdating { return "updating" }
        switch status.link {
        case .notSetUp: return status.isSettingUp ? "choosing…" : "set up"
        case .bluetoothOff: return "bluetooth off"
        case .joining: return "joining…"
        case .away: return status.userDisconnected ? "disconnected" : "away"
        case .linked:
            if status.isLive { return "listening" }
            if status.isSyncing { return "bringing in \(max(status.waiting, 1))" }
            if status.isRecordingOnRing { return "recording" }
            if status.needsAttention { return "nearly full" }
            if status.isLowBattery { return "low battery" }
            return status.isCharging ? "charging" : "linked"
        }
    }

    /// Moss while linked, clay only for something the person has to fix (bluetooth, a
    /// nearly full ring, a low battery), quiet ink otherwise. A streaming muse stays moss and
    /// breathes, like the home's status line.
    private var dotColor: Color {
        if status.needsAttention || status.isLowBattery { return MuseColor.clay }
        switch status.link {
        case .linked: return MuseColor.moss600
        default: return MuseColor.ink55
        }
    }

    /// The dot breathes while something is moving: a muse streaming, a sync, a link
    /// coming up, new firmware going over.
    private var dotPulses: Bool {
        status.isLive || status.isSyncing || status.link == .joining || status.isSettingUp
            || status.isFirmwareUpdating
    }
}

// MARK: - Status to glyph

extension RingStatus {
    /// The gauge's look for this status.
    var glyphStyle: MuseRingGlyph.Style {
        switch link {
        case .notSetUp, .bluetoothOff:
            return .setup
        case .joining, .away:
            return .away
        case .linked:
            if isLive { return .streaming }
            if isSyncing { return .linked }
            return isLowBattery ? .low : .linked
        }
    }

    /// The band's length: the recording in flight while syncing, else the battery.
    /// Nil draws the track alone (not set up, or no reading yet).
    var glyphFill: Double? {
        switch link {
        case .notSetUp, .bluetoothOff:
            return nil
        case .linked where isSyncing && !isLive:
            return max(syncProgress ?? 0, 0.04)
        default:
            return battery.map { Double($0) / 100 }
        }
    }

    /// The number inside while recordings come in.
    var glyphCount: Int? {
        link == .linked && isSyncing && !isLive ? max(waiting, 1) : nil
    }

    /// The gauge for this status, ready to draw: `status.glyph(size: 34)`.
    func glyph(size: CGFloat = 21) -> MuseRingGlyph {
        MuseRingGlyph(
            fill: glyphFill,
            style: glyphStyle,
            count: glyphCount,
            attention: needsAttention,
            breathing: link == .linked && isLive,
            size: size
        )
    }
}

// MARK: - Previews

#if DEBUG
/// Every fixture in every style, side by side.
private struct RingButtonGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.md) {
                MuseHeader(title: "ring icon.", subtitle: "every state, in every style.", titleSize: 28)
                ForEach(RingStatus.fixtures, id: \.name) { fixture in
                    VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                        Text(verbatim: fixture.name)
                            .font(MuseType.meta)
                            .foregroundStyle(MuseColor.ink55)
                        HStack(spacing: MuseSpacing.sm) {
                            ForEach(RingButtonStyle.allCases) { style in
                                RingButton(status: fixture.status, style: style) {}
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.vertical, MuseSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { MuseBackground() }
    }
}

/// Steps through the states on a timer, so the motion between them shows.
private struct RingButtonCycle: View {
    @State private var index = 0

    private let steps: [RingStatus] = [.notSetUp, .joining, .linked, .live, .linked, .syncing, .linkedLow, .away]

    var body: some View {
        VStack(spacing: MuseSpacing.xl) {
            ForEach(RingButtonStyle.allCases) { style in
                RingButton(status: steps[index], style: style) {}
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { MuseBackground() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                index = (index + 1) % steps.count
            }
        }
    }
}

#Preview("every state") {
    RingButtonGallery()
}

#Preview("in motion") {
    RingButtonCycle()
}

#Preview("glyph · linked") {
    RingButton(status: .linked) {}
        .padding()
        .background { MuseBackground() }
}
#endif
