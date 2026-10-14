import SwiftUI

/// The home's search field, under the pills while search is open: a pressed-in well with a
/// glass, the query, and a clear button once there's something to clear. It searches the
/// pill you're on, by meaning and by word, on this iphone (`MuseSearch`).
struct LibrarySearchField: View {
    @Binding var query: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: MuseSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .museSymbol(14, weight: .medium)
                .foregroundStyle(MuseColor.ink70)
                .accessibilityHidden(true)

            TextField(
                "search your muses",
                text: $query,
                prompt: Text("search your muses").foregroundStyle(MuseColor.ink55)
            )
            .font(MuseType.label)
            .foregroundStyle(MuseColor.ink)
            .tint(MuseColor.moss)
            .focused(focus)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { focus.wrappedValue = false }

            if !query.isEmpty {
                Button {
                    MuseHaptics.play(.soft)
                    query = ""
                    focus.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .museSymbol(15, weight: .medium)
                        .foregroundStyle(MuseColor.ink55)
                        .frame(minWidth: MuseTopChrome.hitTarget, minHeight: MuseTopChrome.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MusePressStyle())
                .padding(.trailing, -MuseSpacing.sm)
                .accessibilityLabel("clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, MuseSpacing.md)
        .frame(minHeight: MuseTopChrome.hitTarget + MuseSpacing.xxs)
        .museInsetSurface()
        .museAnimation(MuseMotion.snappy, value: query.isEmpty)
    }
}

#Preview("search field") {
    @Previewable @State var query = "window"
    @Previewable @FocusState var focused: Bool
    VStack(spacing: MuseSpacing.sm) {
        LibrarySearchField(query: $query, focus: $focused)
        LibrarySearchField(query: .constant(""), focus: $focused)
    }
    .padding(MuseSpacing.page)
    .frame(maxHeight: .infinity)
    .background { MuseShelfBackground() }
}
