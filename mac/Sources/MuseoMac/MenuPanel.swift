import AppKit
import MuseoKit
import SwiftUI

/// The panel the menu bar icon opens, on museo's own paper like the library: the ring in one
/// line with its one action, the rows that matter (typing, the speech model, voice commands
/// and their list), the last few muses, and a quiet foot. Everything rarer about
/// the ring (forget it) is a right click on its line; recordings waiting on the ring get their
/// own row under it (`RingSyncRow`), and come over only when you click it.
struct MenuPanel: View {
    @Environment(\.openWindow) private var openWindow
    @State private var dictation = Dictation.shared
    @State private var commands = VoiceCommands.shared
    private let local = LocalSpeech.shared
    @State private var model = MacSpeech.model
    @State private var language: String?
    @State private var isRenaming = false
    @State private var isRingHovered = false
    private let library = MacLibrary.shared
    private let watch = RingWatch.shared
    private var ring: RingStatus {
        #if DEBUG
        if let ring = Self.previewRing { return ring }
        #endif
        return RingModel.shared.status
    }
    #if DEBUG
    /// A ring to draw instead of the real one, for the README's pictures (`ReadmeShots`).
    static var previewRing: RingStatus?
    #endif
    private var actions: RingActions { .live(openFirmware: {}) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ringLine
                .padding(.bottom, MuseSpacing.sm)
            MuseHairline()
            controls
                .padding(.vertical, MuseSpacing.xxs)
            MuseHairline()
            recent
                .padding(.vertical, MuseSpacing.xs)
            MuseHairline()
            footer
                .padding(.top, MuseSpacing.sm)
        }
        .padding(MuseSpacing.md)
        .frame(width: 310)
        // museo's own paper (linen wash and grain), as in the library. The menu bar's glass
        // follows a dark mac, so the panel brings its own and stays light.
        .background { MuseBackground().ignoresSafeArea() }
        .background(PanelWindowReader())
        .preferredColorScheme(.light)
        .task { language = await MacSpeech.language() }
        // A fresh look at the ring each time the panel opens, so its row is current.
        .onAppear { RingWatch.shared.listSoon(after: 0.3) }
    }

    // MARK: - The ring

    private var ringLine: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            HStack(spacing: MuseSpacing.sm) {
                Image(nsImage: DotRingIcon.small(ring.showsCharging ? .charging : ring.isLinked ? .moss : .faint, size: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    RingNameField(ringName: ring.advertisedName, isEditing: $isRenaming, showsPencil: isRingHovered)
                    Text(status)
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                        .monospacedDigit()
                }
                // The name gets the room first; the gap before the pill gives way.
                .layoutPriority(1)
                Spacer(minLength: 0)
                ringAction
            }
            RingSyncRow(ring: ring, actions: actions) { open(nil) }
                .padding(.top, MuseSpacing.xxs)
            if watch.forgotRing, ring.link == .notSetUp {
                forgotNote
            }
        }
        .contentShape(Rectangle())
        .onHover { isRingHovered = $0 }
        .contextMenu { ringMenu }
    }

    /// "linked · 91%", "charging · 79%", "recording on the ring · 0:42", "away". Bringing in shows in `RingSyncRow`.
    private var status: String {
        switch ring.link {
        case .linked:
            if let since = watch.recordingSince {
                return "recording on the ring · \(watch.now.timeIntervalSince(since).museDuration)"
            }
            guard let battery = ring.battery else { return "linked" }
            if ring.isCharging { return battery >= 100 ? "charged · 100%" : "charging · \(battery)%" }
            return "linked · \(battery)%"
        case .joining: return "joining…"
        case .away: return ring.userDisconnected ? "disconnected" : "away · click it to wake it"
        case .bluetoothOff: return "bluetooth is off"
        case .notSetUp: return ring.isSettingUp ? "looking for rings nearby…" : "not set up on this mac"
        }
    }

    /// After "forget this ring": museo has let go, but macOS keeps its own pairing (the ring
    /// is also its media keys), so it still shows as connected in system settings.
    private var forgotNote: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("museo let go of it. this mac keeps its own pairing for the ring's clicks.")
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink55)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("unpair it in system settings › bluetooth")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .frame(minHeight: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 32)
    }

    /// The one action the ring's state calls for.
    @ViewBuilder
    private var ringAction: some View {
        switch ring.link {
        case .linked:
            disconnectPill
        case .away, .joining:
            ghost("look for it") { actions.lookForIt() }
        case .notSetUp where !ring.isSettingUp:
            ghost("set up") { watch.setUp() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var ringMenu: some View {
        if ring.isLinked {
            Button("bring in everything on the ring") { actions.bringInEverything() }
        }
        if ring.link != .notSetUp {
            Divider()
            if ring.advertisedName != nil {
                Button("rename the ring") { isRenaming = true }
            }
            Button("forget this ring") { watch.forget() }
        }
        Divider()
        Button("quit museo") { NSApp.terminate(nil) }
    }

    /// "disconnect", with forgetting the ring one click away in its dropdown: rare enough
    /// not to need its own button.
    private var disconnectPill: some View {
        HStack(spacing: 0) {
            Button { actions.disconnect() } label: {
                Text("disconnect")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.ink70)
                    .padding(.leading, 10)
                    .padding(.trailing, 7)
                    .frame(height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle())
            Rectangle()
                .fill(MuseColor.ink.opacity(0.14))
                .frame(width: 0.75, height: 14)
            Menu {
                Button("forget this ring") { watch.forget() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(MuseType.caption)
                    .imageScale(.small)
                    .foregroundStyle(MuseColor.ink55)
                    .padding(.leading, 6)
                    .padding(.trailing, 9)
                    .frame(height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("more for this ring")
        }
        .overlay(Capsule().strokeBorder(MuseColor.ink.opacity(0.14), lineWidth: 0.75))
        .contentShape(Capsule())
        .fixedSize()
    }

    private func ghost(_ title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.ink70)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .overlay(Capsule().strokeBorder(MuseColor.ink.opacity(0.14), lineWidth: 0.75))
                .contentShape(Capsule())
        }
        .buttonStyle(MusePressStyle())
        .fixedSize()
    }

    // MARK: - Rows

    private var controls: some View {
        VStack(spacing: 0) {
            row("type into apps") {
                Toggle("type into apps", isOn: $dictation.typesIntoApps)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(MuseColor.moss)
            }
            if dictation.typesIntoApps, !TextInserter.canType {
                Button("let museo type for you…") { TextInserter.askToType() }
                    .buttonStyle(.plain)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.moss600)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, MuseSpacing.xxs)
            }
            row("speech") { speechPicker }
            row("your words") { YourWordsRow() }
            if dictation.typesIntoApps {
                row("voice commands") {
                    Toggle("voice commands", isOn: $commands.isOn)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(MuseColor.moss)
                }
                if commands.isOn {
                    CommandsSection()
                }
            }
        }
    }

    private func row(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(title)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: MuseSpacing.xs)
            trailing()
        }
        .frame(height: 36)
    }

    /// The model, as a real choice. The downloaded one first: one click fetches it, once,
    /// and it's chosen when it lands. Switching applies from the next hold. A right click on
    /// the pill removes a downloaded model.
    private var speechPicker: some View {
        Menu {
            Section("on this mac") {
                ForEach(LocalSpeech.Kind.allCases, id: \.self) { kind in
                    localItem(kind)
                }
            }
            Section("apple") {
                choice(.dictation, detail: "no download · the backup")
                choice(.speech, detail: "no download · long form")
            }
        } label: {
            HStack(spacing: 5) {
                Text(pickerLine)
                    .monospacedDigit()
                if model.local == nil, let language { Text("· \(language)").foregroundStyle(MuseColor.ink55) }
                Image(systemName: "chevron.up.chevron.down")
                    .font(MuseFont.symbol(8))
                    .foregroundStyle(MuseColor.ink55)
            }
            .font(MuseType.caption)
            .foregroundStyle(MuseColor.ink)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(MuseColor.composer.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        // Freeing the space is rare: a right click on the pill, not a line in its menu.
        .contextMenu {
            ForEach(LocalSpeech.Kind.allCases.filter(local.isReady), id: \.self) { kind in
                Button("remove \(kind.name) from this mac · \(kind.size)") {
                    if model.local == kind { model = .dictation }
                    local.remove(kind)
                }
            }
        }
        .onChange(of: model) { _, chosen in
            MacSpeech.model = chosen
            Task {
                await MacSpeech.prepare()
                language = await MacSpeech.language()
            }
        }
        .onChange(of: local.states) { _, states in
            // A model someone asked for just landed: it's the one now.
            if let wanted = local.wanted, states[wanted] == .ready {
                local.wanted = nil
                model = MacSpeech.Model(wanted)
            }
        }
    }

    /// The row's words: the model, or how far its download has come.
    private var pickerLine: String {
        if let wanted = local.wanted, case .downloading(let share) = local.states[wanted] {
            return "\(wanted.name) · \(Int(share * 100))%"
        }
        if let kind = model.local, !local.isReady(kind) { return MacSpeech.Model.dictation.name }
        return model.name
    }

    /// A downloaded model to pick, or one to fetch.
    @ViewBuilder
    private func localItem(_ kind: LocalSpeech.Kind) -> some View {
        switch local.states[kind] ?? .missing {
        case .ready:
            choice(MacSpeech.Model(kind), detail: kind.detail)
        case .downloading(let share):
            Button {} label: {
                Text("\(kind.name) · downloading \(Int(share * 100))%")
                Text(kind.detail)
            }
            .disabled(true)
        case .missing, .failed:
            Button {
                local.download(kind)
            } label: {
                Text("download \(kind.name) · \(kind.size)")
                Text(local.states[kind] == .failed ? "didn't download · try again" : kind.detail)
            }
        }
    }

    /// One model, checked when it's the one in use.
    private func choice(_ choice: MacSpeech.Model, detail: String) -> some View {
        Toggle(isOn: Binding(get: { model == choice }, set: { if $0 { model = choice } })) {
            Text(choice.name)
            Text(detail)
        }
    }

    // MARK: - Recent

    private var recent: some View {
        let muses = library.recent(2)
        return VStack(alignment: .leading, spacing: 2) {
            MuseEyebrow("recent")
                .padding(.top, MuseSpacing.xs)
                .padding(.bottom, MuseSpacing.xxs)
            if muses.isEmpty {
                Text("hold the ring and talk.")
                    .font(MuseType.serifItalic)
                    .foregroundStyle(MuseColor.ink55)
                    .padding(.vertical, MuseSpacing.xs)
            }
            ForEach(muses) { muse in
                if library.isLeftOut(muse.id) {
                    // Short, so not in the library: shown here, with nothing to open.
                    recentRow(muse)
                        .help("short, so it isn't kept in your library")
                } else {
                    Button {
                        open(muse.id)
                    } label: {
                        recentRow(muse)
                    }
                    .buttonStyle(MuseRowPressStyle())
                }
            }
        }
    }

    private func recentRow(_ muse: MacMuse) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(muse.createdAt.museClock)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                MiniPill(muse.isFromRing ? "from the ring" : "streamed", dot: muse.isFromRing ? (muse.isUnseen ? MuseColor.ochre : MuseColor.ochre.opacity(0.55)) : nil)
                if let landing = muse.landing { MiniPill(landing) }
            }
            Text(muse.words ?? "")
                .font(MuseFont.lora(14.5))
                .foregroundStyle(MuseColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Foot

    private var footer: some View {
        HStack(spacing: MuseSpacing.sm) {
            Button {
                open(nil)
            } label: {
                Text("open museo")
                    .font(MuseType.metaMedium)
                    .foregroundStyle(MuseColor.moss600)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o")
            Spacer(minLength: 0)
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(MuseFont.symbol(11))
                    .foregroundStyle(MuseColor.ink55)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .accessibilityLabel("quit museo")
        }
    }

    /// Opens the library, on this muse when there is one.
    private func open(_ id: UUID?) {
        if let id { library.selection = id }
        openWindow(id: LibraryWindow.id)
        NSApp.activate()
    }
}

/// A small pill beside a recent muse's time: how it came in ("streamed", "from the ring") and
/// where it went ("into Notes"). The library's words, smaller.
private struct MiniPill: View {
    let text: String
    let dot: Color?

    init(_ text: String, dot: Color? = nil) {
        self.text = text
        self.dot = dot
    }

    var body: some View {
        HStack(spacing: 4) {
            if let dot { Circle().fill(dot).frame(width: 4, height: 4) }
            Text(text)
                .font(MuseFont.satoshi(10, weight: .medium))
                .foregroundStyle(MuseColor.ink70)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(height: 16)
        .background(MuseColor.raised.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
        .fixedSize()
    }
}
