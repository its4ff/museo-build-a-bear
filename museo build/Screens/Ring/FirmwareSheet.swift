import SwiftUI
import MuseoKit

// The firmware updater as a sheet: one card that says what's happening, one button.
// It drives `RingFirmwareUpdater` (Nordic's MCUboot OTA over its own bluetooth link) and
// never touches the ring itself.
//
//   FirmwareSheet(firmware: Museo.firmware,           // the kit's one updater
//                 canUpdate: ring.status.isLinked,
//                 onNeedRing: { router.open(.ring) },
//                 onClose: { router.close() })
//
// Swipe-to-dismiss and the close button are off while an update runs, so nobody walks
// away from a ring that's half written. The update itself lives in the updater, not
// this view: if the sheet goes, the update carries on.

/// The firmware sheet. `canUpdate` is true when there's a ring to send the update to;
/// when it's false the button goes to the ring sheet instead (`onNeedRing`), which sets a
/// new ring up or brings an away one back.
struct FirmwareSheet: View {
    @ObservedObject var firmware: RingFirmwareUpdater
    var canUpdate: Bool
    var onNeedRing: () -> Void
    var onClose: () -> Void

    var body: some View {
        FirmwareSheetContent(
            phase: firmware.phase,
            status: firmware.status,
            finishAt: firmware.estimatedFinishAt,
            canUpdate: canUpdate,
            onUpdate: { firmware.start() },
            onNeedRing: onNeedRing,
            onClose: {
                firmware.resetIfSettled()
                onClose()
            }
        )
        .onDisappear { firmware.resetIfSettled() }
    }
}

/// The sheet drawn from a phase, so the lab and previews can show every step without a
/// ring. `FirmwareSheet` feeds it the updater's live phase.
struct FirmwareSheetContent: View {
    typealias Phase = RingFirmwareUpdater.Phase

