import SwiftUI
import MuseoKit

/// The island: one chrome capsule that says what the ring is doing, then settles back to
/// the battery. The `.island` ring button's face, and the default.
///
/// At rest it's a small ring and the battery ("82%"). When something happens it grows to
/// say it: a counting clock on moss while you hold, "recording" with the ring's amber
/// light, "bringing in 3" with the capsule filling softly as they come in, "nearly full" in
/// clay. The width animates with the status (`RingButton` animates on it).
///
/// It reads only `RingStatus`. The symbols are SF Symbols, so their motion (the waveform,
/// the pulse) follows the system and Reduce Motion.
struct RingIslandFace: View {
    let status: RingStatus

    var body: some View {
        let look = Look(status)
        HStack(spacing: MuseSpacing.xxs + 2) {
            symbol(look)
            label(look)
        }
        .padding(.leading, MuseSpacing.xs + 2)
        .padding(.trailing, MuseSpacing.sm)
        .frame(height: MuseTopChrome.height)
        .background {
            // Muses coming in fill the capsule from the leading edge, under the words.
            if let progress = look.progress {
                Rectangle()
                    .fill(MuseColor.mossTint)
                    .scaleEffect(x: max(0.06, min(1, progress)), anchor: .leading)
                    .clipShape(Capsule())
            }
        }
        .musePill(.chrome, selected: look.isStreaming)
    }

    // MARK: Parts

    @ViewBuilder
    private func symbol(_ look: Look) -> some View {
        let image = Image(systemName: look.symbol)
            .museSymbol(look.symbolSize, weight: .semibold)
            .foregroundStyle(look.symbolColor)
            .frame(width: 14)
            .accessibilityHidden(true)
        switch look.motion {
        case .none:
            image
        case .pulse:
            image.symbolEffect(.pulse, options: .repeating)
        case .wave:
            image.symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating)
        }
    }

    @ViewBuilder
    private func label(_ look: Look) -> some View {
        Group {
            if let since = look.since {
                // Counts up from when the hold began.
                Text(since, style: .timer)
            } else {
                Text(look.words)
                    .contentTransition(.numericText())
            }
        }
        .font(MuseType.metaMedium)
        .monospacedDigit()
        .foregroundStyle(look.wordsColor)
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - What it shows

private extension RingIslandFace {
    enum Motion { case none, pulse, wave }

    /// Everything the capsule shows for one status, decided once.
    struct Look {
        var symbol = "circle"
        var symbolSize: CGFloat = 12
        var symbolColor = MuseColor.moss
        var motion = Motion.none
        var words = ""
        var wordsColor = MuseColor.ink70
        /// A hold in progress: the clock counts from here.
        var since: Date?
        /// Muses coming in, 0...1: the capsule fills.
        var progress: Double?
        var isStreaming = false

        init(_ status: RingStatus) {
            if status.isFirmwareUpdating {
                symbol = "arrow.up"
                symbolColor = MuseColor.moss600
                motion = .pulse
                words = "updating"
                return
            }
            switch status.link {
            case .notSetUp:
                symbol = "circle.dashed"
                symbolColor = MuseColor.ink55
                motion = status.isSettingUp ? .pulse : .none
                words = status.isSettingUp ? "choosing…" : "set up"
            case .bluetoothOff:
                symbol = "circle.dashed"
                symbolColor = MuseColor.clay
                words = "bluetooth off"
                wordsColor = MuseColor.clay
            case .joining:
                symbolColor = MuseColor.moss600
                motion = .pulse
                words = "joining…"
            case .away:
                symbolColor = MuseColor.ink55
                words = status.userDisconnected ? "disconnected" : "away"
                wordsColor = MuseColor.ink55
            case .linked:
                linked(status)
            }
        }

        private mutating func linked(_ status: RingStatus) {
            let battery = status.battery.map { "\($0)%" } ?? "linked"
            if status.isLive {
                symbol = "waveform"
                symbolColor = MuseColor.ground
                motion = .wave
                since = status.liveSince ?? .now
                wordsColor = MuseColor.ground
                isStreaming = true
            } else if status.isSyncing {
                symbol = "arrow.down"
                symbolColor = MuseColor.moss600
                words = "bringing in \(max(status.waiting, 1))"
                wordsColor = MuseColor.ink
                progress = status.syncProgress ?? 0
            } else if status.isRecordingOnRing {
                symbol = "circle.fill"
                symbolSize = 9
                symbolColor = MuseColor.ringAmber
                motion = .pulse
                words = "recording"
            } else if status.needsAttention {
                symbol = "exclamationmark.circle.fill"
                symbolColor = MuseColor.clay
                words = "nearly full"
                wordsColor = MuseColor.clay
            } else if status.isLowBattery {
                symbolColor = MuseColor.clay
                words = battery
                wordsColor = MuseColor.clay
            } else if status.isCharging {
                symbol = "bolt.fill"
                symbolColor = MuseColor.moss600
                words = battery
            } else {
                words = battery
            }
        }
    }
}

#Preview("island · every state") {
    ScrollView {
        VStack(alignment: .trailing, spacing: MuseSpacing.sm) {
            ForEach(RingStatus.fixtures, id: \.name) { fixture in
                HStack {
                    Text(verbatim: fixture.name)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                    Spacer()
                    RingIslandFace(status: fixture.status)
                }
            }
        }
        .padding(MuseSpacing.page)
    }
    .background { MuseBackground() }
}
