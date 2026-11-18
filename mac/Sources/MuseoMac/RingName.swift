import Foundation
import Observation
import SwiftUI

/// What museo calls the ring on this mac. The ring advertises a name its firmware sets
/// ("Museo_bd27") and the mac has no way for an app to rename a bluetooth device, so a name
/// you give it lives here: keyed by the ring's own name, so another ring doesn't inherit it.
@MainActor
@Observable
final class RingNames {
    static let shared = RingNames()
    static let maxLength = 13
    private static let key = "ringNicknames"

    private var names: [String: String] = UserDefaults.standard.dictionary(forKey: RingNames.key) as? [String: String] ?? [:] {
        didSet { UserDefaults.standard.set(names, forKey: Self.key) }
    }

    /// The name you gave this ring, if any.
    func nickname(for ring: String?) -> String? {
        ring.flatMap { names[$0] }
    }

    /// Blank goes back to the ring's own name.
    func setNickname(_ name: String, for ring: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        names[ring] = trimmed.isEmpty || trimmed == ring ? nil : trimmed
    }
}

/// The ring's name at the top of the panel, with a pencil while the ring's line is hovered.
/// Click it (or double click the name) to type a new one; return keeps it, escape doesn't, and
/// blank goes back to the ring's own name. 13 characters fit beside the disconnect pill.
struct RingNameField: View {
    /// The name the ring advertises; nil before it's set up, and then there's nothing to rename.
    let ringName: String?
    @Binding var isEditing: Bool
    /// The ring's line is hovered: the whole line, so the pencil stays while you reach for it.
    var showsPencil = false
    /// How the name is set: Lora on paper by default; the panel's pill sets it as a label.
    var font: Font = MuseFont.lora(16)
    var ink: Color = MuseColor.ink
    /// The cursor, and the thin line under the name while typing.
    var accent: Color = MuseColor.moss
    /// What stands in before a ring is set up.
    var unnamed = "your ring."
    private let names = RingNames.shared
    @State private var text = ""
    @FocusState private var isTyping: Bool

    private var nickname: String? { names.nickname(for: ringName) }
    private var shown: String { nickname ?? ringName ?? unnamed }

    var body: some View {
        HStack(spacing: MuseSpacing.xxs) {
            if isEditing, let ringName {
                TextField(ringName, text: $text)
                    .textFieldStyle(.plain)
                    .font(font)
                    .foregroundStyle(ink)
                    .tint(accent)
                    .focused($isTyping)
                    .onSubmit { save(ringName) }
                    .onExitCommand { isEditing = false }
                    .onChange(of: text) { _, new in
                        if new.count > RingNames.maxLength { text = String(new.prefix(RingNames.maxLength)) }
                    }
                    .onChange(of: isTyping) { _, typing in if !typing, isEditing { save(ringName) } }
                    .onAppear {
                        text = nickname ?? ringName
                        isTyping = true
                    }
                    .accessibilityLabel("the ring's name")
            } else {
                Text(shown)
                    .font(font)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { if ringName != nil { isEditing = true } }
                    .help(nickname != nil ? "on the ring it's \(ringName ?? "")" : "")
                    // In the gap after the name rather than beside it, so it never takes the
                    // name's room.
                    .overlay(alignment: .trailing) {
                        if ringName != nil, showsPencil {
                            Button { isEditing = true } label: {
                                Image(systemName: "pencil")
                                    .font(MuseFont.symbol(11))
                                    .foregroundStyle(MuseColor.ink55)
                                    .frame(width: 20, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("rename the ring")
                            .accessibilityLabel("rename the ring")
                            .offset(x: 23)
                        }
                    }
            }
        }
        .frame(height: 22, alignment: .leading)
        // A thin moss line while typing, so the name reads as a field.
        .overlay(alignment: .bottom) {
            if isEditing {
                Rectangle().fill(accent.opacity(0.6)).frame(height: 1)
            }
        }
    }

    private func save(_ ringName: String) {
        names.setNickname(text, for: ringName)
        isEditing = false
    }
}