    let phase: Phase
    /// The updater's own short line ("sending firmware", "checking the ring").
    var status: String = ""
    /// When the updater expects to be done (`estimatedFinishAt`): the countdown.
    var finishAt: Date? = nil
    var canUpdate: Bool = true
    var onUpdate: () -> Void = {}
    var onNeedRing: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.xl) {
                MuseHeader(
                    title: "firmware.",
                    subtitle: "bundled \(BundledFirmware.version)",
                    titleSize: 28
                ) {
                    MuseChromeIcon("xmark", label: "close", action: onClose)
                        .opacity(phase.isBusy ? 0 : 1)
                        .disabled(phase.isBusy)
                        .accessibilityHidden(phase.isBusy)
                }
                card
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, MuseSpacing.section)
            .padding(.bottom, MuseSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .museBottomBlur(hostBar: false)
        .safeAreaBar(edge: .bottom, spacing: 0) { footer }
        .background { MuseBackground() }
        .interactiveDismissDisabled(phase.isBusy)
        .museAnimation(MuseMotion.smooth, value: step)
        .museAnimation(MuseMotion.dissolve, value: canUpdate)
        .onChange(of: step) { _, now in
            switch now {
            case .success: MuseHaptics.play(.done)
            case .failed: MuseHaptics.play(.error)
            default: break
            }
            AccessibilityNotification.Announcement([headlineWords, detail].compactMap(\.self).joined(separator: ", ")).post()
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
            HStack(alignment: .center, spacing: MuseSpacing.row) {
                MuseOrb(mode: phase.isBusy ? .thinking : .idle, size: MuseOrb.Size.chat, breathes: step == .idle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(MuseType.headline)
                        .foregroundStyle(MuseColor.ink)
                        .contentTransition(.opacity)
                    if let detail {
                        Text(detail)
                            .font(MuseType.meta)
                            .foregroundStyle(step == .failed ? MuseColor.clay : MuseColor.ink55)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }
                }
            }
            Text(copy)
                .font(MuseType.body)
                .lineSpacing(MuseType.bodyLineSpacing)
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            if let progress {
                progressBlock(progress)
                    .transition(.opacity)
            }
        }
        .padding(MuseSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
    }

    private func progressBlock(_ fraction: Double) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = timeLeft(at: context.date)
            VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                RingMeter(fraction: fraction, height: 6)
                HStack(alignment: .firstTextBaseline) {
                    if let left {
                        Text(left)
                            .foregroundStyle(MuseColor.ink55)
                            .contentTransition(.numericText(countsDown: true))
                    }
                    Spacer(minLength: MuseSpacing.sm)
                    if let sent = sentPercent {
                        Text(verbatim: "\(sent)%")
                            .foregroundStyle(MuseColor.ink70)
                            .contentTransition(.numericText(value: Double(sent)))
                    }
                }
                .font(MuseType.meta)
                .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("update progress")
            .accessibilityValue(
                [sentPercent.map { "\($0) percent sent" } ?? "\(Int((fraction * 100).rounded())) percent", left]
                    .compactMap(\.self)
                    .joined(separator: ", ")
            )
        }
    }

    /// "about 40 s left", "about 1 min left", then "a moment". Only while it runs.
    private func timeLeft(at now: Date) -> String? {
        guard phase.isBusy, let finishAt else { return nil }
        let seconds = Int(finishAt.timeIntervalSince(now).rounded(.up))
        if seconds < 3 { return "a moment" }
        if seconds < 60 { return "about \(seconds) s left" }
        let minutes = Int((Double(seconds) / 60).rounded())
        return "about \(minutes) min left"
    }

    /// While sending, how much of the image has gone over: the number people see.
    private var sentPercent: Int? {
        guard case .sending(let sent) = phase else { return nil }
        return Int((min(max(sent, 0), 1) * 100).rounded())
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        Group {
            if phase.isBusy {
                Text("keep the ring close and stay on this screen.")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: MuseTopChrome.hitTarget)
            } else {
                Button(action: primary) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MuseButtonStyle(.primary))
            }
        }
        .padding(.horizontal, MuseSpacing.page)
        .padding(.top, MuseSpacing.xs)
        .padding(.bottom, MuseSpacing.sm)
    }

    private func primary() {
        switch step {
        case .success:
            MuseHaptics.play(.soft)
            onClose()
        default:
            guard canUpdate else {
                MuseHaptics.play(.soft)
                onNeedRing()
                return
            }
            MuseHaptics.play(.medium)
            onUpdate()
        }
    }

    // MARK: Copy

    /// The phase without its progress, so copy, haptics and motion move once per step,
    /// not once per packet.
    private enum Step: Equatable { case idle, preparing, sending, confirming, resetting, success, failed }

    private var step: Step {
        switch phase {
        case .idle: .idle
        case .preparing: .preparing
        case .sending: .sending
        case .confirming: .confirming
        case .resetting: .resetting
        case .success: .success
        case .failed: .failed
        }
    }

    /// The headline as shown: a step still in progress ends in a real ellipsis ("sending…").
    private var headline: String {
        switch step {
        case .preparing, .sending, .confirming, .resetting: "\(headlineWords)\u{2026}"
        case .idle, .success, .failed: headlineWords
        }
    }

    /// The headline's words alone, for matching the updater's own line and for VoiceOver.
    private var headlineWords: String {
        switch step {
        case .idle: canUpdate ? "ready when you are" : "link your ring first"
        case .preparing: "getting ready"
        case .sending: "sending"
        case .confirming: "confirming"
        case .resetting: "restarting"
        case .success: "updated"
        case .failed: "that didn't finish"
        }
    }

    /// The line under the headline: why it stopped (the screen's one clay mark), or the
    /// updater's own line while it adds something ("checking the ring", "bring the ring
    /// close"), not when it repeats it ("sending firmware").
    private var detail: String? {
        if case .failed(let reason) = phase {
            return reason.isEmpty ? nil : reason.museQuiet
        }
        guard phase.isBusy, !status.isEmpty, !status.contains(headlineWords) else { return nil }
        return status
    }

    private var copy: String {
        switch step {
        case .idle where !canUpdate:
            "the update travels to the ring over bluetooth. set it up or bring it close, then come back here."
        case .idle, .failed:
            "bring the ring close so the update can reach it. stay in the app until it finishes."
        case .preparing:
            "handing the bluetooth link to the updater."
        case .sending:
            "sending the new image over bluetooth."
        case .confirming:
            "the ring is checking the new image, then confirming it."
        case .resetting:
            "the ring is restarting into the new firmware."
        case .success:
            "the ring will reconnect on its own."
        }
    }

    private var buttonTitle: String {
        if step == .success { return "done" }
        if !canUpdate { return "go to your ring" }
        if step == .failed { return "try update again" }
        return "update to latest firmware"
    }

    /// How far along the bar is. Sending fills most of it; confirming and restarting
    /// take the last stretch, so it never runs backwards.
    private var progress: Double? {
        switch phase {
        case .idle, .failed: nil
        case .preparing: 0.02
        case .sending(let sent): 0.02 + 0.88 * sent
        case .confirming: 0.94
        case .resetting: 0.98
        case .success: 1
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("ready") {
    FirmwareSheetContent(phase: .idle)
}

#Preview("no ring linked") {
    FirmwareSheetContent(phase: .idle, canUpdate: false)
}

#Preview("getting ready") {
    FirmwareSheetContent(phase: .preparing, status: "bring the ring close")
}

#Preview("sending") {
    FirmwareSheetContent(phase: .sending(progress: 0.42), status: "sending firmware", finishAt: .now.addingTimeInterval(24))
}

#Preview("confirming") {
    FirmwareSheetContent(phase: .confirming, status: "confirming image")
}

#Preview("restarting") {
    FirmwareSheetContent(phase: .resetting, status: "restarting ring")
}

#Preview("updated") {
    FirmwareSheetContent(phase: .success, status: "firmware updated")
}

#Preview("didn't finish") {
    FirmwareSheetContent(phase: .failed("couldn't find the ring"))
}

#Preview("live updater, as a sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FirmwareSheet(firmware: RingFirmwareUpdater(), canUpdate: true, onNeedRing: {}, onClose: {})
                .presentationDetents([.large])
        }
}
#endif
