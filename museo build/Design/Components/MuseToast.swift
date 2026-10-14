import SwiftUI

/// A short note that floats up from the bottom and leaves on its own ("copied",
/// "muse deleted"). Show it with `.museToast($message)`.
struct MuseToast: View {
    let message: String
    var systemImage: String?

    init(_ message: String, systemImage: String? = nil) {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .museSymbol(13, weight: .semibold)
                    .foregroundStyle(MuseColor.moss600)
                    .accessibilityHidden(true)
            }
            Text(message)
                .font(MuseType.label)
                .foregroundStyle(MuseColor.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, MuseSpacing.md)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: 420)
        .background { MuseGlassSurface(cornerRadius: 22) }
    }
}

extension View {
    /// Shows `message` as a `MuseToast` at the bottom, then clears it after `duration`.
    /// Tap the toast to dismiss it early.
    func museToast(
        _ message: Binding<String?>,
        systemImage: String? = nil,
        duration: Duration = .seconds(2.4)
    ) -> some View {
        modifier(MuseToastPresenter(message: message, systemImage: systemImage, duration: duration))
    }
}

private struct MuseToastPresenter: ViewModifier {
    @Binding var message: String?
    let systemImage: String?
    let duration: Duration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    MuseToast(message, systemImage: systemImage)
                        .padding(.horizontal, MuseSpacing.page)
                        .padding(.bottom, MuseSpacing.sm)
                        .onTapGesture { self.message = nil }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(message)
                }
            }
            .animation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion), value: message)
            .task(id: message) {
                guard let shown = message else { return }
                AccessibilityNotification.Announcement(shown).post()
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled, message == shown else { return }
                message = nil
            }
    }
}
