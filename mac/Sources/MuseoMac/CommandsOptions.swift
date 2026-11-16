#if DEBUG
import AppKit
import SwiftUI

/// Four ways to draw the panel's voice commands, side by side in one png, for choosing:
/// `museo -renderCommandOptions /some/folder`. Not used by the app.
enum CommandsOptions {
    static func write(to folder: URL) {
        let commands = VoiceCommands.builtIn
        let sheet = HStack(alignment: .top, spacing: 28) {
            option("c1 · keycaps", "phrase on the left, each key its own cap, like raycast") { KeycapList(commands: commands) }
            option("c2 · chip first", "the island's look: what it does, then what you say") { ChipFirstList(commands: commands) }
            option("c3 · island card", "the list is a small notch island") { IslandCardList(commands: commands) }
            option("c4 · tiles", "two columns, compact") { TileList(commands: commands) }
        }
        .padding(28)
        .background(Color(white: 0.86))
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        if let image = renderer.cgImage {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                .write(to: folder.appendingPathComponent("commands-options.png"))
            print("[museo][mac] wrote commands-options.png")
        }
    }

    private static func option(_ title: String, _ note: String, @ViewBuilder _ list: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(MuseType.metaMedium).foregroundStyle(MuseColor.ink)
                Text(note).font(MuseType.caption).foregroundStyle(MuseColor.ink55)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("voice commands").font(MuseType.body).foregroundStyle(MuseColor.ink)
                    Spacer()
                    Capsule().fill(MuseColor.moss).frame(width: 30, height: 18)
                        .overlay(alignment: .trailing) { Circle().fill(.white).frame(width: 15).padding(1.5) }
                }
                .frame(height: 36)
                list()
            }
            .padding(MuseSpacing.md)
            .frame(width: 310, alignment: .top)
            .background { MuseBackground() }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Pieces

/// One key as a cap: a small rounded square, raised a hair off the paper.
private struct Keycap: View {
    let key: String
    var dark = false

    var body: some View {
        Text(key)
            .font(MuseType.captionMedium)
            .foregroundStyle(dark ? MuseColor.ground : MuseColor.ink70)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, key.count > 1 ? 5 : 0)
            .background(dark ? Color.white.opacity(0.1) : MuseColor.raised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(dark ? Color.white.opacity(0.18) : MuseColor.ink.opacity(0.12), lineWidth: 0.75))
            .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 0, y: 1)
    }
}

/// "cmd+shift+t" as caps: ⌘ ⇧ T.
private func caps(_ command: VoiceCommands.Command) -> [String] {
    guard let keys = command.keys else { return [VoiceCommands.label(command)] }
    let label = VoiceCommands.symbols(keys)
    let held = label.prefix { "⌃⌥⇧⌘".contains($0) }.map(String.init)
    let rest = String(label.dropFirst(held.count))
    return held + [rest]
}

/// The island's chip: keys in one outlined capsule.
private struct Chip: View {
    let text: String
    var dark = false

    var body: some View {
        Text(text)
            .font(MuseType.captionMedium)
            .foregroundStyle(dark ? MuseColor.ground : MuseColor.ink70)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .overlay(Capsule().strokeBorder((dark ? MuseColor.ground : MuseColor.ink).opacity(dark ? 0.45 : 0.22), lineWidth: 1))
            .fixedSize()
    }
}

private struct AddLine: View {
    var dark = false

    var body: some View {
        HStack(spacing: 6) {
            Text("say…")
                .font(MuseType.caption)
                .foregroundStyle(dark ? MuseColor.ground.opacity(0.5) : MuseColor.ink55)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .background(dark ? Color.white.opacity(0.08) : MuseColor.composer.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(dark ? Color.white.opacity(0.14) : MuseColor.hairline, lineWidth: 0.75))
            HStack(spacing: 4) {
                Text("does…")
                Image(systemName: "chevron.up.chevron.down").font(MuseFont.symbol(8))
            }
            .font(MuseType.caption)
            .foregroundStyle(dark ? MuseColor.ground.opacity(0.6) : MuseColor.ink55)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(dark ? Color.white.opacity(0.08) : MuseColor.composer.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(dark ? Color.white.opacity(0.14) : MuseColor.hairline, lineWidth: 0.75))
            Text("add").font(MuseType.captionMedium).foregroundStyle(dark ? MuseColor.ground.opacity(0.5) : MuseColor.ink55)
        }
    }
}

