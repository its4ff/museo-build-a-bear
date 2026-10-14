import SwiftUI

/// Build › speech: the language muses are in, which on-device engine writes the words,
/// and studio sound. Everything here runs on this iphone.
struct SpeechSection: View {
    @Environment(SpeechSettings.self) private var injected: SpeechSettings?

    /// The environment's settings (lab can stage one), else the app's.
    private var speech: SpeechSettings { injected ?? .shared }

    var body: some View {
        BuildBlock(.speech) {
            MuseListCard {
                LanguageRow(speech: speech)
                if VozSpeech.isAvailable {
                    EngineRow(speech: speech)
                    VozRow(speech: speech)
                }
                if StudioSound.isAvailable {
                    MuseToggleRow(
                        "studio sound",
                        subtitle: "a cleaner copy for listening. the words always come from the original.",
                        isOn: Binding(get: { speech.studioSound }, set: { speech.studioSound = $0 })
                    )
                }
            }
            BuildFootnote("runs on this iphone, and your voice never leaves it. voz and studio sound count how often they run for desert ant labs, never what you said.")
        }
        .onAppear { speech.refresh() }
    }
}

// MARK: - Language

private struct LanguageRow: View {
    let speech: SpeechSettings

    @State private var languages: [(id: String, name: String)] = []

    var body: some View {
        Menu {
            Picker("language", selection: selection) {
                Text("auto · this iphone's language").tag(String?.none)
                ForEach(languages, id: \.id) { language in
                    Text(language.name).tag(Optional(language.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(alignment: .center, spacing: MuseSpacing.row) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("language")
                        .font(MuseType.label)
                        .foregroundStyle(MuseColor.ink)
                    Text(speech.languageLabel)
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .lineLimit(1)
                }
                Spacer(minLength: MuseSpacing.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .museSymbol(12, weight: .semibold)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MuseSpacing.card)
            .padding(.vertical, MuseSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("language, \(speech.languageLabel)")
        .accessibilityHint("new muses only")
        .task {
            guard languages.isEmpty else { return }
            languages = await SpeechSettings.availableLanguages()
        }
    }

    private var selection: Binding<String?> {
        Binding(
            get: { speech.language },
            set: { language in
                guard language != speech.language else { return }
                MuseHaptics.play(.selection)
                speech.language = language
            }
        )
    }
}

// MARK: - Engine

private struct EngineRow: View {
    let speech: SpeechSettings

    /// Voz is a big download: one stray tap on the segment asks first.
    @State private var askingToDownload = false

    var body: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text("engine")
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                Text("which on-device model writes the words")
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
            }
            MuseSegmented(
                selection: Binding(get: { shownEngine }, set: { choose($0) }),
                options: SpeechSettings.Engine.allCases.map { ($0, $0.title) }
            )
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("download voz?", isPresented: $askingToDownload, titleVisibility: .visible) {
            Button("download") {
                MuseHaptics.play(.soft)
                speech.downloadVoz()
            }
            Button("keep apple", role: .cancel) {}
        } message: {
            Text("\(VozSpeech.downloadSize), one time. best on wi-fi.")
        }
    }

    /// Voz shows as chosen while it downloads: asking for it is choosing it.
    private var shownEngine: SpeechSettings.Engine {
        switch speech.vozState {
        case .downloading, .preparing: .voz
        default: speech.engine
        }
    }

    private func choose(_ engine: SpeechSettings.Engine) {
        switch engine {
        case .apple:
            if case .downloading = speech.vozState { speech.removeVoz() }
            speech.engine = .apple
        case .voz:
            switch speech.vozState {
            case .ready:
                speech.engine = .voz
            case .downloading, .preparing:
                break
            case .notDownloaded, .failed:
                if VozSpeech.isDownloaded {
                    // On disk already, it only needs getting ready: nothing to download.
                    speech.downloadVoz()
                } else {
                    // The engine stays apple, so the segment slides back until they say yes.
                    askingToDownload = true
                }
            }
        }
    }
}

/// Voz's state in one row: the download, getting ready, ready, or why it stopped.
private struct VozRow: View {
    let speech: SpeechSettings

    /// Removing throws away a 467 mb download, so it asks first.
    @State private var askingToRemove = false

    var body: some View {
        HStack(alignment: .center, spacing: MuseSpacing.row) {
            badge
            VStack(alignment: .leading, spacing: 3) {
                Text("voz")
                    .font(MuseType.label)
                    .foregroundStyle(MuseColor.ink)
                Text(speech.vozDetail)
                    .font(MuseType.meta)
                    .monospacedDigit()
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: MuseSpacing.xs)
            action
        }
        .padding(.horizontal, MuseSpacing.card)
        .padding(.vertical, MuseSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .museAnimation(MuseMotion.smooth, value: speech.vozState)
        .confirmationDialog("remove voz?", isPresented: $askingToRemove, titleVisibility: .visible) {
            Button("remove", role: .destructive) {
                speech.removeVoz()
                MuseHaptics.play(.soft)
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("new muses go back to apple speech. getting voz again is the same download.")
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch speech.vozState {
        case .downloading(let fraction):
            DownloadRing(fraction: fraction)
        case .preparing:
            MuseOrb(mode: .thinking, size: 22)
                .frame(width: 28, height: 28)
        case .ready:
            MuseIconTile("checkmark", size: 28, tone: .moss)
        case .notDownloaded, .failed:
            MuseIconTile("arrow.down", size: 28, tone: .quiet)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch speech.vozState {
        case .notDownloaded:
            Button("download") { MuseHaptics.play(.soft); speech.downloadVoz() }
                .buttonStyle(MuseButtonStyle(.tinted, height: 30))
        case .failed:
            Button("try again") { MuseHaptics.play(.soft); speech.downloadVoz() }
                .buttonStyle(MuseButtonStyle(.tinted, height: 30))
        case .downloading:
            Button("stop") { MuseHaptics.play(.soft); speech.removeVoz() }
                .buttonStyle(MuseButtonStyle(.secondary, height: 30))
                .accessibilityLabel("stop the voz download")
        case .preparing:
            EmptyView()
        case .ready:
            Button("remove voz") { MuseHaptics.play(.soft); askingToRemove = true }
                .buttonStyle(MuseButtonStyle(.secondary, height: 30))
        }
    }
}

/// A small moss ring that fills as Voz downloads.
private struct DownloadRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(MuseColor.ink.opacity(0.1), lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: max(0.02, min(fraction, 1)))
                .stroke(MuseColor.moss600, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .frame(width: 28, height: 28)
        .museAnimation(MuseMotion.gentle, value: fraction)
        .accessibilityHidden(true)
    }
}
