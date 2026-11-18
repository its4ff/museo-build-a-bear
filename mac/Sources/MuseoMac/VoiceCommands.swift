import AppKit
import Carbon.HIToolbox
import Foundation
import Observation

/// Holds that do something instead of typing: say "next tab" and museo presses ⌃⇥; say
/// "send" and it presses return; end a hold with "send" or "and send" and its words are typed,
/// then sent.
///
/// Only a hold can be a command: you're holding the ring and talking to this mac right now.
/// Memory recordings land long after they were made, and are never typed or run. A command
/// is the whole hold, word for word (a hold that only says "next tab"), or the close or the
/// opening of one, set apart by a pause (`edge`). It never fires from the middle of a sentence. The list lives in
/// ~/Library/Application Support/museo mac/commands.json, written on first launch for people
/// to change: phrases to key presses, apps to open, or shortcuts to run.
@MainActor
@Observable
final class VoiceCommands {
    static let shared = VoiceCommands()

    /// Holds may be commands, and "… send" sends.
    var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.onKey) }
    }

    /// One command in the file.
    nonisolated struct Command: Codable, Equatable, Sendable {
        /// What to say, lowercase, without punctuation. Any of them.
        var say: [String]
        /// Keys to press: "return", "ctrl+tab", "cmd+shift+]".
        var keys: String?
        /// An app to open, by name: "Slack".
        var open: String?
        /// A shortcut from the Shortcuts app to run, by name.
        var shortcut: String?
    }

    /// What a hold's words turned out to be.
    nonisolated enum Reading: Equatable, Sendable {
        /// The whole hold was a command.
        case command(Command, said: String)
        /// Words, then return.
        case typeThenSend(String)
        /// "hey claude, …": the rest goes to that app's chat, sent when it ended with "send".
        case ask(Agent, String, send: Bool)
        /// Words, a pause, then a command: the words are typed, then it runs.
        case wordsThenCommand(String, Command, said: String)
        /// A command, a pause, then words: it runs, then the words are typed.
        case commandThenWords(Command, said: String, String)
        /// Just words.
        case words(String)
    }

    /// A command may close or open a hold of other words, set apart by a pause.
    var readsEdges: Bool {
        didSet { UserDefaults.standard.set(readsEdges, forKey: Self.edgesKey) }
    }
    private static let edgesKey = "museo.mac.edgeCommands"
    /// The longest command looked for at an edge, in words.
    private nonisolated static let edgeWords = 4

    private nonisolated struct File: Codable {
        var about: String
        var commands: [Command]
        /// The AI apps "hey …" talks to. Missing in older files: the ones on this mac then.
        var agents: [Agent]?
    }

    private(set) var commands: [Command] = VoiceCommands.builtIn
    /// "hey claude, …" and the like, in the order they're checked.
    private(set) var agents: [Agent] = AgentHandoff.installed
    @ObservationIgnored private var readAt: Date?

    private static let onKey = "museo.mac.voiceCommands"
    /// What comes before an app's name to open it, or bring it forward.
    static let openLeads = ["open ", "switch to "]
    /// "open museo": museo's own library.
    nonisolated static let ownApp = "museo"
    nonisolated static let ownNames: Set<String> = ["museo", "museo library", "the library", "your library", "my library"]

    var fileURL: URL { MacLibrary.shared.folder.appendingPathComponent("commands.json") }

    private init() {
        isOn = UserDefaults.standard.object(forKey: Self.onKey) as? Bool ?? true
        readsEdges = UserDefaults.standard.object(forKey: Self.edgesKey) as? Bool ?? true
    }

    // MARK: - Reading a hold

    /// What `words` mean. Off, everything is words.
    func read(_ words: String) -> Reading {
        guard isOn else { return .words(words) }
        refresh()
        let said = Self.plain(words)
        if let command = commands.first(where: { $0.say.map(Self.plain).contains(said) }) {
            return .command(command, said: said)
        }
        // "open slack" or "switch to slack", for any app on this mac, without a line in the
        // file. Opening an app that's already running brings it forward, so both are one thing.
        for lead in Self.openLeads where said.hasPrefix(lead) {
            let name = String(said.dropFirst(lead.count))
            // museo itself: its library, wherever museo lives (it isn't in Applications while
            // it's built here, and opening a menu bar app shows no window anyway).
            if Self.ownNames.contains(name) {
                return .command(Command(say: [said], open: Self.ownApp), said: said)
            }
            if let app = Self.app(named: name) {
                return .command(Command(say: [said], open: app), said: said)
            }
        }
        if let asked = ask(apple: words, local: nil) { return asked }
        if let kept = Self.beforeSend(words) {
            return .typeThenSend(kept)
        }
        return .words(words)
    }

    /// What a hold means, from both readings of it: apple dictation's (the island's, as you
    /// spoke) and the downloaded model's (heard again at the end, usually the better words).
    /// A command counts when either heard one: dictation hears short commands cleanly where a
    /// model can turn "send it" into "Sendet". The words typed are the model's, with its
    /// version of the closing "send" cut off.
    func read(apple: String, local: String?, pauses: HoldPauses? = nil) -> Reading {
        guard isOn else { return .words(local ?? apple) }
        for heard in [apple, local].compactMap({ $0 }) where !heard.isEmpty {
            if case .command = read(heard) { return read(heard) }
        }
        if let asked = ask(apple: apple, local: local) { return asked }
        guard let local, !local.isEmpty else {
            let reading = read(apple)
            if case .words = reading, let edge = edge(typed: apple, heard: [apple], pauses: pauses) { return edge }
            return reading
        }
        if let kept = Self.beforeSend(local) { return .typeThenSend(kept) }
        // Dictation heard a closing "send" the model mangled: cut the model's last word too.
        if Self.beforeSend(apple) != nil, let kept = Self.withoutLastWord(local) {
            return .typeThenSend(kept)
        }
        if let edge = edge(typed: local, heard: [local, apple], pauses: pauses) { return edge }
        return .words(local)
    }

    /// What the speech model should lean toward hearing, beyond your words: the apps "hey …"
    /// talks to, and the phrases of commands you added. museo's own commands are left out on
    /// purpose: they're everyday words ("send", "undo"), and leaning toward them would turn
    /// "i sent it" into "send it" in ordinary sentences.
    var vocabulary: [String] {
        guard isOn else { return [] }
        refresh()
        let own = Set(Self.builtIn.flatMap(\.say))
        return agents.map(\.say) + commands.flatMap(\.say).filter { !own.contains($0) }
    }

    // MARK: - A command at the edge of a hold

    /// A command that closes or opens a hold of other words: "…that's the plan. new tab",
    /// "new tab, flights to lisbon". It counts only when the hold's audio shows a pause
    /// setting it apart, and that stretch is no longer than the command takes to say. "new
    /// line" closes a hold without one: it only shapes the text, like a closing "send".
    ///
    /// `typed` is the reading whose words are typed (the model's); `heard` are the readings
    /// to look in, since dictation hears short commands cleanly where a model can mangle
    /// them. Found only in another reading, as many words are cut from `typed`.
    func edge(typed: String, heard: [String], pauses: HoldPauses?) -> Reading? {
        guard readsEdges else { return nil }
        let typedWords = typed.split(whereSeparator: \.isWhitespace).map(String.init)
        for reading in heard where !reading.isEmpty {
            let words = reading.split(whereSeparator: \.isWhitespace).map(String.init)
            guard words.count >= 2 else { continue }
            // The longest phrase first, so "switch tab" wins over a "tab" of someone's own.
            for count in stride(from: min(Self.edgeWords, words.count - 1), through: 1, by: -1) where typedWords.count > count {
                if case .command(let command, let said) = read(words.suffix(count).joined(separator: " ")),
                   command.keys != "return",
                   Self.shapesText(command) || HoldPauses.fits(pauses?.trailing, words: count) {
                    let kept = typedWords.dropLast(count).joined(separator: " ")
                        .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:\n"))
                    if !Self.plain(kept).isEmpty { return .wordsThenCommand(kept, command, said: said) }
                }
                if case .command(let command, let said) = read(words.prefix(count).joined(separator: " ")),
                   command.keys != "return", !Self.shapesText(command),
                   HoldPauses.fits(pauses?.leading, words: count),
                   let rest = Self.dropping(count, from: typed) {
                    return .commandThenWords(command, said: said, rest)
                }
            }
        }
        return nil
    }

    /// Only moves the caret down the page: safe to run at the close of a hold with no pause.
    private nonisolated static func shapesText(_ command: Command) -> Bool {
        command.keys == "shift+return"
    }

    /// "hey claude, …" from either reading: the model's words after the greeting when it
    /// heard it too, else the model's words without as many words as dictation's greeting
    /// took (dictation heard "hey claude", the model "Hey Clyde"). Nil when neither starts
    /// with one of `agents`.
    func ask(apple: String, local: String?) -> Reading? {
        let fromApple = AgentHandoff.ask(in: apple, agents: agents)
        let fromLocal = local.flatMap { AgentHandoff.ask(in: $0, agents: agents) }
        guard let agent = fromLocal?.agent ?? fromApple?.agent else { return nil }
        let localRest = fromLocal?.rest ?? fromApple.flatMap { apple in local.flatMap { Self.dropping(apple.greeting, from: $0) } }
        guard let rest = localRest ?? fromApple?.rest else { return nil }
        if let kept = Self.beforeSend(rest) { return .ask(agent, kept, send: true) }
        if localRest != nil, let appleRest = fromApple?.rest, Self.beforeSend(appleRest) != nil, let kept = Self.withoutLastWord(rest) {
            return .ask(agent, kept, send: true)
        }
        return .ask(agent, rest, send: false)
    }

    /// `words` without its first `count` words, or nil when that's all there is.
    nonisolated static func dropping(_ count: Int, from words: String) -> String? {
        let rest = words.split(separator: " ", omittingEmptySubsequences: true).dropFirst(count).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.:!?"))
        return rest.isEmpty ? nil : rest.prefix(1).uppercased() + rest.dropFirst()
    }

    // MARK: - The AI apps

    /// Adds `app` to "talk to", said as `say` or its name ("hey perplexity"), with the keys
    /// museo knows for it or ⌘N.
    func addAgent(app: String, say: String?) {
        refresh()
        let say = Self.plain(say ?? app)
        guard !say.isEmpty, !agents.contains(where: { $0.say == say }) else { return }
        let known = AgentHandoff.known.first { $0.say == say }
        agents.append(known ?? Agent(say: say, app: app, newChat: "cmd+n", heardAs: nil))
        save()
    }

    func removeAgent(_ agent: Agent) {
        refresh()
        agents.removeAll { $0 == agent }
        save()
    }

    /// `words` without its last word (and an "and" before it), or nil when that's all there is.
    nonisolated static func withoutLastWord(_ words: String) -> String? {
        let pattern = #"[\s,;:]*(?:\band\s+)?\S+[\s.!?,]*$"#
        guard let range = words.range(of: pattern, options: .regularExpression) else { return nil }
        let kept = words[..<range.lowerBound].trimmingCharacters(in: CharacterSet(charactersIn: " ,;:\n"))
        return kept.isEmpty ? nil : kept
    }

    /// The words before a closing "send" ("and send", "send it"), or nil when the hold
    /// doesn't end that way or is nothing else.
    nonisolated static func beforeSend(_ words: String) -> String? {
        let pattern = #"[\s,;:]*(?:\band\s+)?\bsend(?:\s+it)?[\s.!?,]*$"#
        guard let range = words.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let kept = words[..<range.lowerBound].trimmingCharacters(in: CharacterSet(charactersIn: " ,;:\n"))
        return kept.isEmpty ? nil : kept
    }

    /// Lowercase, no punctuation, single spaces: "Next tab." is "next tab".
    nonisolated static func plain(_ text: String) -> String {
        let kept = text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    // MARK: - Running one

    /// Does `command`. False when nothing could happen (museo may not press keys, the app or
    /// shortcut isn't here).
    @discardableResult
    func run(_ command: Command) -> Bool {
        if let keys = command.keys {
            guard let (key, modifiers) = Self.chord(keys) else {
                print("[museo][command] can't press \"\(keys)\"")
                return false
            }
            return TextInserter.press(key, holding: modifiers)
        }
        if command.open == Self.ownApp {
            LibraryOpener.open()
            return true
        }
        if let app = command.open {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", app]
            do {
                try process.run()
                return true
            } catch {
                return false
            }
        }
        if let shortcut = command.shortcut {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", shortcut]
            do {
                try process.run()
                return true
            } catch {
                return false
            }
        }
        return false
    }

    /// "cmd+shift+]" as a key and the modifiers to hold.
    nonisolated static func chord(_ text: String) -> (CGKeyCode, [CGKeyCode])? {
        let parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = parts.last, let key = keys[last] else { return nil }
        var modifiers: [CGKeyCode] = []
        for part in parts.dropLast() {
            guard let modifier = Self.modifiers[part] else { return nil }
            modifiers.append(modifier)
        }
        return (key, modifiers)
    }

    private nonisolated static let modifiers: [String: CGKeyCode] = [
        "cmd": CGKeyCode(kVK_Command), "command": CGKeyCode(kVK_Command),
        "shift": CGKeyCode(kVK_Shift),
        "opt": CGKeyCode(kVK_Option), "option": CGKeyCode(kVK_Option), "alt": CGKeyCode(kVK_Option),
        "ctrl": CGKeyCode(kVK_Control), "control": CGKeyCode(kVK_Control),
    ]

    private nonisolated static let keys: [String: CGKeyCode] = {
        var keys: [String: CGKeyCode] = [
            "return": CGKeyCode(kVK_Return), "enter": CGKeyCode(kVK_Return),
            "tab": CGKeyCode(kVK_Tab), "space": CGKeyCode(kVK_Space),
            "delete": CGKeyCode(kVK_Delete), "forwarddelete": CGKeyCode(kVK_ForwardDelete),
            "escape": CGKeyCode(kVK_Escape), "esc": CGKeyCode(kVK_Escape),
            "left": CGKeyCode(kVK_LeftArrow), "right": CGKeyCode(kVK_RightArrow),
            "up": CGKeyCode(kVK_UpArrow), "down": CGKeyCode(kVK_DownArrow),
            "pageup": CGKeyCode(kVK_PageUp), "pagedown": CGKeyCode(kVK_PageDown),
            "home": CGKeyCode(kVK_Home), "end": CGKeyCode(kVK_End),
            "[": CGKeyCode(kVK_ANSI_LeftBracket), "]": CGKeyCode(kVK_ANSI_RightBracket),
            ",": CGKeyCode(kVK_ANSI_Comma), ".": CGKeyCode(kVK_ANSI_Period),
            "/": CGKeyCode(kVK_ANSI_Slash), "-": CGKeyCode(kVK_ANSI_Minus), "=": CGKeyCode(kVK_ANSI_Equal),
            "`": CGKeyCode(kVK_ANSI_Grave),
        ]
        let letters: [(String, Int)] = [
            ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D), ("e", kVK_ANSI_E),
            ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H), ("i", kVK_ANSI_I), ("j", kVK_ANSI_J),
            ("k", kVK_ANSI_K), ("l", kVK_ANSI_L), ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O),
            ("p", kVK_ANSI_P), ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
            ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X), ("y", kVK_ANSI_Y),
            ("z", kVK_ANSI_Z), ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
            ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7), ("8", kVK_ANSI_8),
            ("9", kVK_ANSI_9),
        ]
        for (name, code) in letters { keys[name] = CGKeyCode(code) }
        return keys
    }()

    // MARK: - Apps

    /// The app called `name` on this mac ("slack" finds Slack), or the one whose name is
    /// very close to it, the way a recognizer mishears one ("figment" finds Figma, "granola
    /// bar" finds Granola). Nil when nothing is close enough: "open the door" stays words.
    nonisolated static func app(named name: String) -> String? {
        var wanted = plain(name)
        if wanted.hasSuffix(" app") { wanted = String(wanted.dropLast(4)) }
        guard !wanted.isEmpty, wanted.split(separator: " ").count <= 3 else { return nil }
        let apps = appNames()
        if let exact = apps.first(where: { plain($0) == wanted }) { return exact }
        // The name without its maker: "settings" for System Settings, "chrome" for Google Chrome.
        let unmade = apps.filter { app in
            let words = plain(app).split(separator: " ")
            return words.count >= 2 && words.dropFirst().joined(separator: " ") == wanted
        }
        if unmade.count == 1 { return unmade[0] }
        let squeezed = wanted.replacingOccurrences(of: " ", with: "")
        var best: (app: String, score: Double)?
        for app in apps {
            let title = plain(app)
            let name = title.replacingOccurrences(of: " ", with: "")
            // Short names ("tv", "arc") only by their exact name: too easy to hear by accident.
            guard name.count >= 4 else { continue }
            var score = similarity(squeezed, name)
            // The app's name and one word more: "granola bar".
            if wanted.hasPrefix(title + " "), wanted.split(separator: " ").count == title.split(separator: " ").count + 1 {
                score = max(score, 0.9)
            }
            if score > (best?.score ?? 0) { best = (app, score) }
        }
        guard let best, best.score >= closeEnough else { return nil }
        return best.app
    }

    /// How alike a heard name and an app's must be (Jaro-Winkler) to open it.
    nonisolated static let closeEnough = 0.86

    /// Jaro-Winkler similarity, 0 to 1: matching letters near each other, with extra weight on
    /// a shared start, which is how names get misheard ("figment", "figma").
    nonisolated static func similarity(_ a: String, _ b: String) -> Double {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let reach = max(max(a.count, b.count) / 2 - 1, 0)
        var aMatched = [Bool](repeating: false, count: a.count)
        var bMatched = [Bool](repeating: false, count: b.count)
        var matches = 0
        for i in a.indices {
            let low = max(0, i - reach), high = min(b.count - 1, i + reach)
            guard low <= high else { continue }
            for j in low...high where !bMatched[j] && a[i] == b[j] {
                aMatched[i] = true
                bMatched[j] = true
                matches += 1
                break
            }
        }
        guard matches > 0 else { return 0 }
        var transpositions = 0, k = 0
        for i in a.indices where aMatched[i] {
            while !bMatched[k] { k += 1 }
            if a[i] != b[k] { transpositions += 1 }
            k += 1
        }
        let m = Double(matches)
        let jaro = (m / Double(a.count) + m / Double(b.count) + (m - Double(transpositions / 2)) / m) / 3
        let prefix = zip(a, b).prefix(4).prefix { $0 == $1 }.count
        return jaro + Double(prefix) * 0.1 * (1 - jaro)
    }

    // MARK: - The file

    /// Writes the file the first time, and reads it again when it has changed.
    private func refresh() {
        let manager = FileManager.default
        if !manager.fileExists(atPath: fileURL.path) {
            let file = File(about: Self.about, commands: Self.builtIn, agents: AgentHandoff.installed)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            if let data = try? encoder.encode(file) { try? data.write(to: fileURL, options: .atomic) }
        }
        let changed = (try? manager.attributesOfItem(atPath: fileURL.path)[.modificationDate]) as? Date
        guard let changed, changed != readAt else { return }
        readAt = changed
        do {
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: fileURL))
            commands = file.commands
            agents = file.agents ?? AgentHandoff.installed
            if file.agents == nil { save() }
            if Self.retired.contains(commands) {
                commands = Self.builtIn
                save()
                print("[museo][command] commands.json had an old list of museo's: now the current one")
                return
            }
            print("[museo][command] \(commands.count) commands from commands.json")
        } catch {
            commands = Self.builtIn
            print("[museo][command] commands.json didn't read, using the built in ones:", error.localizedDescription)
        }
    }

    // MARK: - Changing the list

    /// The list as it stands, read from the file first.
    func current() -> [Command] {
        refresh()
        return commands
    }

    /// Adds `command` (or more phrases for what an existing one does) and saves.
    func add(_ command: Command) {
        refresh()
        let phrases = command.say.map(Self.plain).filter { !$0.isEmpty }
        guard !phrases.isEmpty else { return }
        // A phrase belongs to one command only: the new one takes it.
        for index in commands.indices { commands[index].say.removeAll { phrases.contains(Self.plain($0)) } }
        commands.removeAll { $0.say.isEmpty }
        if let index = commands.firstIndex(where: { $0.keys == command.keys && $0.open == command.open && $0.shortcut == command.shortcut }) {
            commands[index].say.append(contentsOf: phrases)
        } else {
            var command = command
            command.say = phrases
            commands.append(command)
        }
        save()
    }

    /// Puts `new` where `old` was: its phrases (the first leads), and what it does. A phrase
    /// another command had moves to this one. No phrases left takes it out.
    func replace(_ old: Command, with new: Command) {
        refresh()
        var phrases: [String] = []
        for phrase in new.say.map(Self.plain) where !phrase.isEmpty && !phrases.contains(phrase) {
            phrases.append(phrase)
        }
        guard let index = commands.firstIndex(of: old) else {
            add(new)
            return
        }
        var updated = new
        updated.say = phrases
        commands[index] = updated
        for other in commands.indices where other != index {
            commands[other].say.removeAll { phrases.contains(Self.plain($0)) }
        }
        commands.removeAll { $0.say.isEmpty }
        save()
    }

    /// Takes `command` out, with every way of saying it.
    func remove(_ command: Command) {
        refresh()
        commands.removeAll { $0 == command }
        save()
    }

    /// Puts the built in list back.
    func reset() {
        commands = Self.builtIn
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(File(about: Self.about, commands: commands, agents: agents)) else { return }
        try? data.write(to: fileURL, options: .atomic)
        readAt = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate]) as? Date
    }

    // MARK: - Saying what one does

    /// What a command does, short: "↩", "⌃⇥", "opens Notes", "runs Focus".
    nonisolated static func label(_ command: Command) -> String {
        if let keys = command.keys { return symbols(keys) }
        if let app = command.open { return "opens \(app)" }
        if let shortcut = command.shortcut { return "runs \(shortcut)" }
        return ""
    }

    /// "cmd+shift+z" as ⇧⌘Z, the way menus write it.
    nonisolated static func symbols(_ keys: String) -> String {
        let parts = keys.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last else { return keys }
        let order: [(String, [String])] = [("⌃", ["ctrl", "control"]), ("⌥", ["opt", "option", "alt"]), ("⇧", ["shift"]), ("⌘", ["cmd", "command"])]
        let held = order.filter { !Set($1).isDisjoint(with: parts) }.map(\.0).joined()
        let names: [String: String] = [
            "return": "↩", "enter": "↩", "tab": "⇥", "space": "space", "delete": "⌫", "forwarddelete": "⌦",
            "escape": "esc", "esc": "esc", "left": "←", "right": "→", "up": "↑", "down": "↓",
            "pageup": "page up", "pagedown": "page down", "home": "home", "end": "end",
        ]
        return held + (names[key] ?? key.uppercased())
    }

    /// Keys people reach for, to pick from when adding one.
    nonisolated static let commonKeys: [(name: String, keys: String)] = [
        ("send (return)", "return"), ("new line", "shift+return"),
        ("next tab", "ctrl+tab"), ("last tab", "ctrl+shift+tab"), ("new tab", "cmd+t"), ("close tab", "cmd+w"),
        ("back", "cmd+["), ("forward", "cmd+]"), ("undo", "cmd+z"), ("redo", "cmd+shift+z"),
        ("select all", "cmd+a"), ("copy", "cmd+c"), ("paste", "cmd+v"), ("find", "cmd+f"),
        ("switch app", "cmd+tab"), ("escape", "escape"), ("page down", "pagedown"), ("page up", "pageup"),
    ]

    /// The shortcuts in the Shortcuts app, by name.
    nonisolated static func shortcutNames() async -> [String] {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).sorted()
        }.value
    }

    /// The apps on this mac, by name.
    nonisolated static func appNames() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folders = ["/Applications", "/System/Applications", "/System/Applications/Utilities", "\(home)/Applications"]
        let names = folders.flatMap { (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? [] }
            .filter { $0.hasSuffix(".app") }
            .map { String($0.dropLast(4)) }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Opens the file in the app that edits json, writing it first if it isn't there.
    func openFile() {
        refresh()
        NSWorkspace.shared.open(fileURL)
    }

    private nonisolated static let about = "hold the ring and say one of these, and nothing else: museo does it instead of typing. say: what to say, lowercase. then one of keys (\"cmd+shift+]\"), open (an app's name) or shortcut (a shortcut's name). \"open\" and an app's name works for any app without a line here. end any hold with \"send\" or \"and send\" to type it, then press return. agents: start a hold with \"hey\" and one of their names (\"hey claude, …\") and the rest goes to that app: say is the name, app the app's name, newChat the keys for a new chat."

    /// The few people say, one way to do each thing. "switch tab" is ⌃⇥: in Arc that's the tab
    /// you were just on, in Chrome and Safari the next one. "switch app" is ⌘⇥, the app you
    /// were just in. "open" and any app's name works without a line here.
    nonisolated static let builtIn: [Command] = [
        Command(say: ["send", "send it", "and send", "enter", "press enter"], keys: "return"),
        Command(say: ["new line", "next line"], keys: "shift+return"),
        Command(say: ["switch tab", "last tab"], keys: "ctrl+tab"),
        Command(say: ["switch app", "last app"], keys: "cmd+tab"),
        Command(say: ["undo", "undo that"], keys: "cmd+z"),
        Command(say: ["new tab"], keys: "cmd+t"),
        Command(say: ["close tab"], keys: "cmd+w"),
    ]

    /// Lists museo once wrote as its own: a file still holding one of these, exactly, was
    /// never edited, and gets the list above instead.
    private nonisolated static let retired: [[Command]] = [
        [
            Command(say: ["send", "send it", "and send", "press enter", "press return"], keys: "return"),
            Command(say: ["new line"], keys: "shift+return"),
            Command(say: ["next tab"], keys: "ctrl+tab"),
            Command(say: ["last tab", "previous tab"], keys: "ctrl+shift+tab"),
            Command(say: ["new tab"], keys: "cmd+t"),
            Command(say: ["close tab"], keys: "cmd+w"),
            Command(say: ["go back"], keys: "cmd+["),
            Command(say: ["go forward"], keys: "cmd+]"),
            Command(say: ["undo", "undo that"], keys: "cmd+z"),
            Command(say: ["redo"], keys: "cmd+shift+z"),
            Command(say: ["select all"], keys: "cmd+a"),
            Command(say: ["copy that"], keys: "cmd+c"),
            Command(say: ["paste", "paste that"], keys: "cmd+v"),
            Command(say: ["switch app", "last app"], keys: "cmd+tab"),
            Command(say: ["page down", "scroll down"], keys: "pagedown"),
            Command(say: ["page up", "scroll up"], keys: "pageup"),
            Command(say: ["escape", "never mind"], keys: "escape"),
        ],
        [
            Command(say: ["send", "send it", "and send", "enter", "press enter"], keys: "return"),
            Command(say: ["new line", "next line"], keys: "shift+return"),
            Command(say: ["switch tab", "other tab", "last tab", "next tab"], keys: "ctrl+tab"),
            Command(say: ["switch app", "other app", "last app"], keys: "cmd+tab"),
            Command(say: ["undo", "undo that", "scratch that"], keys: "cmd+z"),
            Command(say: ["new tab"], keys: "cmd+t"),
            Command(say: ["close tab"], keys: "cmd+w"),
        ],
    ]
}
