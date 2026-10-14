import SwiftUI
import UIKit

/// One muse, on its own page:
///
/// 1. the stamp ("wednesday october 8 · 3:40p") with newer and older chevrons, and close
/// 2. the title (tap to edit it in place), then where it came from
/// 3. the notes, for longer muses (`MuseNotesView`)
/// 4. the words: open when they're the whole muse, folded under the notes when there are
///    some. They ink in as the muse plays; tap a word to hear it from there
/// 5. a quiet footer with copy and share, then write the notes again, transcribe again, delete
/// 6. "for builders": the muse as your code sees it
///
/// The listen capsule floats at the bottom. Swipe sideways, or tap the chevrons, to go to
/// the newer or older muse among the ones that were on screen (`AppRouter.musePool`).
///
/// ```swift
/// router.open(muse: muse.id, among: shown.map(\.id))   // RootView shows MuseDetailView(id:)
/// ```
struct MuseDetailView: View {
    /// The muse the page opened on.
    let id: UUID

    @Environment(MuseStore.self) private var store
    @Environment(MusePipeline.self) private var pipeline
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The muse on screen now: `id`, until they browse.
    @State private var shownID: UUID
    /// The way the last step went: 1 older (the page leaves to the left), -1 newer.
    @State private var step = 0

    @State private var player: MuseAudioPlayer
    private let timings: TimedTranscript?
    private let loadsAudio: Bool

    @State private var toast: String?
    @State private var toastIcon = "checkmark"
    @State private var copied = false
    @State private var copyReset: Task<Void, Never>?
    @State private var confirmingDelete = false
    @State private var deletedHere = false
    @State private var wordsOpen = false
    @State private var showsDetails: Bool
    @State private var timingNote: String?
    @State private var editingTitle: Bool
    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool

    /// Mid-letter on the meta line, so the origin mark sits on its first line at any size.
    @ScaledMetric(relativeTo: .footnote) private var metaMidline: CGFloat = 4.5

    init(id: UUID) {
        self.id = id
        _shownID = State(initialValue: id)
        _player = State(initialValue: MuseAudioPlayer())
        _showsDetails = State(initialValue: false)
        _editingTitle = State(initialValue: false)
        timings = nil
        loadsAudio = true
    }

    /// For lab screens and previews: a player that keeps time without audio
    /// (`MuseAudioPlayer.preview`), optionally word timings to ink, and the title editor
    /// or the builders' details already open.
    init(
        id: UUID,
        player: MuseAudioPlayer,
        timings: TimedTranscript? = nil,
        editsTitle: Bool = false,
        opensDetails: Bool = false
    ) {
        self.id = id
        _shownID = State(initialValue: id)
        _player = State(initialValue: player)
        _showsDetails = State(initialValue: opensDetails)
        _editingTitle = State(initialValue: editsTitle)
        self.timings = timings
        loadsAudio = false
    }

    var body: some View {
        Group {
            if let muse = store.muse(id: shownID) {
                page(muse)
            } else {
                gone
            }
        }
        .background { MuseBackground() }
        // The home zooms the page back into this muse's tile, not the one it opened on.
        // The router forgets it once the sheet is gone (`musePageGone()`), not here: the
        // page is still zooming back when it disappears.
        .onChange(of: shownID, initial: true) { _, shown in
            router.museShown = shown
        }
        .onDisappear {
            player.stop()
            copyReset?.cancel()
        }
    }

    // MARK: - Page

