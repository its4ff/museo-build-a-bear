import SwiftUI
import MuseoKit

// The ring sheet, opened by the one ring icon: the ring as this iphone knows it, its
// battery, what's waiting on it and clearing it, and firmware. Everything it shows
// comes from one `RingStatus`; everything it does goes through `RingActions`, so the
// lab and previews draw it with fixtures and no ring.
//
//   RingSheet(status: ring.status,
//             actions: .live(openFirmware: { router.open(.firmware) }),
//             events: RingSetup.shared.events)
//
// Detents come from whoever presents it (`.presentationDetents([.medium, .large])`). At
// medium the header, the ring and the one thing to do next are all in view.

/// The ring sheet. `events` is the AccessorySetupKit log (`RingSetup.shared.events`),
/// shown only in debug builds.
struct RingSheet: View {
    let status: RingStatus
    let actions: RingActions
    let events: [String]

    init(status: RingStatus, actions: RingActions, events: [String] = []) {
        self.status = status
        self.actions = actions
        self.events = events
    }

    @State private var isConfirmingRemove = false
    /// The one "clear the ring?" dialog, asked from the on the ring card or, on a nearly
    /// full ring, from the button up top.
    @State private var isConfirmingClear = false
    /// A switch flips at once; the real value lands a beat later through `status`
    /// (a second at most, then the switch shows the truth again).
    @State private var pendingAutoSync: Bool?
    @State private var pendingAutoClear: Bool?
    /// Recordings in this sync run, for "bringing in 2 of 5". The status only knows
    /// how many are left.
    @State private var syncTotal = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The ring mark in its inset well, moss when linked.
    private static let ringImageSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.section) {
                VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                    MuseHeader(
                        title: "your ring.",
                        subtitle: status.headline,
                        titleSize: 28,
                        subtitleColor: clayMark == .headline ? MuseColor.clay : MuseColor.ink70
                    )
                    deviceCard
                    primaryAction
                    if let note = status.setupNote, !status.isLinked {
                        MuseHintCard(note, systemImage: "hand.tap")
                    }
                }
                if isSetUp {
                    onTheRing
                    firmware
                }
                oneAppNote
                if isSetUp {
                    footer
                }
                #if DEBUG
                RingLogSection(events: events)
                #endif
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, MuseSpacing.section)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .museBottomBlur()
        .background { MuseBackground() }
        .confirmationDialog("clear the ring?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("clear", role: .destructive) {
                MuseHaptics.play(.success)
                actions.clearStorage()
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text(clearMessage)
        }
        .museAnimation(MuseMotion.smooth, value: status)
        .onAppear { actions.refresh() }
        .onChange(of: status.isSyncing, initial: true) { _, syncing in
            syncTotal = syncing ? status.waiting : 0
        }
        .onChange(of: status.waiting) { _, waiting in
            if status.isSyncing { syncTotal = max(syncTotal, waiting) }
        }
        .onChange(of: status.autoSync) { pendingAutoSync = nil }
        .onChange(of: status.autoClear) { pendingAutoClear = nil }
        .task(id: [pendingAutoSync, pendingAutoClear]) {
            // If the ring kit never reports the new value, the switches go back to the
            // truth instead of holding a guess.
            guard pendingAutoSync != nil || pendingAutoClear != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            pendingAutoSync = nil
            pendingAutoClear = nil
        }
    }

    private var isSetUp: Bool { status.link != .notSetUp }

    private var isLargeType: Bool { dynamicTypeSize.isAccessibilitySize }

    /// A label and its value side by side, or stacked once the type is too big to share
    /// a line.
    private var rowLayout: AnyLayout {
        isLargeType
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: MuseSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: MuseSpacing.sm))
    }

    // MARK: Clay

    /// One clay mark per screen: the thing that most needs the person gets it, the rest
    /// stay ink. (The "remove ring" action is clay too; it's a button, not a mark.)
    private enum ClayMark { case headline, syncError, storage, battery, none }

    private var clayMark: ClayMark {
        if status.link == .bluetoothOff { return .headline }
        if isSetUp, status.syncError != nil { return .syncError }
        if status.isLinked, status.isStorageLow { return .storage }
        if status.isLowBattery { return .battery }
        return .none
    }

    // MARK: Device

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            HStack(alignment: .center, spacing: MuseSpacing.row) {
                ZStack {
                    Circle()
                        .fill(MuseColor.inset)
                        .overlay {
                            Circle().strokeBorder(MuseColor.hairline, lineWidth: 0.75)
                        }
                    MuseRingMark(
                        size: Self.ringImageSize * 0.52,
                        color: status.isLinked ? MuseColor.moss : MuseColor.ink55
                    )
                }
                .frame(width: Self.ringImageSize, height: Self.ringImageSize)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                        Text(status.name)
                            .font(MuseType.titleSmall)
                            .tracking(MuseType.titleTracking)
                            .foregroundStyle(MuseColor.ink)
                            .lineLimit(2)
                        if status.isLinked, status.canRename {
                            renameButton
                        }
                    }
                    Text(status.deviceLine)
                        .font(MuseType.meta)
                        .monospacedDigit()
                        .foregroundStyle(MuseColor.ink55)
                        .lineLimit(isLargeType ? nil : 2)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }
            if isSetUp, let battery = status.battery {
                batteryRow(battery)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .museCardSurface()
    }

    private var renameButton: some View {
        Button {
            MuseHaptics.play(.soft)
            actions.rename()
        } label: {
            // A small pencil on the name's baseline, with a full 44pt target around it.
            Image(systemName: "pencil")
                .museSymbol(13, weight: .semibold)
                .foregroundStyle(MuseColor.ink55)
                .padding(MuseSpacing.xxs)
                .contentShape(Rectangle().inset(by: -MuseSpacing.sm))
        }
        .buttonStyle(MusePressStyle())
        .accessibilityLabel("rename your ring")
    }

    private func batteryRow(_ battery: Int) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            RingMeter(fraction: Double(battery) / 100, tint: batteryTint)
            rowLayout {
                Text("battery")
                    .foregroundStyle(MuseColor.ink55)
                if !isLargeType {
                    Spacer(minLength: MuseSpacing.xs)
                }
                Text(batteryText(battery))
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink70)
                    .contentTransition(.numericText(value: Double(battery)))
            }
            .font(MuseType.meta)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("battery")
        .accessibilityValue(Self.spoken(batteryText(battery)))
    }

    /// "80%", "55% · charging", "80% · last read 2m ago", "15% · charge soon". Away, the
    /// line above already says when it was read, so this one doesn't say it twice.
    private func batteryText(_ battery: Int) -> String {
        let saidAbove = status.link == .away && status.batteryReadAt != nil && !status.isCharging
        let line = saidAbove ? "\(battery)%" : (status.batteryLine ?? "\(battery)%")
        return status.isLowBattery ? "\(line) · charge soon" : line
    }

    /// Moss while it's a live reading, half strength when it's the last one, clay when
    /// low (if nothing else has the clay).
    private var batteryTint: Color {
        if clayMark == .battery { return MuseColor.clay }
        if !status.isLinked || status.batteryIsStale { return MuseColor.ink55 }
        return MuseColor.moss
    }

    // MARK: The one thing to do

    @ViewBuilder
    private var primaryAction: some View {
        switch status.link {
        case .notSetUp:
            Button {
                MuseHaptics.play(.medium)
                actions.setUp()
            } label: {
                Text("set up your ring")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MuseButtonStyle(.primary))
            .disabled(status.isSettingUp)
        case .away:
            Button {
                MuseHaptics.play(.soft)
                actions.lookForIt()
            } label: {
                Text("look for it")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MuseButtonStyle(.secondary))
            .disabled(status.isSettingUp)
        case .linked:
            makeRoom
        case .bluetoothOff, .joining:
            EmptyView()
        }
    }

    // MARK: Making room

    /// A nearly full ring, up where the medium detent shows it: how long is left and the
    /// one thing that makes room. It wears the sheet's clay (`.storage`). Bringing in is
    /// safe, so it's this sheet's primary button. Clearing can't be undone, so it's
    /// secondary and asks first (the same dialog as the row in on the ring).
    @ViewBuilder
    private var makeRoom: some View {
        if let room = status.room, let line = status.storageLine {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                Text(roomLine(room, line))
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(clayMark == .storage ? MuseColor.clay : MuseColor.ink70)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MuseSpacing.xxs)
                switch room {
                case .bringIn:
                    if !status.isSyncing {
                        Button {
                            MuseHaptics.play(.soft)
                            actions.syncNow()
                        } label: {
                            Text(status.waiting == 1 ? "bring it in" : "bring them in")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MuseButtonStyle(.primary))
                    }
                case .clear:
                    Button {
                        MuseHaptics.play(.soft)
                        isConfirmingClear = true
                    } label: {
                        Text("clear the ring")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MuseButtonStyle(.secondary))
                }
            }
            .transition(.opacity)
        }
    }

    /// "nearly full · about 22 min left. 2 recordings on it haven't come in yet." /
    /// "nearly full · about 22 min left. everything on it is already here; it keeps a copy."
    private func roomLine(_ room: RingStatus.Room, _ line: String) -> String {
        if status.isSyncing { return line }
        switch room {
        case .bringIn:
            return status.waiting == 1
                ? "\(line). 1 recording on it hasn't come in yet."
                : "\(line). \(status.waiting) recordings on it haven't come in yet."
        case .clear:
            return "\(line). nothing is waiting on it; it keeps a copy of what came in."
        }
    }

    // MARK: On the ring

    private var onTheRing: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("on the ring")
            MuseListCard {
                waitingRow
                if let storage = status.storageLine {
                    storageRow(storage)
                }
                MuseToggleRow("bring recordings in on their own", isOn: autoSync)
                MuseToggleRow(
                    "clear the ring once they're safe",
                    subtitle: "off keeps a copy on the ring for other apps",
                    isOn: autoClear
                )
                clearRow
            }
            if let error = status.syncError {
                Text(error)
                    .font(MuseType.meta)
                    .foregroundStyle(clayMark == .syncError ? MuseColor.clay : MuseColor.ink70)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MuseSpacing.xxs)
            }
        }
    }

    private var waitingRow: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            rowLayout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(waitingTitle)
                        .font(MuseType.label)
                        .monospacedDigit()
                        .foregroundStyle(status.waiting > 0 || status.isSyncing ? MuseColor.ink : MuseColor.ink55)
                        .contentTransition(.numericText())
                    if let detail = waitingDetail {
                        Text(detail)
                            .font(MuseType.meta)
                            .monospacedDigit()
                            .foregroundStyle(MuseColor.ink55)
                            .contentTransition(.numericText())
                    }
                }
                .accessibilityElement(children: .combine)
                if !isLargeType {
                    Spacer(minLength: MuseSpacing.xs)
                }
                // While the ring is nearly full, the same button sits up top (`makeRoom`).
                if status.isLinked, status.waiting > 0, !status.isSyncing, status.room == nil {
                    Button(status.waiting == 1 ? "bring it in" : "bring them in") {
                        MuseHaptics.play(.soft)
                        actions.syncNow()
                    }
                    .buttonStyle(MuseButtonStyle(.tinted, height: 32))
                    .transition(.opacity)
                }
            }
            if status.isSyncing {
                RingMeter(fraction: status.syncProgress ?? 0)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private var waitingTitle: String {
        if status.isSyncing {
            let total = max(syncTotal, status.waiting, 1)
            if total == 1 { return "bringing in 1 recording" }
            return "bringing in \(total - max(status.waiting, 1) + 1) of \(total)"
        }
        switch status.waiting {
        case 0: return "nothing waiting on the ring"
        case 1: return "1 recording waiting"
        default: return "\(status.waiting) recordings waiting"
        }
    }

    private var waitingDetail: String? {
        if status.isSyncing {
            let percent = Int(((status.syncProgress ?? 0) * 100).rounded())
            return "\(percent)% of this one · keep the ring close"
        }
        if status.waiting > 0, !status.isLinked {
            return status.waiting == 1 ? "it comes in when the ring links" : "they come in when the ring links"
        }
        return nil
    }

    private func storageRow(_ line: String) -> some View {
        rowLayout {
            Text("storage")
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
            if !isLargeType {
                Spacer(minLength: MuseSpacing.xs)
            }
            Text(line)
                .font(MuseType.meta)
                .monospacedDigit()
                // The clay sits on the line up top (`makeRoom`) while it shows.
                .foregroundStyle(clayMark == .storage && status.room == nil ? MuseColor.clay : MuseColor.ink55)
                .multilineTextAlignment(isLargeType ? .leading : .trailing)
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Clearing the ring

    /// Clear by hand, under the switch that does it on its own. Ink, not clay: the sheet's
    /// clay belongs to whatever most needs the person, and the dialog says it's for good.
    private var clearRow: some View {
        MuseListRow(
            title: "clear ring storage",
            meta: clearMeta,
            systemImage: "trash",
            showsChevron: false
        ) {
            isConfirmingClear = true
        }
        .disabled(!canClear)
        .opacity(canClear ? 1 : 0.42)
    }

    /// The ring only clears while it's linked and idle; until then the row says when.
    private var canClear: Bool {
        status.isLinked && !status.isSyncing && !status.isRecordingOnRing && !status.isLive
            && !status.isFirmwareUpdating
    }

    private var clearMeta: String {
        guard status.isLinked else { return "when your ring links" }
        if status.isSyncing { return "after this sync finishes" }
        if status.isRecordingOnRing && !status.isLive { return "after it stops recording" }
        if status.isLive { return "after this stream ends" }
        if status.isFirmwareUpdating { return "after the update" }
        if status.waiting > 0 {
            return status.waiting == 1
                ? "1 recording on it hasn't come in yet"
                : "\(status.waiting) recordings on it haven't come in yet"
        }
        return "every recording on it goes · muses stay"
    }

    private var clearMessage: String {
        if status.waiting > 0 {
            let recordings = status.waiting == 1 ? "1 recording" : "\(status.waiting) recordings"
            return "\(recordings) still on the ring will be gone for good. muses already on this iphone stay."
        }
        return "muses already on this iphone stay. other apps that use the ring lose their copies."
    }

    private var autoSync: Binding<Bool> {
        Binding(
            get: { pendingAutoSync ?? status.autoSync },
            set: { on in
                pendingAutoSync = on
                actions.setAutoSync(on)
            }
        )
    }

    private var autoClear: Binding<Bool> {
        Binding(
            get: { pendingAutoClear ?? status.autoClear },
            set: { on in
                pendingAutoClear = on
                actions.setAutoClear(on)
            }
        )
    }

    // MARK: Firmware

    private var firmware: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            MuseSectionHeader("firmware")
            MuseListRow(
                title: "update firmware",
                meta: status.isFirmwareUpdating
                    ? "updating now · keep it close"
                    : "bundled \(BundledFirmware.version)",
                systemImage: "arrow.down.circle"
            ) {
                actions.openFirmware()
            }
        }
    }

    private var oneAppNote: some View {
        Text("one ring app per phone. two apps on one ring split your recordings.")
            .font(MuseType.meta)
            .foregroundStyle(MuseColor.ink55)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            MuseHairline()
            HStack(spacing: MuseSpacing.sm) {
                if status.isLinked {
                    Button {
                        MuseHaptics.play(.soft)
                        actions.disconnect()
                    } label: {
                        Text("disconnect")
                            .foregroundStyle(MuseColor.ink70)
                            .frame(minHeight: MuseTopChrome.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MusePressStyle(pressedScale: 0.97))
                }
                Spacer(minLength: MuseSpacing.sm)
                Button {
                    MuseHaptics.play(.soft)
                    isConfirmingRemove = true
                } label: {
                    Text("remove ring")
                        .foregroundStyle(MuseColor.clay)
                        .frame(minHeight: MuseTopChrome.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.97))
                // On the button, so the question rises from what was tapped.
                .confirmationDialog("remove your ring?", isPresented: $isConfirmingRemove, titleVisibility: .visible) {
                    Button("remove", role: .destructive) {
                        MuseHaptics.play(.warning)
                        actions.remove()
                    }
                    Button("keep it", role: .cancel) {}
                } message: {
                    Text("this iphone forgets it in every app that uses it. you can set it up again any time.")
                }
            }
            .font(MuseType.meta)
            .padding(.top, MuseSpacing.xxs)
        }
    }

    /// Commas for middle dots, for VoiceOver.
    nonisolated private static func spoken(_ line: String) -> String {
        line.replacingOccurrences(of: " · ", with: ", ").replacingOccurrences(of: "%", with: " percent")
    }
}

