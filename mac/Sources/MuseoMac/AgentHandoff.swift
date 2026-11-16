import AppKit
import Carbon.HIToolbox
import Foundation

/// An AI app museo can talk to: "hey claude, …" sends the rest of the hold there.
nonisolated struct Agent: Codable, Equatable, Hashable, Sendable {
    /// The name you say after "hey", lowercase: "claude", "chatgpt".
    var say: String
    /// The app, by name: "Claude".
    var app: String
    /// Keys for a new chat ("cmd+n"); nil types into whatever chat is open.
    var newChat: String?
    /// How the name is often heard, so those count too: "cloud" for "claude".
    var heardAs: [String]?
}

/// "hey claude, …", "hey cursor, …": the rest of the hold goes to that app.
///
/// museo brings the app forward, starts a new chat with the app's own keys and types the
/// words there, as it types anywhere (no link, so no app's caution screen for links). Already
/// in that app, it types into the chat you're in. End the hold with "send" and return is
/// pressed too.
enum AgentHandoff {
    /// AI apps museo knows the keys for. The panel offers the ones on this mac.
    static let known: [Agent] = [
        Agent(say: "claude", app: "Claude", newChat: "cmd+n", heardAs: ["claud", "cloud", "clod", "clyde"]),
        Agent(say: "chatgpt", app: "ChatGPT", newChat: "cmd+n", heardAs: ["chat gpt", "chat g p t", "chat gbt", "chatty"]),
        Agent(say: "codex", app: "ChatGPT", newChat: "cmd+n", heardAs: ["codecs", "code x"]),
        Agent(say: "cursor", app: "Cursor", newChat: "cmd+n", heardAs: ["curser"]),
        Agent(say: "grok", app: "Grok", newChat: "cmd+n", heardAs: ["groc", "grock", "grog"]),
        Agent(say: "perplexity", app: "Perplexity", newChat: "cmd+n", heardAs: nil),
    ]

    /// The ones to start with, when their app is on this mac: the two that take a typed chat
    /// cleanly. The rest are a click away in "add".
    static var installed: [Agent] {
        known.filter { ["claude", "cursor"].contains($0.say) && appURL($0.app) != nil }
    }

    /// Where `name`'s app is, or nil.
    nonisolated static func appURL(_ name: String) -> URL? {
        let wanted = VoiceCommands.plain(name)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for folder in ["/Applications", "/System/Applications", "/System/Applications/Utilities", "\(home)/Applications"] {
            let apps = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            if let app = apps.first(where: { $0.hasSuffix(".app") && VoiceCommands.plain(String($0.dropLast(4))) == wanted }) {
                return URL(fileURLWithPath: folder).appendingPathComponent(app)
            }
        }
        return nil
    }

    // MARK: - Hearing it

    /// The agent a hold starts with ("hey claude", "hey chat gpt"), how many words that
    /// greeting took, and the words after it. Nil when it doesn't start that way, or there's
    /// nothing after.
    nonisolated static func ask(in words: String, agents: [Agent]) -> (agent: Agent, greeting: Int, rest: String)? {
        for agent in agents {
            let names = ([agent.say] + (agent.heardAs ?? []))
                .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: #"[\s-]*"#) }
                .joined(separator: "|")
            let pattern = #"^\s*(?:hey|hi|okay|ok)[\s,]+(?:"# + names + #")\b[\s,.:!?]*"#
            guard let range = words.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            let rest = String(words[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rest.isEmpty else { return nil }
            let greeting = words[..<range.upperBound].split(whereSeparator: { $0 == " " || $0 == "," }).count
            // "Hey Claude, what's…" leaves "what's…": give it its capital back.
            return (agent, greeting, rest.prefix(1).uppercased() + rest.dropFirst())
        }
        return nil
    }

    // MARK: - Handing it over

    /// Types `text` into `agent`'s app (a new chat unless it's already in front), and sends it
    /// when `send`. False when the app isn't here or didn't come forward.
    @MainActor
    static func hand(_ text: String, to agent: Agent, send: Bool) async -> Bool {
        guard let url = appURL(agent.app) else { return false }
        let alreadyThere = NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL == url.standardizedFileURL
        if !alreadyThere {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            // Wait for it to be in front, a second and a half at most.
            for _ in 0..<30 where NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL != url.standardizedFileURL {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL == url.standardizedFileURL else { return false }
            if let keys = agent.newChat, let (key, modifiers) = VoiceCommands.chord(keys) {
                TextInserter.press(key, holding: modifiers)
            }
            // A moment for the new chat's field to take the cursor.
            try? await Task.sleep(for: .milliseconds(600))
        }
        guard TextInserter.insert(alreadyThere && !send ? text + " " : text) != .copied else { return false }
        if send {
            try? await Task.sleep(for: .milliseconds(300))
            TextInserter.press(CGKeyCode(kVK_Return))
        }
        return true
    }
}
