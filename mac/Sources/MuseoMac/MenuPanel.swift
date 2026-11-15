import AppKit
import MuseoKit
import SwiftUI

/// The glass panel the menu bar icon opens: the ring in one compact row, the one switch that
/// matters, which speech model is listening, and the last few muses.
struct MenuPanel: View {
    @Environment(\.openWindow) private var openWindow
    @State private var dictation = Dictation.shared
    @State private var speechLine = "apple speech · on this mac"
    private let library = MacLibrary.shared
    private var ring: RingStatus { RingModel.shared.status }
    private var actions: RingActions { .live(openFirmware: {}) }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            RingCard(ring: ring, recording: RingWatch.shared.recordingSince != nil, actions: actions)
            settings
            recent
            footer
        }
        .padding(MuseSpacing.sm)
        .frame(width: 320)
        .background(MuseColor.ground.opacity(0.7))
        .environment(\.colorScheme, .light)
        .task { speechLine = await MacSpeech.line() }
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $dictation.typesIntoApps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("type into the app in front")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink)
                    Text(dictation.typesIntoApps ? "hold, talk, let go" : "off: words are only copied")
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                }
            }
            .toggleStyle(.switch)
            .tint(MuseColor.moss)
            .padding(.vertical, MuseSpacing.xs)

            if dictation.typesIntoApps, !TextInserter.canType {
                Button {
                    TextInserter.askToType()
                } label: {
                    Text("let museo type for you…")
                        .font(MuseType.metaMedium)
                        .foregroundStyle(MuseColor.moss600)
                }
                .buttonStyle(.plain)
                .padding(.bottom, MuseSpacing.xs)
            }

            Rectangle().fill(MuseColor.divider).frame(height: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("speech")
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                Text(speechLine)
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
            }
            .padding(.vertical, MuseSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.xxs)
        .background(MuseColor.raised.opacity(0.75), in: RoundedRectangle(cornerRadius: MuseRadius.control))
        .overlay(RoundedRectangle(cornerRadius: MuseRadius.control).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
    }

    // MARK: - Recent

    private var recent: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            MuseEyebrow("recent")
                .padding(.horizontal, MuseSpacing.xxs)
            if library.muses.isEmpty {
                Text("nothing yet. hold the ring and talk.")
                    .font(MuseType.serifItalic)
                    .foregroundStyle(MuseColor.ink55)
                    .padding(.horizontal, MuseSpacing.xxs)
                    .padding(.vertical, MuseSpacing.xs)
            }
            ForEach(library.muses.prefix(4)) { muse in
                Button {
                    open(muse.id)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.sm) {
                        Text(muse.createdAt.museClock)
                            .font(MuseFont.mono(.caption2))
                            .foregroundStyle(MuseColor.ink55)
                            .frame(width: 44, alignment: .leading)
                        Text(snippet(muse))
                            .font(MuseFont.lora(14))
                            .foregroundStyle((muse.words ?? "").isEmpty ? MuseColor.ink55 : MuseColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if muse.isUnseen {
                            Circle().fill(MuseColor.ochre).frame(width: 6, height: 6)
                                .accessibilityLabel("new from the ring")
                        }
                    }
                    .padding(.horizontal, MuseSpacing.xxs)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MuseRowPressStyle())
            }
        }
    }

    private func snippet(_ muse: MacMuse) -> String {
        switch muse.words {
        case nil: "hearing it…"
        case "": "no words"
        case let words?: words
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: MuseSpacing.xs) {
            Button {
                open(nil)
            } label: {
                Text("open museo")
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(MuseColor.primaryGradient, in: RoundedRectangle(cornerRadius: MuseRadius.control))
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.97))
            .keyboardShortcut("o")

            Button {
                library.pasteNewest()
            } label: {
                Text("paste newest · ⌥⌘V")
                    .font(MuseType.metaMedium)
                    .foregroundStyle(MuseColor.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .overlay(RoundedRectangle(cornerRadius: MuseRadius.control).strokeBorder(MuseColor.hairline, lineWidth: 1))
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.97))
            .disabled(library.muses.allSatisfy { ($0.words ?? "").isEmpty })

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(MuseFont.symbol(12))
                    .foregroundStyle(MuseColor.ink55)
                    .frame(width: 34, height: 34)
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

/// The ring in one row: the dot ring, its state, and the one thing to do next.
private struct RingCard: View {
    let ring: RingStatus
    let recording: Bool
    let actions: RingActions

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            if let image = Self.glyph(lit: recording) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 34)
                    .opacity(ring.isLinked ? 1 : 0.5)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("your ring.")
                    .font(MuseFont.lora(17))
                    .foregroundStyle(MuseColor.ground)
                Text(line)
                    .font(MuseFont.mono(.caption2))
                    .foregroundStyle(MuseColor.ground.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            primary
            more
        }
        .padding(.leading, MuseSpacing.sm)
        .padding(.trailing, MuseSpacing.xs)
        .frame(height: 58)
        .background(MuseColor.softForestGradient, in: RoundedRectangle(cornerRadius: MuseRadius.control))
        .overlay(RoundedRectangle(cornerRadius: MuseRadius.control).strokeBorder(MuseColor.composer.opacity(0.12), lineWidth: 0.75))
    }

    private var line: String {
        var parts = [ring.shortLine]
        if ring.isLinked, let battery = ring.battery { parts.append("\(battery)%") }
        if ring.isLinked, let name = ring.advertisedName { parts.append(name) }
        return parts.joined(separator: " · ")
    }

    /// The one next step, as a small cream pill.
    @ViewBuilder
    private var primary: some View {
        switch ring.link {
        case .notSetUp:
            pill(ring.isSettingUp ? "looking…" : "set up") { actions.setUp() }
        case .away:
            pill("look for it") { actions.lookForIt() }
        case .linked where !ring.isSyncing && ring.waiting > 0:
            pill("bring in \(ring.waiting)") { actions.syncNow() }
        default:
            EmptyView()
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss900)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(MuseColor.ground, in: Capsule())
        }
        .buttonStyle(MusePressStyle())
    }

    /// Everything else about the ring, out of the way.
    private var more: some View {
        Menu {
            if ring.isLinked {
                Button("bring in memory recordings") { actions.syncNow() }
                Toggle("bring them in by itself", isOn: Binding(get: { ring.autoSync }, set: { actions.setAutoSync($0) }))
                Button("disconnect") { actions.disconnect() }
            }
            if ring.link != .notSetUp {
                Divider()
                Button("forget this ring") { actions.remove() }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(MuseFont.symbol(13))
                .foregroundStyle(MuseColor.ground.opacity(0.85))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("more about your ring")
    }

    /// The dot ring in bone: face on, or tipped toward you with its amber light on while it
    /// records to itself.
    private static func glyph(lit: Bool) -> NSImage? {
        lit ? tiltLit : circle
    }

    private static let circle = Bundle.main.url(forResource: "RingDotsCircleLight", withExtension: "webp").flatMap(NSImage.init(contentsOf:))
    private static let tiltLit = Bundle.main.url(forResource: "RingDotsTiltLit", withExtension: "webp").flatMap(NSImage.init(contentsOf:))
}