// MARK: - c1 · keycaps

private struct KeycapList: View {
    let commands: [VoiceCommands.Command]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commands, id: \.say) { command in
                HStack(spacing: MuseSpacing.xs) {
                    Text("“\(command.say[0])”").font(MuseFont.lora(14)).foregroundStyle(MuseColor.ink)
                    if command.say.count > 1 {
                        Text("+\(command.say.count - 1)").font(MuseType.caption).foregroundStyle(MuseColor.ink55)
                    }
                    Spacer()
                    HStack(spacing: 3) { ForEach(caps(command), id: \.self) { Keycap(key: $0) } }
                }
                .frame(height: 28)
            }
            HStack {
                Text("“open claude”").font(MuseFont.lora(14)).foregroundStyle(MuseColor.ink)
                Spacer()
                Text("any app").font(MuseType.caption).foregroundStyle(MuseColor.ink55)
            }
            .frame(height: 28)
            AddLine().padding(.top, 6)
        }
    }
}

// MARK: - c2 · chip first

private struct ChipFirstList: View {
    let commands: [VoiceCommands.Command]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commands, id: \.say) { command in
                HStack(spacing: MuseSpacing.sm) {
                    Chip(text: VoiceCommands.label(command))
                        .frame(width: 44, alignment: .leading)
                    Text(command.say[0]).font(MuseFont.lora(14.5)).foregroundStyle(MuseColor.ink)
                    Text(command.say.dropFirst().prefix(2).joined(separator: " · "))
                        .font(MuseType.caption).foregroundStyle(MuseColor.ink55).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(height: 28)
            }
            HStack(spacing: MuseSpacing.sm) {
                Chip(text: "app").frame(width: 44, alignment: .leading)
                Text("open claude").font(MuseFont.lora(14.5)).foregroundStyle(MuseColor.ink)
                Text("or any app").font(MuseType.caption).foregroundStyle(MuseColor.ink55)
                Spacer(minLength: 0)
            }
            .frame(height: 28)
            AddLine().padding(.top, 6)
        }
    }
}

// MARK: - c3 · island card

private struct IslandCardList: View {
    let commands: [VoiceCommands.Command]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commands, id: \.say) { command in
                HStack(spacing: MuseSpacing.sm) {
                    Chip(text: VoiceCommands.label(command), dark: true)
                        .frame(width: 44, alignment: .leading)
                    Text(command.say[0]).font(MuseFont.lora(14.5)).foregroundStyle(MuseColor.ground)
                    Spacer(minLength: 0)
                    if command.say.count > 1 {
                        Text("+\(command.say.count - 1)").font(MuseType.caption).foregroundStyle(MuseColor.ground.opacity(0.45))
                    }
                }
                .frame(height: 28)
            }
            HStack(spacing: MuseSpacing.sm) {
                Chip(text: "app", dark: true).frame(width: 44, alignment: .leading)
                Text("open claude").font(MuseFont.lora(14.5)).foregroundStyle(MuseColor.ground)
                Spacer(minLength: 0)
                Text("any app").font(MuseType.caption).foregroundStyle(MuseColor.ground.opacity(0.45))
            }
            .frame(height: 28)
            AddLine(dark: true).padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, MuseSpacing.xs)
    }
}

// MARK: - c4 · tiles

private struct TileList: View {
    let commands: [VoiceCommands.Command]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(commands, id: \.say) { command in tile(VoiceCommands.label(command), command.say[0]) }
                tile("app", "open claude")
            }
            AddLine()
        }
    }

    private func tile(_ keys: String, _ phrase: String) -> some View {
        HStack(spacing: 6) {
            Text(phrase).font(MuseFont.lora(13.5)).foregroundStyle(MuseColor.ink).lineLimit(1)
            Spacer(minLength: 2)
            Text(keys).font(MuseType.captionMedium).foregroundStyle(MuseColor.ink55)
        }
        .padding(.horizontal, 9)
        .frame(height: 34)
        .museInsetSurface()
    }
}
#endif
