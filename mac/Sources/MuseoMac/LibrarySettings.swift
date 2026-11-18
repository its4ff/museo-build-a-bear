import SwiftUI

/// The library's settings: a small button at the top of the sidebar, in the traffic lights'
/// row, and a popover under it. For now it holds one thing: leaving out short muses.
struct LibrarySettingsButton: View {
    @State private var isOpen = false
    @State private var isHovered = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(MuseFont.symbol(12))
                .foregroundStyle(isOpen ? MuseColor.moss : MuseColor.ink55)
                .frame(width: 28, height: 28)
                .background(isOpen || isHovered ? MuseColor.moss.opacity(0.1) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("library settings")
        .accessibilityLabel("library settings")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            LibrarySettingsPopover()
        }
    }
}

struct LibrarySettingsPopover: View {
    @State private var library = MacLibrary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            Text("your library.")
                .font(MuseFont.lora(18))
                .foregroundStyle(MuseColor.ink)
            HStack(alignment: .top, spacing: MuseSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("leave out short muses")
                        .font(MuseType.captionMedium)
                        .foregroundStyle(MuseColor.ink)
                    Text("blank ones, and ones under \(library.shortWords) \(library.shortWords == 1 ? "word" : "words"), aren't kept.")
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("leave out short muses", isOn: $library.leavesOutShort)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(MuseColor.moss)
            }
            HStack(spacing: MuseSpacing.xs) {
                Text("shorter than")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink70)
                Spacer(minLength: 0)
                WordCountStepper(value: $library.shortWords)
                Text("words")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink70)
            }
            .opacity(library.leavesOutShort ? 1 : 0.45)
            .disabled(!library.leavesOutShort)
            if Updates.isOn {
                HStack {
                    Text("museo \(Updates.version)")
                        .font(MuseType.caption)
                        .foregroundStyle(MuseColor.ink55)
                    Spacer(minLength: 0)
                    Button {
                        Updates.check()
                    } label: {
                        Text("check for updates")
                            .font(MuseType.captionMedium)
                            .foregroundStyle(MuseColor.moss600)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, MuseSpacing.xs)
                .overlay(alignment: .top) { Rectangle().fill(MuseColor.hairline).frame(height: 1) }
            }
        }
        .padding(MuseSpacing.md)
        .frame(width: 290, alignment: .leading)
        .background { MuseBackground().ignoresSafeArea() }
        .environment(\.colorScheme, .light)
    }
}

/// − [5] +: a number you can type, or nudge.
private struct WordCountStepper: View {
    @Binding var value: Int
    @State private var text = ""
    @FocusState private var isTyping: Bool

    private let range = MacLibrary.shortWordsRange

    var body: some View {
        HStack(spacing: 0) {
            nudge("minus", by: -1, label: "fewer words")
            TextField("words", text: $text)
                .textFieldStyle(.plain)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.ink)
                .multilineTextAlignment(.center)
                .tint(MuseColor.moss)
                .focused($isTyping)
                .frame(width: 28, height: 26)
                .overlay(alignment: .leading) { Rectangle().fill(MuseColor.hairline).frame(width: 0.75) }
                .overlay(alignment: .trailing) { Rectangle().fill(MuseColor.hairline).frame(width: 0.75) }
                .onSubmit(commit)
                .onChange(of: isTyping) { _, typing in if !typing { commit() } }
                .accessibilityLabel("words")
            nudge("plus", by: 1, label: "more words")
        }
        .background(MuseColor.composer.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
        .onAppear { text = String(value) }
        .onChange(of: value) { _, new in text = String(new) }
    }

    private func nudge(_ symbol: String, by step: Int, label: String) -> some View {
        Button {
            value = min(max(value + step, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol)
                .font(MuseFont.symbol(9))
                .foregroundStyle(MuseColor.ink70)
                .frame(width: 24, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// A typed number, kept within the range; anything else goes back to what it was.
    private func commit() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)) {
            value = min(max(typed, range.lowerBound), range.upperBound)
        }
        text = String(value)
    }
}
