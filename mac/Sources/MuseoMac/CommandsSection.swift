import AppKit
import SwiftUI

/// The panel's voice commands, two to a row: what each presses on a small paper key, then
/// what to say, with a small moss dot for each other way to say it. Pointing at
/// one shows those ways under it. Clicking one opens it to change: its phrase, the other ways
/// to say it, what it does, or to remove it. "add" opens the same line, empty. What it does is
/// a pick (keys people reach for, an app on this mac, or a shortcut from the Shortcuts app), so
/// nobody types key names.
/// Everything lands in commands.json, which stays the place for anything rarer.
struct CommandsSection: View {
    @State private var commands = VoiceCommands.shared
    @State private var showsAll = false
    @State private var hovered: String?
    @State private var phrase = ""
    @State private var does: VoiceCommands.Command?
    /// The line to add or change one is out: "add", or a click on a command, opened it.
    @State private var isAdding = false
    /// The command being changed; nil while adding a new one.
    @State private var editing: VoiceCommands.Command?
    /// The other ways to say it, under the phrase.
    @State private var others: [String] = []
    @State private var anotherWay = ""
    @FocusState private var typingAnother: Bool
    #if DEBUG
    private var previewEditing: String?
    #endif
    @State private var showsApps = false
    @State private var apps: [String] = []
    @State private var shortcuts: [String] = []
    @FocusState private var typing: Bool

    init() {}

    #if DEBUG
    /// For `ScreenSheet`: drawn as if the pointer were on `phrase`.
    init(hovering phrase: String) {
        _hovered = State(initialValue: phrase)
    }

    /// For `ScreenSheet`: drawn with `phrase`'s command open to change.
    init(editing phrase: String) {
        previewEditing = phrase
    }
    #endif

