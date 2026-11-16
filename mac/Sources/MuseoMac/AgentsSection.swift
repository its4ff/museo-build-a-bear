import AppKit
import SwiftUI

/// "talk to": the AI apps a hold can start with ("hey claude, …"), each with its app's icon,
/// what to say, and what museo does there. Hover a row for its ×; "add an app" offers the
/// apps on this mac.
struct AgentsSection: View {
    @State private var commands = VoiceCommands.shared
    @State private var hovered: Agent?
    @State private var apps: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MuseEyebrow("talk to")
                .frame(height: 26)
            ForEach(commands.agents, id: \.self) { agent in
                line(agent)
            }
            // The caption and "add" share a row, as under the voice commands.
            HStack(spacing: MuseSpacing.sm) {
                Text("say “hey claude…” and your prompt.")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: 0)
                addMenu
            }
            .frame(height: 26)
        }
        .task { apps = VoiceCommands.appNames() }
    }

    private func line(_ agent: Agent) -> some View {
        // The phrase starts where the commands' phrases do.
        HStack(spacing: 5) {
            Group {
                if let icon = Self.icon(agent.app) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "bubble.left")
                        .font(MuseFont.symbol(12))
                        .foregroundStyle(MuseColor.ink55)
                }
            }
            .frame(width: 34, alignment: .leading)
            .accessibilityHidden(true)
            Text("“hey \(agent.say)”")
                .font(MuseFont.lora(14.5))
                .foregroundStyle(MuseColor.ink)
                .lineLimit(1)
            Text(does(agent))
                .font(MuseType.caption)
                .padding(.leading, 3)
                .foregroundStyle(MuseColor.ink55)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .overlay(alignment: .trailing) {
            Button {
                withAnimation(MuseMotion.gentle) { commands.removeAgent(agent) }
            } label: {
                Image(systemName: "xmark")
                    .font(MuseFont.symbol(9))
                    .foregroundStyle(MuseColor.ink55)
                    .frame(width: 22, height: 22)
                    .background(MuseColor.ground, in: Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovered == agent ? 1 : 0)
            .help("stop talking to \(agent.say) this way")
            .accessibilityLabel("remove hey \(agent.say)")
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = agent } else if hovered == agent { hovered = nil }
        }
    }

    /// "new chat", or "new chat in ChatGPT" for an app under another name. museo presses
    /// the keys, so they aren't shown (they're in commands.json).
    private func does(_ agent: Agent) -> String {
        let what = agent.newChat == nil ? "the open chat" : "new chat"
        return VoiceCommands.plain(agent.app) == agent.say ? what : "\(what) in \(agent.app)"
    }

    private var addMenu: some View {
        Menu {
            let known = AgentHandoff.known.filter { agent in
                AgentHandoff.appURL(agent.app) != nil && !commands.agents.contains { $0.say == agent.say }
            }
            if !known.isEmpty {
                Section("ai apps on this mac") {
                    ForEach(known, id: \.self) { agent in
                        Button("hey \(agent.say)") { withAnimation(MuseMotion.gentle) { commands.addAgent(app: agent.app, say: agent.say) } }
                    }
                }
            }
            Menu("another app") {
                ForEach(apps, id: \.self) { app in
                    Button(app) { withAnimation(MuseMotion.gentle) { commands.addAgent(app: app, say: nil) } }
                }
            }
        } label: {
            Text("add")
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss600)
        }
        .help("talk to another app")
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// The app's own icon, small.
    private static func icon(_ app: String) -> NSImage? {
        guard let url = AgentHandoff.appURL(app) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
