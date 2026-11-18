#if DEBUG
import SwiftUI

/// A new place: one sentence, the way a person talks. The app proposes a name from it, and
/// it sends nowhere until the person says where. No rule builder.
struct PocketNewPlace: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sentence: String
    @State private var destination: PocketDestination = .none
    @FocusState private var isWriting: Bool

    /// The lab opens it with the sentence already said, so the proposed name shows.
    init(sentence: String = PocketNewPlaceWords.example) {
        _sentence = State(initialValue: sentence)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("a new place")
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink55)
                .frame(maxWidth: .infinity)
                .padding(.top, MuseSpacing.xl)
                .accessibilityAddTraits(.isHeader)

            TextField(
                "",
                text: $sentence,
                prompt: Text(PocketNewPlaceWords.example).foregroundStyle(MuseColor.ink55.opacity(0.6)),
                axis: .vertical
            )
            .font(MuseType.title)
            .tracking(MuseType.titleTracking)
            .foregroundStyle(MuseColor.ink)
            .tint(MuseColor.moss)
            .lineLimit(1...4)
            .textInputAutocapitalization(.never)
            .focused($isWriting)
            .accessibilityLabel("what belongs here, in a sentence")
            .padding(.top, MuseSpacing.sectionLabel)

            VStack(spacing: 0) {
                row("its name") {
                    Text(name)
                        .font(MuseType.serif)
                        .foregroundStyle(name.isEmpty ? MuseColor.ink55 : MuseColor.ink)
                        .contentTransition(.opacity)
                }
                line
                Menu {
                    Picker("send to", selection: $destination) {
                        ForEach(PocketNewPlaceWords.choices, id: \.self) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                } label: {
                    row("send to") {
                        Text(destination.label)
                            .font(MuseType.body)
                            .foregroundStyle(MuseColor.ink)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("send to, \(destination.label)")
                line
            }
            .padding(.top, MuseSpacing.sectionLabel)

            Text("the iphone reads each new thought against this, on the iphone.")
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MuseSpacing.md)
                .padding(.bottom, MuseSpacing.xl)

            Button {
                MuseHaptics.play(.soft)
                dismiss()
            } label: {
                PocketPlacesPrimaryLabel("make this place")
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? PocketNewPlaceWords.restingOpacity : 1)
        }
        .padding(.horizontal, MuseSpacing.xl)
        .padding(.bottom, MuseSpacing.md)
        .museAnimation(MuseMotion.select, value: name)
    }

    /// The name the app proposes from the sentence.
    private var name: String { PocketNewPlaceWords.name(from: sentence) }

    private func row(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(spacing: MuseSpacing.sm) {
            Text(label)
                .font(MuseType.body)
                .foregroundStyle(MuseColor.ink55)
            Spacer(minLength: MuseSpacing.xs)
            value()
                .lineLimit(1)
        }
        .frame(minHeight: PocketNewPlaceWords.rowHeight)
        .contentShape(Rectangle())
    }

    private var line: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - The one primary button

/// The moss capsule the places sheets end on: the same material as the ring pill.
struct PocketPlacesPrimaryLabel: View {
    let words: String

    init(_ words: String) {
        self.words = words
    }

    var body: some View {
        Text(words)
            .font(MuseType.label)
            .foregroundStyle(MuseColor.ground)
            .contentTransition(.opacity)
            .frame(maxWidth: .infinity, minHeight: PocketRingPillMetrics.height)
            .pocketMossPill()
            .contentShape(Capsule())
    }
}

// MARK: - Words

/// The new place sheet's words and the plain rule that proposes a name. In the app the
/// on-device model would name it; here the opening words are dropped.
nonisolated enum PocketNewPlaceWords {
    static let example = "anything about the shop"
    static let choices: [PocketDestination] = [.none, .files, .webAddress, .agent]
    static let rowHeight: CGFloat = 52
    static let restingOpacity: Double = 0.45

    /// "anything about the shop" becomes "the shop".
    static func name(from sentence: String) -> String {
        var words = sentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for lead in ["anything about ", "things about ", "everything about ", "when i say ", "ideas for ", "anything for "]
        where words.hasPrefix(lead) {
            words.removeFirst(lead.count)
            break
        }
        return words.split(separator: " ").prefix(3).joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters)
    }
}

#Preview {
    PocketNewPlace()
        .background(MuseColor.raised)
}
#endif