// MARK: - Meter

/// A thin capsule gauge: battery, a sync in flight, a firmware upload. Moss on a faint
/// ink track; a sliver always shows so 0% still reads as a gauge.
struct RingMeter: View {
    var fraction: Double
    var tint: Color = MuseColor.moss
    var height: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(MuseColor.ink.opacity(0.08))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
                }
            }
            .museAnimation(MuseMotion.gentle, value: fraction)
            .accessibilityHidden(true)
    }
}

// MARK: - Ring log (debug builds)

#if DEBUG
/// The AccessorySetupKit events, newest last, collapsed by default. For builders chasing
/// a setup that didn't take; never in a release build.
private struct RingLogSection: View {
    let events: [String]
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.md) {
            Button {
                MuseHaptics.play(.selection)
                isOpen.toggle()
            } label: {
                HStack(spacing: MuseSpacing.sm) {
                    MuseEyebrow("ring log")
                    MuseSectionCount(count: events.count)
                    Spacer(minLength: MuseSpacing.sm)
                    Image(systemName: "chevron.down")
                        .museSymbol(11, weight: .semibold)
                        .foregroundStyle(MuseColor.ink55)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "hide the ring log" : "show the ring log")
            if isOpen {
                if events.isEmpty {
                    Text("nothing logged yet. setup events land here.")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                } else {
                    MuseCodeLine(events.joined(separator: "\n"), caption: "accessorysetupkit events, newest last")
                }
            }
        }
        .museAnimation(MuseMotion.smooth, value: isOpen)
    }
}
#endif