    /// How many show before "show all": the built in list fits whole, with "open" as the
    /// eighth cell.
    private static let few = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grid
                // Its "also say" card is drawn over what comes after it.
                .zIndex(1)
            if commands.commands.count > Self.few {
                Button(showsAll ? "show fewer" : "show all \(commands.commands.count)") {
                    withAnimation(MuseMotion.gentle) { showsAll.toggle() }
                }
                .buttonStyle(.plain)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.moss600)
                .frame(height: PanelMetrics.wordButton)
            }
            if isAdding {
                adding
                    .padding(.top, MuseSpacing.xxs)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
            HStack(spacing: MuseSpacing.sm) {
                Text("end any hold with “send” to send it")
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: 0)
                Button(isAdding ? "cancel" : "add") {
                    if isAdding { close() } else { startAdding() }
                }
                .buttonStyle(.plain)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss600)
                .help(isAdding ? "keep it as it was" : "add a voice command")
            }
            .font(MuseType.caption)
            .frame(height: PanelMetrics.wordButton)
            AgentsSection()
                .padding(.top, MuseSpacing.md)
        }
        .padding(.bottom, MuseSpacing.xxs)
        .onAppear {
            _ = commands.current()
            #if DEBUG
            if let previewEditing, let command = commands.commands.first(where: { $0.say.first == previewEditing }) {
                startEditing(command)
            }
            #endif
        }
        .task {
            apps = VoiceCommands.appNames()
            shortcuts = await VoiceCommands.shortcutNames()
        }
    }

    // MARK: - The list

    private var shown: [VoiceCommands.Command] {
        showsAll ? commands.commands : Array(commands.commands.prefix(Self.few))
    }

    /// The commands two to a row, then "open". The ways to say a command it doesn't lead
    /// with show under the one you point at, drawn over the grid so the rows don't move.
    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 0, alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 0) {
            ForEach(shown, id: \.say) { command in
                cell(command)
                    .anchorPreference(key: HoveredCell.self, value: .bounds) { hovered == command.say.first ? [$0] : [] }
            }
            openCell
                .anchorPreference(key: HoveredCell.self, value: .bounds) { hovered == Self.openPhrase ? [$0] : [] }
        }
        .overlayPreferenceValue(HoveredCell.self) { anchors in
            GeometryReader { grid in
                if let anchor = anchors.first, let phrases = alsoSay(hovered), !phrases.isEmpty {
                    let frame = grid[anchor]
                    // Under the phrase in the left column; flush with the cell's end in the
                    // right one, so it never runs past the panel.
                    let isRight = frame.midX > grid.size.width / 2
                    AlsoSay(phrases: phrases)
                        .fixedSize()
                        .frame(width: grid.size.width, alignment: isRight ? .trailing : .leading)
                        .offset(x: isRight ? frame.maxX - grid.size.width : frame.minX + PanelMetrics.keyCapWidth - PanelMetrics.keyGap, y: frame.maxY + MuseSpacing.xxs / 2)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
        }
        .museAnimation(MuseMotion.snappy, value: hovered)
    }

    /// The ways to say the command under the pointer that it doesn't lead with.
    private func alsoSay(_ phrase: String?) -> [String]? {
        if phrase == Self.openPhrase { return ["switch to claude"] }
        return commands.commands.first { $0.say.first == phrase }.map { Array($0.say.dropFirst()) }
    }

    private static let openPhrase = "open claude"

    /// One command: its key, what you say, and a dot for each other way to say it.
    private func cell(_ command: VoiceCommands.Command) -> some View {
        let phrase = command.say.first ?? ""
        let others = command.say.dropFirst()
        return cellLabel(key: VoiceCommands.label(command), phrase: phrase, others: min(others.count, 3), isEditing: editing == command)
            .onTapGesture { startEditing(command) }
            .help("click to change it")
            .onHover { inside in
                if inside { hovered = phrase } else if hovered == phrase { hovered = nil }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(others.isEmpty ? phrase : "\(phrase), or \(others.joined(separator: ", "))")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("changes it")
    }

    /// The key, the phrase in Lora, the dots riding high after it; a quiet wash under the
    /// pointer, a moss line round the one being changed.
    private func cellLabel(key: String, phrase: String, others: Int, isEditing: Bool = false) -> some View {
        let isHovered = hovered == phrase
        return HStack(spacing: PanelMetrics.keyGap) {
            PanelKeyCap(key)
            Text("“\(phrase)”")
                .font(MuseFont.lora(PanelMetrics.phrase))
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
                .layoutPriority(1)
                // Drawn past the quote, so the dots take no room from the phrase.
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: PanelMetrics.alternateGap) {
                        ForEach(0..<others, id: \.self) { _ in
                            Circle()
                                .fill(isHovered ? MuseColor.moss600 : MuseColor.moss300)
                                .frame(width: PanelMetrics.alternateDot, height: PanelMetrics.alternateDot)
                        }
                    }
                    .fixedSize()
                    .alignmentGuide(.trailing) { $0[.leading] - PanelMetrics.alternateGap }
                    .padding(.top, MuseSpacing.xxs)
                    .accessibilityHidden(true)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: PanelMetrics.commandRow)
        .padding(.horizontal, MuseSpacing.xxs)
        .background {
            let shape = RoundedRectangle(cornerRadius: PanelMetrics.hoverRadius, style: .continuous)
            // Stops short of the cell's right edge: the columns touch, and a line drawn to
            // the edge (and the little it reaches past it) ran over the next command's key.
            Group {
                if isEditing {
                    shape.strokeBorder(MuseColor.moss600.opacity(0.7), lineWidth: 1)
                } else if isHovered {
                    shape.fill(DuoColor.hover)
                }
            }
            .padding(.trailing, MuseSpacing.sm)
        }
        .padding(.horizontal, -MuseSpacing.xxs)
        .contentShape(Rectangle())
    }

    /// "open" and any app's name ("open claude"): always there, nothing to add. A click shows
    /// the apps museo knows.
    private var openCell: some View {
        Button {
            showsApps.toggle()
        } label: {
            // Its one dot is "switch to".
            cellLabel(key: "app", phrase: Self.openPhrase, others: 1)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hovered = Self.openPhrase } else if hovered == Self.openPhrase { hovered = nil }
        }
        .help("say “open” or “switch to” and any of your \(apps.count) apps")
        .accessibilityLabel("open claude, or switch to claude. any of your \(apps.count) apps")
        .popover(isPresented: $showsApps, arrowEdge: .trailing) {
            AppsList(apps: apps)
        }
    }

    // MARK: - Adding or changing one

    /// The phrase, what it does and the check; then the other ways to say it, and "remove"
    /// when it's one that's there already.
    private var adding: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            HStack(spacing: 6) {
                // The panel's window follows a dark mac; the field's ink is set so it reads on paper.
                TextField("say", text: $phrase, prompt: Text("say…").foregroundStyle(MuseColor.ink55))
                    .textFieldStyle(.plain)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink)
                    .tint(MuseColor.moss)
                    .focused($typing)
                    .padding(.horizontal, MuseSpacing.xs)
                    .frame(height: PanelMetrics.field)
                    .panelField()
                    .onSubmit(save)
                    .onExitCommand(perform: close)
                doesPicker
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(MuseFont.symbol(10))
                        .foregroundStyle(canAdd ? MuseColor.ground : MuseColor.ink55)
                        .frame(width: PanelMetrics.field, height: PanelMetrics.field)
                        .background(canAdd ? AnyShapeStyle(MuseColor.primaryGradient) : AnyShapeStyle(MuseColor.ink.opacity(0.06)), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .help(editing == nil ? "add it" : "keep the change")
                .accessibilityLabel(editing == nil ? "add this command" : "keep the change")
            }
            MuseEyebrow("or say")
            WrappingRow(spacing: 5) {
                ForEach(others, id: \.self) { other in
                    HStack(spacing: 3) {
                        Text("“\(other)”")
                            .font(MuseFont.lora(12.5))
                            .foregroundStyle(MuseColor.ink)
                        Button {
                            others.removeAll { $0 == other }
                        } label: {
                            Image(systemName: "xmark")
                                .font(MuseFont.symbol(7))
                                .foregroundStyle(MuseColor.ink55)
                                .frame(width: 14, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("stop saying \(other)")
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 4)
                    .frame(height: 22)
                    .overlay(Capsule(style: .circular).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
                }
                TextField("another way", text: $anotherWay, prompt: Text("+ another way").foregroundStyle(MuseColor.moss600))
                    .textFieldStyle(.plain)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink)
                    .tint(MuseColor.moss)
                    .focused($typingAnother)
                    .frame(width: 96, height: 22)
                    .padding(.horizontal, 8)
                    .overlay(Capsule(style: .circular).strokeBorder(MuseColor.moss600.opacity(0.35), style: StrokeStyle(lineWidth: 0.75, dash: [2, 2])))
                    .onSubmit(keepAnotherWay)
                    .onExitCommand(perform: close)
            }
            if let editing {
                Button {
                    withAnimation(MuseMotion.gentle) {
                        commands.remove(editing)
                        close()
                    }
                } label: {
                    Text("remove this command")
                        .font(MuseType.captionMedium)
                        .foregroundStyle(MuseColor.clay)
                        .frame(height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(others.isEmpty ? "remove “\(editing.say.first ?? "")”" : "remove it and every way to say it")
            }
        }
        .padding(MuseSpacing.sm)
        .duoTileGlass(cornerRadius: MuseRadius.control)
    }

    private var canAdd: Bool {
        does != nil && !VoiceCommands.plain(phrase).isEmpty
    }

    private var doesPicker: some View {
        Menu {
            Section("keys") {
                ForEach(VoiceCommands.commonKeys, id: \.keys) { key in
                    Button("\(key.name) · \(VoiceCommands.symbols(key.keys))") {
                        pick(VoiceCommands.Command(say: [], keys: key.keys), suggesting: key.name)
                    }
                }
            }
            Menu("open an app") {
                ForEach(apps, id: \.self) { app in
                    Button(app) { pick(VoiceCommands.Command(say: [], open: app), suggesting: "open \(app.lowercased())") }
                }
            }
            Menu("run a shortcut") {
                if shortcuts.isEmpty {
                    Text("no shortcuts on this mac yet")
                }
                ForEach(shortcuts, id: \.self) { shortcut in
                    Button(shortcut) { pick(VoiceCommands.Command(say: [], shortcut: shortcut), suggesting: shortcut.lowercased()) }
                }
            }
            Divider()
            Button("keys of your own… (commands.json)") { commands.openFile() }
        } label: {
            HStack(spacing: 4) {
                Text(does.map(VoiceCommands.label) ?? "does…")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(MuseFont.symbol(8))
                    .foregroundStyle(MuseColor.ink55)
            }
            .font(MuseType.caption)
            .foregroundStyle(does == nil ? MuseColor.ink55 : MuseColor.ink)
            .padding(.horizontal, MuseSpacing.xs)
            .frame(height: PanelMetrics.field)
            .frame(maxWidth: 120)
            .panelField()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Picks what the new command does, and offers a phrase when none is typed yet.
    private func pick(_ command: VoiceCommands.Command, suggesting phrase: String) {
        does = command
        if VoiceCommands.plain(self.phrase).isEmpty { self.phrase = phrase.lowercased() }
        typing = true
    }

    private func startAdding() {
        close()
        withAnimation(MuseMotion.gentle) { isAdding = true }
        typing = true
    }

    /// Opens `command` to change, filled in.
    private func startEditing(_ command: VoiceCommands.Command) {
        editing = command
        phrase = command.say.first ?? ""
        others = Array(command.say.dropFirst())
        anotherWay = ""
        does = VoiceCommands.Command(say: [], keys: command.keys, open: command.open, shortcut: command.shortcut)
        withAnimation(MuseMotion.gentle) { isAdding = true }
        typing = true
    }

    /// "+ another way": a phrase typed there joins the others.
    private func keepAnotherWay() {
        let way = VoiceCommands.plain(anotherWay)
        if !way.isEmpty, way != VoiceCommands.plain(phrase), !others.map(VoiceCommands.plain).contains(way) {
            others.append(way)
        }
        anotherWay = ""
        typingAnother = true
    }

    /// Adds it, or keeps the change: the phrase first, then the other ways to say it.
    private func save() {
        guard canAdd, var command = does else { return }
        keepAnotherWay()
        command.say = [phrase] + others
        withAnimation(MuseMotion.gentle) {
            if let editing {
                commands.replace(editing, with: command)
            } else {
                commands.add(command)
            }
        }
        close()
    }

    private func close() {
        withAnimation(MuseMotion.gentle) { isAdding = false }
        editing = nil
        phrase = ""
        others = []
        anotherWay = ""
        does = nil
        typing = false
        typingAnother = false
    }
}

/// Lays its pieces out in rows, starting a new row when the next one won't fit.
private struct WrappingRow: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The command under the pointer, for the ways to say it it doesn't lead with.
private struct HoveredCell: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value += nextValue()
    }
}

/// "also say": the other ways to say the command under the pointer, on a small card.
private struct AlsoSay: View {
    let phrases: [String]

    private static let shape = RoundedRectangle(cornerRadius: MuseRadius.control, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs / 2) {
            MuseEyebrow("also say")
                .padding(.bottom, MuseSpacing.xxs / 2)
            ForEach(phrases, id: \.self) { phrase in
                Text("“\(phrase)”")
                    .font(MuseFont.lora(PanelMetrics.phrase))
                    .foregroundStyle(MuseColor.ink)
            }
        }
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.xs)
        // Warm paper with the glass's light top edge: it sits over the rows below, so it
        // stays opaque enough to read on.
        .background(DuoColor.cream, in: Self.shape)
        .overlay {
            Self.shape.strokeBorder(
                LinearGradient(colors: [DuoColor.edge, DuoColor.tileEdge], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .museElevation(.e2)
    }
}

/// The apps "open …" knows, by name with their icons. Nothing to change: every app on this mac
/// is in it, and a name heard close to one opens it.
private struct AppsList: View {
    let apps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            VStack(alignment: .leading, spacing: 3) {
                Text("your apps.")
                    .font(MuseFont.lora(18))
                    .foregroundStyle(MuseColor.ink)
                Text("say “open” or “switch to” and any of these. a name heard close to one opens it.")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(apps, id: \.self) { app in
                        HStack(spacing: MuseSpacing.xs) {
                            if let url = AgentHandoff.appURL(app) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .accessibilityHidden(true)
                            }
                            Text(app)
                                .font(MuseType.caption)
                                .foregroundStyle(MuseColor.ink)
                        }
                        .frame(height: 24)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: 280)
        }
        .padding(MuseSpacing.md)
        .frame(width: 250, alignment: .leading)
        .background { PanelGround() }
        .environment(\.colorScheme, .light)
    }
}
