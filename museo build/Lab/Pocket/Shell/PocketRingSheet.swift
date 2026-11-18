#if DEBUG
import SwiftUI

/// The ring sheet: the ring large, as print, with its light; what it is doing in one line;
/// the exact battery and the room left on it; the four gestures as a quiet list; firmware
/// as one line. No ground of its own: it sits on the sheet's paper (shell a, the lab's
/// `LabSheet`) or on the corner's glass panel (shell b).
///
/// One primary button at most, and only when the ring needs you: away, "look for it".
struct PocketRingSheet: View {
    let state: PocketRingState

    /// As tall as what it holds: `pocketFittedSheet()` sizes the sheet to it and scrolls it
    /// at the largest text sizes.
    var body: some View {
        VStack(spacing: MuseSpacing.section) {
            head
            facts
            gestures
            foot
        }
        .padding(.horizontal, MuseSpacing.xl)
        .padding(.top, MuseSpacing.sectionLabel)
        .padding(.bottom, MuseSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - The ring, its name, what it is doing

    private var head: some View {
        VStack(spacing: MuseSpacing.md) {
            PocketHalftoneRing(size: PocketRingSheetMetrics.ring, light: light)
            VStack(spacing: MuseSpacing.xxs) {
                Text("your museo")
                    .font(MuseType.titleSmall)
                    .foregroundStyle(MuseColor.ink)
                Text(doing)
                    .font(MuseType.body)
                    .foregroundStyle(MuseColor.ink55)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var light: PocketRingLight? {
        switch state {
        case .memory: .amber
        case .streaming: .white
        default: nil
        }
    }

    /// The state, in one line.
    private var doing: String {
        switch state {
        case .away: "away"
        case .linked: "linked"
        case .memory: "recording to memory"
        case .streaming: "streaming"
        case .bringingIn(_, let total): "bringing in \(total)…"
        case .charging: "charging"
        }
    }

    // MARK: - Battery, room left

    private var facts: some View {
        HStack(spacing: 0) {
            if let battery {
                fact("battery", battery)
                Rectangle()
                    .fill(MuseColor.hairline)
                    .frame(width: PocketRingSheetMetrics.rule, height: PocketRingSheetMetrics.factRule)
                    .accessibilityHidden(true)
            }
            fact("room left", PocketFixtures.roomLeft)
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        VStack(spacing: MuseSpacing.xxs) {
            Text(value)
                .font(MuseType.label)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink)
            Text(name)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value)")
    }

    /// The ring's exact percent, when it is near enough to say.
    private var battery: String? {
        switch state {
        case .away: nil
        case .linked(let battery): "\(battery)%"
        case .charging(let level): "\(level)%"
        case .memory, .streaming, .bringingIn:
            if case .linked(let battery) = PocketFixtures.ring { "\(battery)%" } else { nil }
        }
    }

    // MARK: - The four gestures

    private var gestures: some View {
        VStack(spacing: 0) {
            ForEach(PocketRingGesture.all) { gesture in
                if gesture.id != PocketRingGesture.all.first?.id {
                    Rectangle()
                        .fill(MuseColor.hairline)
                        .frame(height: PocketRingSheetMetrics.rule)
                        .accessibilityHidden(true)
                }
                HStack(spacing: MuseSpacing.sm) {
                    RingGestureMark(gesture.mark, color: MuseColor.ink70)
                        .accessibilityHidden(true)
                    Text(gesture.name)
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink)
                    Spacer(minLength: MuseSpacing.sm)
                    Text(gesture.does)
                        .font(MuseType.body)
                        .foregroundStyle(MuseColor.ink55)
                }
                .lineLimit(1)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(gesture.name), \(gesture.does)")
            }
        }
    }

    // MARK: - Firmware, and the one thing to do

    @ViewBuilder
    private var foot: some View {
        VStack(spacing: MuseSpacing.md) {
            if case .away = state {
                Button {
                    MuseHaptics.play(.soft)
                } label: {
                    Text("look for it")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ground)
                        .frame(maxWidth: .infinity)
                        .frame(height: PocketRingPillMetrics.height)
                        .pocketMossPill()
                        .contentShape(Capsule())
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.98))
            }
            Text("firmware \(PocketFixtures.firmware)")
                .font(MuseType.meta)
                .monospacedDigit()
                .foregroundStyle(MuseColor.ink55)
        }
    }
}

/// One way to press the ring, and what it does.
private nonisolated struct PocketRingGesture: Identifiable, Sendable {
    let mark: RingGestureMark.Gesture
    let name: String
    let does: String

    var id: String { name }

    static let all: [PocketRingGesture] = [
        PocketRingGesture(mark: .hold, name: "hold", does: "streamed"),
        PocketRingGesture(mark: .clicks(2), name: "double click", does: "memory"),
        PocketRingGesture(mark: .clicks(1), name: "click", does: "play or pause"),
        PocketRingGesture(mark: .clicks(3), name: "three clicks", does: "skip"),
    ]
}

private nonisolated enum PocketRingSheetMetrics {
    /// The ring, large.
    static let ring: CGFloat = 156
    /// A hairline.
    static let rule: CGFloat = 1
    /// The rule between the two facts.
    static let factRule: CGFloat = 32
}

#Preview {
    PocketRingSheet(state: PocketFixtures.ring)
        .background(MuseColor.raised)
}
#endif