// MARK: - Previews

#if DEBUG
private extension RingStatus {
    func with(_ change: (inout RingStatus) -> Void) -> RingStatus {
        var copy = self
        change(&copy)
        return copy
    }
}

private let previewEvents = [
    "09:41:02.114 activated accessories=1",
    "09:41:02.380 handOff Muse_47cf",
    "09:41:03.902 linked",
]

#Preview("linked") {
    RingSheet(status: .linked, actions: .preview, events: previewEvents)
        .environment(AppRouter())
}

#Preview("not set up") {
    RingSheet(status: .notSetUp, actions: .preview)
        .environment(AppRouter())
}

#Preview("not set up · nothing answered") {
    RingSheet(
        status: .notSetUp.with { $0.setupNote = "no ring answered. click it 6 to 7 times to wake it, then try again." },
        actions: .preview
    )
        .environment(AppRouter())
}

#Preview("choosing") {
    RingSheet(status: .notSetUp.with { $0.isSettingUp = true }, actions: .preview)
        .environment(AppRouter())
}

#Preview("joining") {
    RingSheet(status: .joining, actions: .preview)
        .environment(AppRouter())
}

#Preview("away") {
    RingSheet(status: .away.with { $0.waiting = 2 }, actions: .preview)
        .environment(AppRouter())
}

