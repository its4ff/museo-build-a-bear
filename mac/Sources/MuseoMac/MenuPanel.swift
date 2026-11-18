import AppKit
import MuseoKit
import SwiftUI

/// The panel the menu bar icon opens, on the dune like the library: the ring as its pill, with
/// what it can be told behind the glyph beside it (rename, disconnect, forget), the rows that
/// matter (typing, the speech model, your words, voice commands and their list), the last two
/// muses, and a quiet foot. Recordings waiting on the ring get their own row under the pill
/// (`RingSyncRow`), and come over only when you click it. Type and space do the dividing.
struct MenuPanel: View {
    @Environment(\.openWindow) private var openWindow
    @State private var dictation = Dictation.shared
    @State private var commands = VoiceCommands.shared
    private let local = LocalSpeech.shared
    @State private var model = MacSpeech.model
    @State private var language: String?
    @State private var isRenaming = false
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
            if let offer = UpdateModel.shared.offer {
                PanelUpdateRow(offer: offer) {
                    if offer.stage == .ready { Updates.restart() } else { Updates.install() }
                } more: {
                    LibraryOpener.update()
                }
                .padding(.bottom, MuseSpacing.xs)
            }
            controls
            recent
                .padding(.top, MuseSpacing.lg)
            footer
                .padding(.top, MuseSpacing.sm)
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.top, MuseSpacing.sm)
        .padding(.bottom, MuseSpacing.xs)
        .frame(width: PanelMetrics.width)
        // The dune, quiet, as in the library. The menu bar's glass follows a dark mac, so the
        // panel brings its own paper and stays light.
        .background { PanelGround() }
        .background(PanelWindowReader())
        .preferredColorScheme(.light)
        .task { language = await MacSpeech.language() }
        // A fresh look at the ring each time the panel opens, so its row is current.
        .onAppear { RingWatch.shared.listSoon(after: 0.3) }
    }

    // MARK: - The ring

    /// How the ring shows at the panel's top: the moss pill, or the plain line it had before
    /// (the mark, its name, one status line), with disconnect in sight or in the menu.
    enum RingLineStyle {
        case pill, line, quietLine
    }

    static var ringLineStyle = RingLineStyle.line

    /// The ring as a plain line on the paper: the halftone mark, its name in Lora, one
    /// status line under it. `showsDisconnect` keeps the disconnect capsule; without it,
    /// everything is in the ellipsis.
    private func plainLine(showsDisconnect: Bool) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            PocketHalftoneRing(
                size: DuoMetrics.pillMark + MuseSpacing.xxs,
                ink: ring.isLinked ? MuseColor.moss : MuseColor.ink55,
                light: ring.isLinked && watch.recordingSince != nil ? .amber : nil,
                dots: DuoMetrics.pillMarkDots
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                RingNameField(ringName: ring.advertisedName, isEditing: $isRenaming)
                Text(status)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            if showsDisconnect, ring.isLinked {
                // One capsule: disconnect, and the rarer things behind its chevron.
                HStack(spacing: 0) {
                    Button { actions.disconnect() } label: {
                        Text("disconnect")
                            .font(MuseType.captionMedium)
                            .foregroundStyle(MuseColor.ink70)
                            .padding(.leading, MuseSpacing.sm)
                            .padding(.trailing, MuseSpacing.xs)
                            .frame(height: MuseSpacing.section)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle()
                        .fill(MuseColor.hairline)
                        .frame(width: 1, height: MuseSpacing.row)
                        .accessibilityHidden(true)
                    Menu {
                        ringMenu
                    } label: {
                        Image(systemName: "chevron.down")
                            .museSymbol(MuseSpacing.xs, weight: .semibold)
                            .foregroundStyle(MuseColor.ink55)
                            .padding(.leading, MuseSpacing.xs)
                            .padding(.trailing, MuseSpacing.sm - MuseSpacing.xxs / 2)
                            .frame(height: MuseSpacing.section)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("rename, forget, bring in")
                    .accessibilityLabel("more for this ring")
                }
                .duoControlGlass()
                .fixedSize()
            } else if ring.link != .notSetUp {
                Menu {
                    ringMenu
                } label: {
                    Image(systemName: "ellipsis")
                        .museSymbol(PanelMetrics.more, weight: .semibold)
                        .foregroundStyle(MuseColor.ink70)
                        .frame(width: PanelMetrics.moreBox, height: MuseSpacing.section)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("rename, disconnect, forget")
                .accessibilityLabel("more for this ring")
            }
        }
    }

    private var ringLine: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            if Self.ringLineStyle != .pill {
                plainLine(showsDisconnect: Self.ringLineStyle == .line)
            } else {
            HStack(spacing: MuseSpacing.xxs) {
                PanelRingPill(state: pillState, ringName: ring.advertisedName, detail: pillDetail, spoken: status, isRenaming: $isRenaming)
                if ring.link != .notSetUp {
                    // Everything the ring can be told, in sight: nothing is right click only.
                    Menu {
                        ringMenu
                    } label: {
                        Image(systemName: "ellipsis")
                            .museSymbol(PanelMetrics.more, weight: .semibold)
                            .foregroundStyle(MuseColor.ink70)
                            .frame(width: PanelMetrics.moreBox, height: DuoMetrics.bar)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("rename, disconnect, forget")
                    .accessibilityLabel("more for this ring")
                }
            }
            .padding(.trailing, ring.link != .notSetUp ? -MuseSpacing.xs : 0)
            }
            ringHint
            RingSyncRow(ring: ring, actions: actions) { open(nil) }
            if watch.forgotRing, ring.link == .notSetUp {
                forgotNote
            }
        }
        .contextMenu {
            ringMenu
            Divider()
            if Updates.isOn {
                Button("check for updates") { Updates.check() }
            }
            Button("quit museo") { NSApp.terminate(nil) }
        }
    }

    /// What the pill is filled with: the ring's state, and amber while it records to itself.
    private var pillState: PocketRingState {
        if ring.isLinked, watch.recordingSince != nil { return .memory }
        return PocketRingState(ring)
    }

    /// The pill's one quiet word: "82%", "recording · 0:42", "away".
    private var pillDetail: String? {
        switch ring.link {
        case .linked:
            if let since = watch.recordingSince {
                return "recording · \(watch.now.timeIntervalSince(since).museDuration)"
            }
            if ring.isSyncing { return "bringing in…" }
            guard let battery = ring.battery else { return "linked" }
            return "\(battery)%"
        case .joining: return "joining…"
        case .away: return ring.userDisconnected ? "disconnected" : "away"
        case .bluetoothOff: return "bluetooth is off"
        case .notSetUp: return nil
        }
    }

    /// The whole of it, for VoiceOver: "linked · 91%", "charging · 79%",
    /// "recording on the ring · 0:42", "away". Bringing in shows in `RingSyncRow`.
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

    /// Under the pill when the ring isn't linked: what to do about it, and the one action
    /// its state calls for.
    @ViewBuilder
    private var ringHint: some View {
        let hint: String? = switch ring.link {
        case .away where !ring.userDisconnected: "click it to wake it"
        case .notSetUp: ring.isSettingUp ? "looking for rings nearby…" : "not set up on this mac"
        default: nil
        }
        let action: (title: String, run: () -> Void)? = switch ring.link {
        case .away, .joining: ("look for it", { actions.lookForIt() })
        case .notSetUp where !ring.isSettingUp: ("set up", { watch.setUp() })
        default: nil
        }
        if hint != nil || action != nil {
            HStack(spacing: MuseSpacing.sm) {
                if let hint {
                    Text(hint)
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                    Spacer(minLength: 0)
                }
                if let action {
                    wordButton(action.title, run: action.run)
                }
                if hint == nil { Spacer(minLength: 0) }
            }
            .padding(.leading, MuseSpacing.sm)
            .padding(.trailing, MuseSpacing.xxs)
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
                    .frame(minHeight: PanelMetrics.wordButton)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, MuseSpacing.sm)
    }

    /// What the ring can be told, for the glyph beside the pill and for a right click.
    @ViewBuilder
    private var ringMenu: some View {
        if ring.isLinked {
            Button("bring in everything on the ring") { actions.bringInEverything() }
        }
        if ring.link != .notSetUp {
            if ring.advertisedName != nil {
                Button("rename the ring") { isRenaming = true }
            }
            // Beside the chevron already, when the capsule shows it.
            if ring.isLinked, Self.ringLineStyle != .line {
                Button("disconnect") { actions.disconnect() }
            }
            Button("forget this ring") { watch.forget() }
        }
    }

    /// A quiet action in moss words: "look for it", "set up".
    private func wordButton(_ title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss600)
                .frame(height: PanelMetrics.wordButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle())
        .fixedSize()
    }

    // MARK: - Rows

    private var controls: some View {
        VStack(spacing: 0) {
            row("type into apps") {
                Toggle("type into apps", isOn: $dictation.typesIntoApps)
                    .toggleStyle(PanelSwitchStyle())
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
                        .toggleStyle(PanelSwitchStyle())
                }
                if commands.isOn {
                    row("at a hold's end, too") {
                        Toggle("commands at a hold's end, too", isOn: $commands.readsEdges)
                            .toggleStyle(PanelSwitchStyle())
                    }
                    .help("say one after a pause, at the end or the start of a hold, and it runs with the words")
                    CommandsSection()
                        .padding(.top, MuseSpacing.xxs)
                }
            }
        }
    }

    private func row(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(title)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: PanelMetrics.rowHeight)
    }

    /// The model, as a real choice. The downloaded one first: one click fetches it, once,
    /// and it's chosen when it lands. Switching applies from the next hold. A right click on
    /// its words removes a downloaded model.
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
            PanelChoiceLabel(
                value: pickerLine,
                detail: model.local == nil ? language.map { "· \($0)" } : nil,
                symbol: "chevron.up.chevron.down"
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        // Freeing the space is rare: a right click on the choice, not a line in its menu.
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
        return VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            MuseEyebrow("recent")
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

    /// When, how it came in and where it went, in one quiet line; then the words.
    private func recentRow(_ muse: MacMuse) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
            HStack(spacing: MuseSpacing.xxs) {
                if muse.isFromRing {
                    // Amber for one from the ring's memory, brighter until it's been seen.
                    Circle()
                        .fill(MuseColor.ochre.opacity(muse.isUnseen ? 1 : 0.55))
                        .frame(width: PanelMetrics.unseenDot, height: PanelMetrics.unseenDot)
                        .accessibilityHidden(true)
                }
                Text([muse.createdAt.museClock, muse.isFromRing ? "from the ring" : "streamed", muse.landing].compactMap { $0 }.joined(separator: " · "))
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .lineLimit(1)
            }
            Text(muse.words ?? "")
                .font(MuseFont.lora(PanelMetrics.recentWords))
                .foregroundStyle(MuseColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MuseSpacing.xxs)
        .contentShape(Rectangle())
    }

    // MARK: - Foot

    private var footer: some View {
        VStack(spacing: 0) {
            MuseHairline()
            HStack(spacing: MuseSpacing.sm) {
                Button {
                    open(nil)
                } label: {
                    footWord("open museo")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o")
                Text("·")
                    .font(MuseType.metaMedium)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
                // Straight to a blank page, without the library in between.
                Button {
                    openWindow(id: NoteWindow.id, value: UUID())
                    NSApp.activate()
                } label: {
                    footWord("new note")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n")
                .help("new note · ⌘N")
                Spacer(minLength: 0)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .museSymbol(PanelMetrics.power, weight: .medium)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(width: PanelMetrics.rowHeight, height: PanelMetrics.rowHeight, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .help("quit museo")
                .accessibilityLabel("quit museo")
            }
            .frame(height: PanelMetrics.rowHeight + MuseSpacing.xs)
        }
    }

    private func footWord(_ title: String) -> some View {
        Text(title)
            .font(MuseType.metaMedium)
            .foregroundStyle(MuseColor.moss600)
            .frame(height: PanelMetrics.rowHeight)
            .contentShape(Rectangle())
    }

    /// Opens the library, on this muse when there is one.
    private func open(_ id: UUID?) {
        if let id { library.selection = id }
        openWindow(id: LibraryWindow.id)
        NSApp.activate()
    }
}
