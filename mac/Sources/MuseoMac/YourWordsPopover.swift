import SwiftUI

/// The panel's "your words" row: how many, and a popover to change them. In the popover, a
/// field takes words with commas between; each word is a pill. Click one to change it, hover
/// for its ×.
struct YourWordsRow: View {
    @State private var words = YourWords.shared
    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 5) {
                Text(summary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(MuseFont.symbol(8))
                    .foregroundStyle(MuseColor.ink55)
            }
            .font(MuseType.caption)
            .foregroundStyle(MuseColor.ink)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(MuseColor.composer.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $isOpen, arrowEdge: .trailing) {
            YourWordsPopover()
        }
    }

    /// "museo, Voz, +1", or "none yet".
    private var summary: String {
        let all = words.words
        guard !all.isEmpty else { return "none yet" }
        let shown = all.prefix(2).joined(separator: ", ")
        return all.count > 2 ? "\(shown), +\(all.count - 2)" : shown
    }
}

struct YourWordsPopover: View {
    @State private var words = YourWords.shared
    @State private var adding = ""
    @State private var editing: String?
    @State private var draft = ""
    @State private var hovered: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case adding, editing }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text("your words.")
                    .font(MuseFont.lora(18))
                    .foregroundStyle(MuseColor.ink)
                Text("names and words museo should hear right. commas between to add a few.")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("add", text: $adding, prompt: Text("Voz, Haseab, Arc…").foregroundStyle(MuseColor.ink55))
                .textFieldStyle(.plain)
                .font(MuseType.caption)
                .foregroundStyle(MuseColor.ink)
                .tint(MuseColor.moss)
                .focused($focus, equals: .adding)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(MuseColor.composer.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(MuseColor.hairline, lineWidth: 0.75))
                .onSubmit {
                    withAnimation(MuseMotion.gentle) { words.add(adding) }
                    adding = ""
                }
            if words.words.isEmpty {
                Text("none yet.")
                    .font(MuseType.serifItalic)
                    .foregroundStyle(MuseColor.ink55)
            } else {
                PillFlow(spacing: 6) {
                    ForEach(words.words, id: \.self) { word in
                        pill(word)
                    }
                }
            }
        }
        .padding(MuseSpacing.md)
        .frame(width: 290, alignment: .leading)
        .background { MuseBackground().ignoresSafeArea() }
        .environment(\.colorScheme, .light)
        .onAppear { focus = .adding }
    }

    // MARK: - A pill

    @ViewBuilder
    private func pill(_ word: String) -> some View {
        if editing == word {
            TextField("word", text: $draft)
                .textFieldStyle(.plain)
                .font(MuseFont.lora(14))
                .foregroundStyle(MuseColor.ink)
                .tint(MuseColor.moss)
                .focused($focus, equals: .editing)
                .fixedSize()
                .frame(minWidth: 40)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(MuseColor.raised, in: Capsule())
                .overlay(Capsule().strokeBorder(MuseColor.moss.opacity(0.6), lineWidth: 1))
                .onSubmit { finishEditing() }
                .onExitCommand { editing = nil }
        } else {
            HStack(spacing: 4) {
                Text(word)
                    .font(MuseFont.lora(14))
                    .foregroundStyle(MuseColor.ink)
                Button {
                    withAnimation(MuseMotion.gentle) { words.remove(word) }
                } label: {
                    Image(systemName: "xmark")
                        .font(MuseFont.symbol(8))
                        .foregroundStyle(MuseColor.ink55)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hovered == word ? 1 : 0.35)
                .help("remove \(word)")
                .accessibilityLabel("remove \(word)")
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(height: 26)
            .background(MuseColor.raised.opacity(0.8), in: Capsule())
            .overlay(Capsule().strokeBorder(MuseColor.hairline, lineWidth: 0.75))
            .contentShape(Capsule())
            .onHover { inside in
                if inside { hovered = word } else if hovered == word { hovered = nil }
            }
            .onTapGesture {
                finishEditing()
                draft = word
                editing = word
                focus = .editing
            }
            .help("click to change it")
        }
    }

    private func finishEditing() {
        guard let old = editing else { return }
        words.rename(old, to: draft)
        editing = nil
    }
}

/// Pills in rows that wrap: as many as fit on a line, then the next.
struct PillFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