#Preview("disconnected") {
    RingSheet(status: .away.with { $0.userDisconnected = true }, actions: .preview)
        .environment(AppRouter())
}

#Preview("bluetooth off") {
    RingSheet(status: .bluetoothOff, actions: .preview)
        .environment(AppRouter())
}

#Preview("streaming") {
    RingSheet(status: .live, actions: .preview)
        .environment(AppRouter())
}

#Preview("syncing") {
    RingSheet(status: .syncing, actions: .preview)
        .environment(AppRouter())
}

#Preview("sync stopped") {
    RingSheet(
        status: .linked.with {
            $0.waiting = 2
            $0.syncError = "the ring stopped answering. it'll try again when it's close."
        },
        actions: .preview
    )
        .environment(AppRouter())
}

#Preview("low battery") {
    RingSheet(status: .linkedLow, actions: .preview)
        .environment(AppRouter())
}

#Preview("charging") {
    RingSheet(status: .charging, actions: .preview)
        .environment(AppRouter())
}

#Preview("nearly full") {
    RingSheet(status: .nearlyFull, actions: .preview)
        .environment(AppRouter())
}

#Preview("as a sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RingSheet(status: .syncing, actions: .preview, events: previewEvents)
                .presentationDetents([.medium, .large])
        }
}
#endif

#Preview("nearly full · waiting") {
    RingSheet(status: .nearlyFull, actions: .preview)
        .environment(AppRouter())
}

#Preview("nearly full · all in") {
    RingSheet(status: .nearlyFull.with { $0.waiting = 0 }, actions: .preview)
        .environment(AppRouter())
}
