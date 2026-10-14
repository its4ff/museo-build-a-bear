import SwiftUI
import UIKit

/// A copyable snippet: SF Mono on an inset block with a copy chip. Copying plays
/// `.success` and the chip reads "copied" for a moment.
struct MuseCodeLine: View {
    let code: String
    var caption: String?

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    init(_ code: String, caption: String? = nil) {
        self.code = code
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xs) {
            HStack(alignment: .center, spacing: MuseSpacing.sm) {
                if let caption {
                    Text(caption)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                }
                Spacer(minLength: 0)
                copyChip
            }
            ScrollView(.horizontal) {
                Text(verbatim: code)
                    .font(MuseType.code)
                    .lineSpacing(3)
                    .foregroundStyle(MuseColor.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, MuseSpacing.md)
                    .padding(.vertical, MuseSpacing.sm)
            }
            .scrollIndicators(.hidden)
            .museInsetSurface()
        }
        .onDisappear { resetTask?.cancel() }
    }

    private var copyChip: some View {
        Button(action: copy) {
            HStack(spacing: MuseSpacing.xxs) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .museSymbol(10, weight: .semibold)
                    .contentTransition(.symbolEffect(.replace))
                Text(copied ? "copied" : "copy")
                    .font(MuseType.captionMedium)
            }
            .foregroundStyle(copied ? MuseColor.moss600 : MuseColor.ink70)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .musePill(.chrome)
            .frame(minHeight: MuseTopChrome.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.95))
        .accessibilityLabel(copied ? "copied" : "copy code")
    }

    private func copy() {
        UIPasteboard.general.string = code
        MuseHaptics.play(.success)
        withAnimation(MuseMotion.snappy) { copied = true }
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(MuseMotion.snappy) { copied = false }
        }
    }
}