    private func page(_ muse: Muse) -> some View {
        let audio = muse.audioURL
        let hasAudio = audio != nil || (!loadsAudio && player.canPlay)
        return ZStack {
            scroll(muse, hasAudio: hasAudio)
                .id(muse.id)
                .transition(pageTransition)
        }
        .museAnimation(MuseMotion.smooth, value: shownID)
        // Inside the bars, so a toast rises above the capsule instead of over it.
        .museToast($toast, systemImage: toastIcon)
        .safeAreaBar(edge: .top, spacing: 0) {
            topBar(muse)
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            bottomBar(audio: audio, hasAudio: hasAudio)
        }
        .confirmationDialog("delete this muse?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("delete", role: .destructive) { delete(muse.id) }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("its words, notes and audio go too.")
        }
        .task(id: muse.audioFileName) {
            guard loadsAudio else { return }
            player.load(audio, duration: muse.duration)
        }
        .onAppear {
            // The lab can open with the editor up: start it from the title there is.
            if editingTitle, titleDraft.isEmpty { titleDraft = muse.title ?? "" }
        }
        // Playing a muse whose words are folded opens them, so you can watch them ink in.
        .onChange(of: player.isPlaying) { _, playing in
            guard playing, !wordsOpen, store.muse(id: shownID)?.notes != nil else { return }
            withAnimation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion)) { wordsOpen = true }
        }
    }

    /// Leans the way they went: older comes in from the right, newer from the left. Under
    /// Reduce Motion it only fades.
    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let shift = CGFloat(step) * Self.browseShift
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: shift)),
            removal: .opacity.combined(with: .offset(x: -shift))
        )
    }

    /// How far a page leans as it comes and goes.
    private static let browseShift: CGFloat = 28

    private func scroll(_ muse: Muse, hasAudio: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                heading(muse)
                notes(muse)
                words(muse, hasAudio: hasAudio)
                    .museAnimation(MuseMotion.dissolve, value: muse.transcriptionState)
                if showsFooter(muse) {
                    footer(muse)
                        .padding(.top, MuseSpacing.xxs)
                }
                actions(muse, hasAudio: hasAudio)
                builders(muse)
                    .padding(.top, MuseSpacing.sm)
            }
            .padding(.horizontal, MuseSpacing.page)
            .padding(.top, MuseSpacing.xs)
            .padding(.bottom, MuseSpacing.sectionLabel)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .museBottomBlur(hostBar: false)
        .gesture(BrowseSwipe(
            onOlder: { swipe(older: true) },
            onNewer: { swipe(older: false) }
        ))
    }

    // MARK: Top bar

    /// The stamp, the newer and older chevrons when there's somewhere to go, and close.
    private func topBar(_ muse: Muse) -> some View {
        let near = neighbors(of: muse.id)
        let browses = near.newer != nil || near.older != nil
        return HStack(spacing: 0) {
            MuseEyebrow(Self.stamp(muse.createdAt), color: MuseColor.ink70)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: MuseSpacing.xs)
            if browses {
                chevron("chevron.left", label: "newer muse", to: near.newer, step: -1)
                chevron("chevron.right", label: "older muse", to: near.older, step: 1)
                    .padding(.trailing, MuseSpacing.xxs)
            }
            MuseChromeIcon("xmark", label: "close") { close() }
        }
        .museAnimation(MuseMotion.dissolve, value: shownID)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.leading, MuseSpacing.page)
        // The close circle's edge sits on the page gutter.
        .padding(.trailing, MuseSpacing.page - (MuseTopChrome.hitTarget - MuseTopChrome.circle) / 2)
        .padding(.top, MuseSpacing.xs)
        .padding(.bottom, MuseSpacing.xxs)
    }

    /// A quiet chevron in a 44pt target, dimmed at the end of the pool.
    private func chevron(_ symbol: String, label: String, to target: UUID?, step direction: Int) -> some View {
        Button {
            go(to: target, step: direction)
        } label: {
            Image(systemName: symbol)
                .font(MuseFont.symbol(14, weight: .semibold))
                .foregroundStyle(target == nil ? MuseColor.ink55.opacity(0.35) : MuseColor.ink70)
                .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusePressStyle(pressedScale: 0.88))
        .disabled(target == nil)
        .accessibilityLabel(label)
    }

    /// "wednesday october 8 · 3:40p", with the year when it isn't this one.
    private static func stamp(_ date: Date, now: Date = .now) -> String {
        var style = Date.FormatStyle().weekday(.wide).month(.wide).day()
        if Calendar.current.component(.year, from: date) != Calendar.current.component(.year, from: now) {
            style = style.year()
        }
        let day = date.formatted(style).replacingOccurrences(of: ",", with: "").lowercased()
        return "\(day) \u{00B7} \(date.museClock)"
    }

    // MARK: Heading

    private func heading(_ muse: Muse) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.xxs) {
            titleRow(muse)
            originLine(muse)
            if muse.transcriptionState == .complete, !muse.isBlank, let confidence = muse.wordConfidence {
                MuseConfidenceTag(confidence)
                    .padding(.top, MuseSpacing.xs)
                    .transition(.opacity)
            }
        }
    }

    /// The person's or the model's title. Once the words are in, tap it to change it.
    @ViewBuilder
    private func titleRow(_ muse: Muse) -> some View {
        let title = Self.title(of: muse)
        if editingTitle {
            titleEditor
        } else if let title {
            if canEditTitle(muse) {
                Button {
                    beginTitleEdit(muse)
                } label: {
                    titleText(title, pencil: true)
                }
                .buttonStyle(MusePressStyle(pressedScale: 0.98))
                .accessibilityLabel(title)
                .accessibilityHint("edits the title")
                .accessibilityAddTraits(.isHeader)
            } else {
                titleText(title, pencil: false)
                    .accessibilityAddTraits(.isHeader)
            }
        } else if canEditTitle(muse), !pipeline.working.contains(muse.id) {
            // Untitled (short, or the model wasn't there): the words are the hero, so the
            // way to name it stays small.
            Button {
                beginTitleEdit(muse)
            } label: {
                HStack(spacing: MuseSpacing.xxs) {
                    Image(systemName: "pencil")
                        .museSymbol(12, weight: .medium)
                        .accessibilityHidden(true)
                    Text("add a title")
                        .font(MuseType.meta)
                }
                .foregroundStyle(MuseColor.ink55)
                .frame(minHeight: MuseTopChrome.hitTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.96))
        }
    }

    /// Lora 24 medium, the pencil riding on its last line.
    private func titleText(_ title: String, pencil: Bool) -> some View {
        let mark = Text(Image(systemName: "pencil"))
            .font(MuseFont.symbol(13, weight: .medium))
            .foregroundStyle(MuseColor.ink55)
        return Group {
            if pencil {
                Text("\(title)  \(mark)")
            } else {
                Text(title)
            }
        }
        .font(Self.titleFont)
        .tracking(MuseType.titleTracking)
        .lineSpacing(MuseType.bodyLineSpacing)
        .foregroundStyle(MuseColor.ink)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: MuseTopChrome.hitTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private static let titleFont = MuseFont.lora(24, weight: .medium)

    /// The title in place, on an inset well that bleeds into the gutter so the words don't
    /// move. Return saves, as does "save"; "keep as is" leaves it.
    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            TextField("title", text: $titleDraft, axis: .vertical)
                .font(Self.titleFont)
                .tracking(MuseType.titleTracking)
                .foregroundStyle(MuseColor.ink)
                .tint(MuseColor.moss600)
                .lineLimit(1...4)
                .submitLabel(.done)
                .focused($titleFocused)
                .padding(.horizontal, MuseSpacing.sm)
                .padding(.vertical, MuseSpacing.xs)
                .museInsetSurface()
                .padding(.horizontal, -MuseSpacing.sm)
                .accessibilityLabel("title")
                .onChange(of: titleDraft) { _, text in
                    // A vertical field takes return as a new line: here it means done.
                    guard text.contains("\n") else { return }
                    titleDraft = text.replacingOccurrences(of: "\n", with: "")
                    finishTitle(save: true)
                }
            HStack(spacing: MuseSpacing.xs) {
                Spacer(minLength: 0)
                Button("keep as is") { finishTitle(save: false) }
                    .buttonStyle(.muse(.secondary, height: 34))
                Button("save") { finishTitle(save: true) }
                    .buttonStyle(.muse(.primary, height: 34))
            }
        }
    }

    /// "streamed · from the ring", "memory · synced from the ring", "typed".
    private func originLine(_ muse: Muse) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
            if muse.origin.isRing {
                MuseRingMark(size: 13, color: MuseColor.ink55)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + metaMidline }
            } else {
                Image(systemName: muse.origin.symbol)
                    .museSymbol(12, weight: .medium)
                    .foregroundStyle(MuseColor.ink55)
                    .accessibilityHidden(true)
            }
            Text(Self.originWords(muse.origin))
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private static func originWords(_ origin: MuseOrigin) -> String {
        switch origin {
        case .stream: "streamed \u{00B7} from the ring"
        case .offline: "memory \u{00B7} synced from the ring"
        case .typed: "typed"
        case .sample: "sample"
        }
    }

    /// The title the page shows, when there is one.
    private static func title(of muse: Muse) -> String? {
        guard !muse.isBlank, let title = muse.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        return title
    }

    // MARK: Notes

    /// The notes, a spinner while they're written, or why there are none.
    @ViewBuilder
    private func notes(_ muse: Muse) -> some View {
        let writing = pipeline.noting.contains(muse.id)
        let missing = notesUnavailable(muse)
        if muse.notes != nil || writing || missing != nil {
            VStack(alignment: .leading, spacing: MuseSpacing.sm) {
                if writing {
                    MuseNotesWriting(kind: muse.expectedNotes ?? muse.notes?.kind ?? .brief)
                        .transition(.opacity)
                }
                if let notes = muse.notes {
                    MuseNotesView(notes: notes)
                        .opacity(writing ? 0.45 : 1)
                        .transition(.opacity)
                } else if !writing, let missing {
                    Text("notes \u{00B7} \(missing)")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .museAnimation(MuseMotion.dissolve, value: writing)
            .museAnimation(MuseMotion.dissolve, value: muse.notes)
        }
    }

    /// Why a muse long enough for notes has none: the model can't run here. Nil when it can
    /// (they're on their way), or for samples (the model never runs on them).
    private func notesUnavailable(_ muse: Muse) -> String? {
        guard muse.notes == nil, muse.expectedNotes != nil, muse.origin != .sample else { return nil }
        return MuseAI.unavailableNote
    }

    // MARK: Words

    @ViewBuilder
    private func words(_ muse: Muse, hasAudio: Bool) -> some View {
        switch muse.transcriptionState {
        case .pending, .transcribing:
            TranscribingLine()
        case .failed:
            failed(muse, hasAudio: hasAudio)
        case .complete:
            if muse.isBlank || muse.words.isEmpty {
                VStack(alignment: .leading, spacing: MuseSpacing.xs) {
                    Text("blank muse")
                        .font(MuseFont.loraItalic(22))
                        .foregroundStyle(MuseColor.ink55)
                    Text(hasAudio ? "nothing in it sounded like words. the audio is kept." : "nothing in it sounded like words.")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if muse.notes != nil {
                wordsFold(muse)
            } else {
                timedWords(muse)
            }
        }
    }

    private func timedWords(_ muse: Muse) -> some View {
        TimedWordsView(
            muse: muse,
            player: player,
            timings: muse.id == id ? timings : nil,
            titled: Self.title(of: muse) != nil
        )
    }

    /// With notes, the words wait under them: "words · 182 words · 1:23" and a two-line
    /// peek. A tap opens them whole.
    private func wordsFold(_ muse: Muse) -> some View {
        let meta = Self.foldMeta(muse)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleWords()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                    MuseEyebrow("words")
                    Text(meta)
                        .font(MuseType.meta)
                        .monospacedDigit()
                        .foregroundStyle(MuseColor.ink55)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .museSymbol(12, weight: .semibold)
                        .foregroundStyle(MuseColor.ink55)
                        .rotationEffect(.degrees(wordsOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, MuseSpacing.md)
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))
            .accessibilityLabel(wordsOpen ? "hide the words" : "show the words")
            .accessibilityValue(meta)

            if wordsOpen {
                timedWords(muse)
                    .padding(.horizontal, MuseSpacing.md)
                    .padding(.bottom, MuseSpacing.md)
                    .transition(.opacity)
            } else {
                Button {
                    toggleWords()
                } label: {
                    Text(muse.words)
                        .font(MuseFont.lora(15))
                        .lineSpacing(MuseType.bodyLineSpacing + 1)
                        .lineLimit(2)
                        .foregroundStyle(MuseColor.ink70)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask {
                            LinearGradient(
                                colors: [MuseColor.ink, MuseColor.ink, MuseColor.ink.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .padding(.horizontal, MuseSpacing.md)
                        .padding(.bottom, MuseSpacing.md)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
                .transition(.opacity)
            }
        }
        .museInsetSurface(cornerRadius: MuseRadius.tile)
    }

    /// "182 words · 1:23".
    private static func foldMeta(_ muse: Muse) -> String {
        var parts = [wordCount(muse.wordCount)]
        if muse.origin != .typed, muse.duration >= 0.5 { parts.append(muse.duration.museDuration) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private static func wordCount(_ count: Int) -> String {
        count == 1 ? "1 word" : "\(count) words"
    }

    private func toggleWords() {
        MuseHaptics.play(.soft)
        withAnimation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion)) {
            wordsOpen.toggle()
        }
    }

    private func failed(_ muse: Muse, hasAudio: Bool) -> some View {
        VStack(alignment: .leading, spacing: MuseSpacing.sm) {
            Text(hasAudio ? "couldn't transcribe this muse. the voice is still here." : "couldn't transcribe this muse.")
                .font(MuseFont.loraItalic(22))
                .foregroundStyle(MuseColor.ink70)
                .fixedSize(horizontal: false, vertical: true)
            if let reason = muse.transcriptionError?.museQuiet, !reason.isEmpty {
                Text(reason)
                    .font(MuseType.meta)
                    .foregroundStyle(MuseColor.ink55)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasAudio {
                Button {
                    MuseHaptics.play(.light)
                    pipeline.retranscribe(muse.id)
                } label: {
                    Label("retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.muse(.tinted, height: 34))
                .disabled(isWorking(muse))
                .accessibilityLabel("retry transcribing this muse")
            }
        }
    }

    // MARK: Footer

    /// One quiet capsule: how it came in, which engine heard it, how long it is. Copy and
    /// share sit on its right.
    private func footer(_ muse: Muse) -> some View {
        let parts = footerParts(muse)
        return HStack(spacing: MuseSpacing.xs) {
            if muse.origin.isRing {
                OriginDot(origin: muse.origin)
            }
            Text(parts.joined(separator: " \u{00B7} "))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            copyTool(muse)
            shareTool(muse)
        }
        .font(MuseType.meta)
        .monospacedDigit()
        .foregroundStyle(MuseColor.ink55)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.leading, MuseSpacing.row)
        .frame(minHeight: MuseTopChrome.hitTarget)
        .museStock(.inset, in: Capsule())
    }

    /// Once the words land (or don't), and only when it has something to say or offer.
    private func showsFooter(_ muse: Muse) -> Bool {
        guard muse.transcriptionState == .complete || muse.transcriptionState == .failed else { return false }
        return !footerParts(muse).isEmpty || muse.copyWords != nil || muse.audioURL != nil
    }

    /// "streamed · apple · 182 words".
    private func footerParts(_ muse: Muse) -> [String] {
        var parts: [String] = []
        switch muse.origin {
        case .stream: parts.append("streamed")
        case .offline: parts.append("synced")
        case .typed, .sample: break
        }
        if let engine = Self.engineNickname(muse.textModel) { parts.append(engine) }
        if muse.isTranscribed, !muse.isBlank { parts.append(Self.wordCount(muse.wordCount)) }
        return parts
    }

    /// "apple-speech" and "apple-dictation" read "apple", "voz-0.1.0" reads "voz". Typed
    /// and sample muses have no engine to name.
    private static func engineNickname(_ model: String?) -> String? {
        guard let model = model?.lowercased(), !model.isEmpty, model != "typed", model != "sample" else { return nil }
        if model.hasPrefix("apple") { return "apple" }
        if model.hasPrefix("voz") { return "voz" }
        return model.split(separator: "-").first.map(String.init)
    }

    /// With notes, a menu (copy notes, copy words); without, one tap copies the words.
    /// The icon turns into a checkmark for a moment either way.
    @ViewBuilder
    private func copyTool(_ muse: Muse) -> some View {
        if muse.copyNotes != nil {
            Menu {
                MuseExportActions(muse: muse, parts: .copy) { _ in flashCopied() }
            } label: {
                toolIcon(copied ? "checkmark" : "doc.on.doc", tint: copied ? MuseColor.moss600 : MuseColor.ink70)
            }
            .menuStyle(.button)
            .buttonStyle(MusePressStyle(pressedScale: 0.9))
            .accessibilityLabel(copied ? "copied" : "copy")
        } else if let words = muse.copyWords {
            Button {
                UIPasteboard.general.string = words
                MuseHaptics.play(.success)
                flashCopied()
            } label: {
                toolIcon(copied ? "checkmark" : "doc.on.doc", tint: copied ? MuseColor.moss600 : MuseColor.ink70)
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.9))
            .accessibilityLabel(copied ? "copied" : "copy words")
        }
    }

    /// Share notes, share words, share audio: whichever this muse has.
    @ViewBuilder
    private func shareTool(_ muse: Muse) -> some View {
        if muse.shareNotes != nil || muse.shareWords != nil || muse.audioURL != nil {
            Menu {
                MuseExportActions(muse: muse, parts: .share)
            } label: {
                toolIcon("square.and.arrow.up", tint: MuseColor.ink70)
            }
            .menuStyle(.button)
            .buttonStyle(MusePressStyle(pressedScale: 0.9))
            .accessibilityLabel("share")
        }
    }

    /// A raised circle in a 44pt target, the size of a chrome capsule.
    private func toolIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(MuseFont.symbol(13, weight: .medium))
            .foregroundStyle(tint)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: MuseTopChrome.height, height: MuseTopChrome.height)
            .museStock(.chrome, in: Circle())
            .frame(width: MuseTopChrome.hitTarget, height: MuseTopChrome.hitTarget)
            .contentShape(Circle())
    }

    private func flashCopied() {
        withAnimation(MuseMotion.snappy) { copied = true }
        AccessibilityNotification.Announcement("copied").post()
        copyReset?.cancel()
        copyReset = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(MuseMotion.smooth) { copied = false }
        }
    }

    // MARK: Actions

    /// Write the notes again, transcribe again, delete. Delete is the page's one clay mark.
    private func actions(_ muse: Muse, hasAudio: Bool) -> some View {
        HStack(alignment: .top, spacing: MuseSpacing.xs) {
            MuseFlowLayout(spacing: MuseSpacing.xs) {
                redoActions(muse, hasAudio: hasAudio)
            }
            Button(role: .destructive) {
                MuseHaptics.play(.warning)
                confirmingDelete = true
            } label: {
                Label("delete", systemImage: "trash")
            }
            .buttonStyle(.muse(.destructive, height: 34))
            .fixedSize()
            // Clay text has no capsule: its last letter sits on the gutter.
            .padding(.trailing, -MuseSpacing.sm)
        }
    }

    /// Only once the words are in: while it's transcribing there's nothing to redo, and a
    /// failed muse has its own retry.
    @ViewBuilder
    private func redoActions(_ muse: Muse, hasAudio: Bool) -> some View {
        if muse.isTranscribed {
            if muse.expectedNotes != nil {
                Button {
                    MuseHaptics.play(.soft)
                    pipeline.writeNotes(muse.id)
                } label: {
                    Label("write the notes again", systemImage: "list.bullet")
                }
                .buttonStyle(.muse(.secondary, height: 34))
                .disabled(pipeline.noting.contains(muse.id))
            }
            if hasAudio || muse.origin == .sample {
                Button {
                    MuseHaptics.play(.soft)
                    pipeline.retranscribe(muse.id)
                    show("transcribing it again\u{2026}", icon: "arrow.clockwise")
                } label: {
                    Label("transcribe again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.muse(.secondary, height: 34))
                .disabled(isWorking(muse))
            }
        }
    }

    // MARK: For builders

    /// Folded: what your code sees for this muse.
    private func builders(_ muse: Muse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                MuseHaptics.play(.selection)
                withAnimation(MuseMotion.adaptive(MuseMotion.smooth, reduceMotion: reduceMotion)) {
                    showsDetails.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
                    MuseEyebrow("for builders")
                    Text("what your code sees")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .museSymbol(12, weight: .semibold)
                        .foregroundStyle(MuseColor.ink55)
                        .rotationEffect(.degrees(showsDetails ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: MuseTopChrome.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(MusePressStyle(pressedScale: 0.98))
            .accessibilityLabel("for builders")
            .accessibilityValue(showsDetails ? "open" : "closed")
            .accessibilityHint(showsDetails ? "hides what your code sees" : "shows what your code sees")

            if showsDetails {
                VStack(alignment: .leading, spacing: MuseSpacing.md) {
                    MuseCodeLine(details(muse), caption: "this muse, as your code sees it")
                    if let audio = muse.audioURL {
                        MuseCodeLine(audio.path, caption: "muse.audioURL")
                    }
                    Text("find it in code with store.muse(id:). hear about the next one with MuseHooks.onTranscribed.")
                        .font(MuseType.meta)
                        .foregroundStyle(MuseColor.ink55)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, MuseSpacing.xxs)
                .transition(.opacity)
            }
        }
        .task(id: showsDetails ? muse.transcript : nil) {
            guard showsDetails else { return }
            timingNote = await Self.describeTimings(muse.id, injected: muse.id == id ? timings : nil)
        }
    }

    /// Key and value lines, aligned, for the code block.
    private func details(_ muse: Muse) -> String {
        let rows: [(String, String)] = [
            ("id", muse.id.uuidString.lowercased()),
            ("origin", ".\(muse.origin.rawValue)"),
            ("state", ".\(muse.transcriptionState.rawValue)"),
            ("words", "\(muse.wordCount)"),
            ("notes", muse.notes.map { ".\($0.kind.rawValue) · \($0.model)" } ?? "none"),
            ("title", muse.title == nil ? "none" : (muse.titleIsTheirs ? "theirs" : "the model's")),
            ("engine", muse.textModel ?? "none"),
            ("language", muse.language ?? "none"),
            ("confidence", muse.wordConfidence.map { String(format: "%.2f", $0) } ?? "none"),
            ("timings", timingNote ?? "none"),
            ("audio", muse.audioFileName ?? "none"),
            ("source", muse.sourceFileName ?? "none"),
        ]
        let width = rows.map(\.0.count).max() ?? 0
        return rows
            .map { key, value in key.padding(toLength: width + 2, withPad: " ", startingAt: 0) + value }
            .joined(separator: "\n")
    }

    /// "42 words · apple-speech" from the saved timings, off the main actor.
    @concurrent
    nonisolated private static func describeTimings(_ id: UUID, injected: TimedTranscript?) async -> String? {
        guard let timed = injected ?? TimedTranscriptStore.load(id), !timed.words.isEmpty else { return nil }
        return "\(timed.words.count) words · \(timed.timingModel)"
    }

    // MARK: Bottom bar

    @ViewBuilder
    private func bottomBar(audio: URL?, hasAudio: Bool) -> some View {
        // Live: whenever the muse has audio. Lab and previews: whenever the stand-in
        // player has a length (its bars are a sample shape).
        if hasAudio {
            VStack(spacing: MuseSpacing.sm) {
                if SpeechSettings.shared.studioSound, StudioSound.isAvailable {
                    // A fresh picker for each muse: the player starts every muse raw.
                    StudioSoundPicker(player: player) { note in show(note, icon: "waveform") }
                        .id(shownID)
                }
                ListenCapsule(audioURL: audio, player: player)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, MuseSpacing.xs)
        } else {
            // Hosts the soft fade at the bottom edge when there's nothing to play.
            Color.clear
                .frame(height: MuseSpacing.xs)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Gone

    /// The muse isn't in the store: deleted here (the page is closing), or elsewhere.
    private var gone: some View {
        VStack(spacing: MuseSpacing.md) {
            if !deletedHere {
                Text("this muse was deleted.")
                    .font(MuseType.titleSmall)
                    .foregroundStyle(MuseColor.ink70)
                Button("close") { close() }
                    .buttonStyle(.muse(.secondary))
            }
        }
        .padding(.horizontal, MuseSpacing.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Deleted somewhere else while it played: the voice goes with it.
        .onAppear { player.stop() }
    }

    // MARK: - Browsing

    /// The muses this page can step through, newest first: the pool the page opened with,
    /// less any deleted since. Just this one when it opened alone.
    private func neighbors(of current: UUID) -> (newer: UUID?, older: UUID?) {
        guard !router.musePool.isEmpty else { return (nil, nil) }
        let wanted = Set(router.musePool)
        // `store.muses` is newest first, so the pool comes out in time order.
        let pool = store.muses.lazy.filter { wanted.contains($0.id) }.map(\.id)
        let ids = Array(pool)
        guard let index = ids.firstIndex(of: current) else { return (nil, nil) }
        let newer = index > 0 ? ids[index - 1] : nil
        let older = index + 1 < ids.count ? ids[index + 1] : nil
        return (newer, older)
    }

    /// A sideways swipe. Ignored while the title is open, where a drag moves the caret.
    private func swipe(older: Bool) {
        guard !editingTitle else { return }
        let near = neighbors(of: shownID)
        go(to: older ? near.older : near.newer, step: older ? 1 : -1)
    }

    /// Steps to a neighbor. `direction` 1 is older, -1 newer.
    private func go(to next: UUID?, step direction: Int) {
        guard let next, next != shownID else { return }
        MuseHaptics.play(.soft)
        if editingTitle { finishTitle(save: false) }
        // The leaving page takes this lean first, then the swap happens a beat later, so
        // both pages move the same way.
        step = direction
        Task { @MainActor in
            resetForNewMuse()
            shownID = next
        }
    }

    private func resetForNewMuse() {
        copyReset?.cancel()
        copied = false
        wordsOpen = false
        showsDetails = false
        timingNote = nil
        titleDraft = ""
    }

    // MARK: - Title

    private func canEditTitle(_ muse: Muse) -> Bool {
        muse.isTranscribed && !muse.isBlank
    }

    private func beginTitleEdit(_ muse: Muse) {
        guard canEditTitle(muse), !editingTitle else { return }
        MuseHaptics.play(.soft)
        titleDraft = Self.title(of: muse) ?? ""
        editingTitle = true
        titleFocused = true
    }

    /// Save writes their title onto the muse (`MuseStore.setTitle`), and the model never
    /// replaces it. Empty or unchanged keeps what was there. Case counts: "call with priya"
    /// to "call with Priya" is a change worth saving.
    private func finishTitle(save: Bool) {
        guard editingTitle else { return }
        editingTitle = false
        titleFocused = false
        guard save, let muse = store.muse(id: shownID) else { return }
        let cleaned = titleDraft
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != (Self.title(of: muse) ?? "") else { return }
        store.setTitle(cleaned, for: muse.id)
        MuseHaptics.play(.success)
    }

    // MARK: - Actions

    private func isWorking(_ muse: Muse) -> Bool {
        pipeline.working.contains(muse.id) || muse.transcriptionState == .transcribing
    }

    private func show(_ message: String, icon: String = "checkmark") {
        toastIcon = icon
        toast = message
    }

    private func close() {
        player.stop()
        router.close()
    }

    /// Deletes, then lands on the older neighbor, else the newer one, else closes.
    private func delete(_ gone: UUID) {
        // An open title editor belongs to the muse going away: close it unsaved, so it
        // doesn't carry over to the neighbor.
        if editingTitle { finishTitle(save: false) }
        let near = neighbors(of: gone)
        MuseHaptics.play(.done)
        guard let next = near.older ?? near.newer else {
            player.stop()
            deletedHere = true
            store.remove(gone)
            router.close()
            return
        }
        step = near.older != nil ? 1 : -1
        Task { @MainActor in
            resetForNewMuse()
            // In one beat, so the page slides to the neighbor instead of flashing "deleted".
            shownID = next
            store.remove(gone)
        }
    }
}

// MARK: - Origin dot

/// The ring's light, as it was: white while streaming, amber for memory.
private struct OriginDot: View {
    let origin: MuseOrigin
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(origin == .offline ? MuseColor.ringAmber : MuseColor.composer)
            .overlay {
                if origin != .offline {
                    Circle().strokeBorder(MuseColor.ink.opacity(0.22), lineWidth: 0.75)
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Browse swipe

/// A sideways swipe on the page steps to the older muse (swipe left) or the newer one
/// (swipe right). A UIKit pan that only starts when the finger moves more sideways than
/// down, and runs beside the scroll view's own, so vertical scrolling never waits on it.
private struct BrowseSwipe: UIGestureRecognizerRepresentable {
    var onOlder: () -> Void
    var onNewer: () -> Void

    /// How far a swipe has to travel, with its momentum, to count.
    private static let distance: CGFloat = 56
    /// A flick this fast counts however short it is.
    private static let speed: CGFloat = 480

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        guard pan.state == .ended else { return }
        let travel = pan.translation(in: pan.view)
        let velocity = pan.velocity(in: pan.view)
        guard abs(travel.x) > abs(travel.y) else { return }
        let projected = travel.x + velocity.x * 0.18
        if projected < -Self.distance || velocity.x < -Self.speed {
            onOlder()
        } else if projected > Self.distance || velocity.x > Self.speed {
            onNewer()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer, let host = pan.view else { return true }
            let velocity = pan.velocity(in: host)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }
            // A sideways scroller under the finger (the builders' code block) keeps its swipe.
            var node = host.hitTest(pan.location(in: host), with: nil)
            while let view = node, view !== host {
                if let scroll = view as? UIScrollView, scroll.contentSize.width > scroll.bounds.width + 1 {
                    return false
                }
                node = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - Transcribing

/// "transcribing this muse…" with a moss dot breathing beside it, the home card's skeleton
/// (0.24 to 0.52 over 1.85s) at the page's size. Still under Reduce Motion.
private struct TranscribingLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Half Lora's x-height at 22pt: the dot sits mid-letter on the first line, at any size.
    @ScaledMetric(relativeTo: .title2) private var midLetter: CGFloat = 5.5

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MuseSpacing.xs) {
            dot
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + midLetter }
            Text("transcribing this muse\u{2026}")
                .font(MuseFont.loraItalic(22))
                .foregroundStyle(MuseColor.ink55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("transcribing this muse")
    }

    /// Scoped to the dot, so the breath never reaches the page's layout.
    @ViewBuilder
    private var dot: some View {
        let circle = Circle()
            .fill(MuseColor.moss600)
            .frame(width: 6, height: 6)
        if reduceMotion {
            circle.opacity(0.4)
        } else {
            circle.phaseAnimator([0.24, 0.52]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 1.85)
            }
        }
    }
}

// MARK: - Previews

private enum MusePagePreview {
    static let words = "okay so the sign for the shop. i think it should just say open, lowercase, painted straight onto the glass. and remind me to call mum back about it tonight."
    static let id = UUID()

    static let muse = Muse(
        id: id,
        createdAt: .now.addingTimeInterval(-600),
        duration: 14,
        origin: .stream,
        transcript: words,
        transcriptionState: .complete,
        title: "the sign for the shop",
        language: "en",
        wordConfidence: 0.91,
        textModel: "apple-speech",
        audioFileName: "preview.wav",
        sourceFileName: "preview.ogg",
        arrivedAt: .now.addingTimeInterval(-580)
    )

    static func page(_ muse: Muse, player: MuseAudioPlayer, timings: TimedTranscript? = nil) -> some View {
        let store = MuseStore.preview([muse])
        return MuseDetailView(id: muse.id, player: player, timings: timings)
            .environment(store)
            .environment(MusePipeline.preview(store))
            .environment(AppRouter())
    }

    /// The samples, every one in the pool so the chevrons browse.
    static func samples(_ id: UUID, noting: Set<UUID> = []) -> some View {
        let samples = SampleMuses.make()
        let store = MuseStore.preview(samples)
        let router = AppRouter()
        router.musePool = samples.map(\.id)
        return MuseDetailView(id: id, player: .preview(duration: 0, playing: false))
            .environment(store)
            .environment(MusePipeline.preview(store, noting: noting))
            .environment(router)
    }
}

#Preview("muse page · playing") {
    MusePagePreview.page(
        MusePagePreview.muse,
        player: .preview(duration: 14),
        timings: TimedWordsView.sampleTimings(for: MusePagePreview.words, duration: 14)
    )
}

#Preview("muse page · brief") {
    MusePagePreview.samples(SampleMuses.cardID)
}

#Preview("muse page · long thought") {
    MusePagePreview.samples(SampleMuses.marketID)
}

#Preview("muse page · transcribing") {
    var muse = MusePagePreview.muse
    muse.transcriptionState = .transcribing
    muse.transcript = nil
    muse.title = nil
    return MusePagePreview.page(muse, player: .preview(duration: 14, playing: false))
}

#Preview("muse page · failed") {
    var muse = MusePagePreview.muse
    muse.transcriptionState = .failed
    muse.transcriptionError = "this recording can't be read."
    muse.transcript = nil
    muse.title = nil
    return MusePagePreview.page(muse, player: .preview(duration: 14, playing: false))
}

#Preview("muse page · blank") {
    MusePagePreview.samples(SampleMuses.blankID)
}

#Preview("muse page · deleted") {
    let store = MuseStore.preview([])
    MuseDetailView(id: UUID(), player: .preview(duration: 0, playing: false))
        .environment(store)
        .environment(MusePipeline.preview(store))
        .environment(AppRouter())
}
