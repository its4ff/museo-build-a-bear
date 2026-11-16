import AppKit
import Foundation
import MuseoKit
import Observation

/// One recording on this mac.
nonisolated struct MacMuse: Codable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    /// "streamed" (a hold), "memory" (brought in from the ring), or "note" (written in a
    /// museo note: no audio, and `audioFile` is empty).
    var origin: String
    var audioFile: String
    var words: String?
    /// Which model heard it: "apple speech".
    var model: String?
    /// The app its words were typed into, when they were.
    var typedInto: String?
    /// Its words were sent there too (return pressed): "sent to Claude".
    var wasSent: Bool?
    /// From the ring's memory and not looked at yet: amber until it is.
    var unseen: Bool?

    /// Kept with the bookmark: shown under "saved".
    var saved: Bool?
    /// A note's name: written by museo when it ends, or typed by you (`nameIsTheirs`).
    var name: String?
    var nameIsTheirs: Bool?

    var isNote: Bool { origin == "note" }
    var isStreamed: Bool { origin == "streamed" }
    /// Recorded, so it has audio: everything but a note.
    var hasAudio: Bool { !isNote && !audioFile.isEmpty }

    var isFromRing: Bool { origin == "memory" }

    /// Where its words went, short: "into Notes", "sent to Claude". Nil when they weren't
    /// typed anywhere that said its name.
    var landing: String? {
        guard let typedInto else { return nil }
        return wasSent == true ? "sent to \(typedInto)" : "into \(typedInto)"
    }
    var isSaved: Bool { saved == true }
    var isUnseen: Bool { unseen == true }

    /// A title from its own words until titles are written on this mac: the first sentence,
    /// seven words at most.
    var title: String {
        if let name, !name.isEmpty { return name }
        guard let words, !words.isEmpty else { return words == nil ? "hearing it…" : "blank muse" }
        let sentence = words.split(whereSeparator: { ".?!".contains($0) }).first.map(String.init) ?? words
        let picked = sentence.split(separator: " ").prefix(7)
        let cut = picked.count < sentence.split(separator: " ").count
        return picked.joined(separator: " ") + (cut ? "…" : "")
    }

    /// "streamed · 0:06", "from the ring · 12:04", "note · 212 words".
    var meta: String {
        if isNote {
            let count = MacLibrary.wordCount(words ?? "")
            return "note · \(count) \(count == 1 ? "word" : "words")"
        }
        return "\(isFromRing ? "from the ring" : "streamed") · \(duration.museDuration)"
    }
}

/// Every recording the ring hands this mac, kept in ~/Library/Application Support/museo mac.
///
/// The kit's rule holds here too: save first, then return true, and only then may the ring
/// let go of its copy. Memory recordings stay on the ring anyway (clearsRingAfterSync is off).
///
/// Memory recordings come over when you click "bring in" in the panel, never on their own,
/// and are never typed: they land long after they were made. The panel's row shows them
/// coming in (the island is for holds only), each waits here in amber, and ⌥⌘V pastes the
/// newest muse where you are.
@MainActor
@Observable
final class MacLibrary {
    static let shared = MacLibrary()

    nonisolated enum Filter: CaseIterable, Sendable {
        case all, streamed, ring, saved
    }

    private(set) var muses: [MacMuse] = []
    /// The muse open in the library window. The panel's recent list sets it. With several
    /// picked, it's where a shift click measures from.
    var selection: UUID?
    /// Muses picked with ⌘ or shift click, to copy or delete together. Empty, or just one,
    /// means only `selection`.
    var picked: Set<UUID> = []
    /// Your stats in place of the open muse. Opening a muse closes them.
    var showsStats = false

    /// New muses with fewer words than `shortWords` (blank ones too) aren't kept: once their
    /// words are heard, they leave with their audio. Off at first. Muses already here stay.
    var leavesOutShort = UserDefaults.standard.bool(forKey: "leavesOutShort") {
        didSet { UserDefaults.standard.set(leavesOutShort, forKey: "leavesOutShort") }
    }
    var shortWords = UserDefaults.standard.object(forKey: "shortWords") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(shortWords, forKey: "shortWords") }
    }
    static let shortWordsRange = 1...20

    /// Short muses left out of the library, kept only for the panel's recent list. In memory:
    /// gone when museo quits, and their audio is already deleted.
    private(set) var leftOut: [MacMuse] = []

    /// The newest muses with words, for the panel: the library's and the short ones left out.
    func recent(_ count: Int) -> [MacMuse] {
        (muses + leftOut)
            .filter { !$0.isNote && !($0.words ?? "").isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(count)
            .map { $0 }
    }

    func isLeftOut(_ id: UUID) -> Bool { leftOut.contains { $0.id == id } }

    /// Recordings from the ring nobody has looked at yet.
    var unseenCount: Int { muses.filter(\.isUnseen).count }

    let folder: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("museo mac", isDirectory: true)
    }()
    private var audioFolder: URL { folder.appendingPathComponent("audio", isDirectory: true) }
    private var indexURL: URL { folder.appendingPathComponent("muses.json") }

    /// Where the last hold was typed, until its recording lands.
    @ObservationIgnored private var typedLately: (app: String?, sent: Bool, at: Date)?
    /// When a hold that ran as a voice command began, until its recording lands.
    @ObservationIgnored private var commandHolds: [Date] = []

    func start() {
        try? FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode([MacMuse].self, from: data) {
            muses = saved
        }
        Museo.onCapture { [weak self] capture, seenBefore in
            guard !seenBefore else { return true }
            return self?.save(capture) ?? false
        }
        Museo.takeWaitingCaptures()
        // Catch up words for anything saved before they were heard, or heard as nothing
        // (cheap: a blank one is a few seconds of audio).
        for muse in muses where muse.hasAudio && (muse.words ?? "").isEmpty { transcribe(muse.id) }
    }

    #if DEBUG
    /// The saved muses, without starting the ring (for `ScreenSheet`).
    /// Made-up muses in memory only, never saved: for the README's pictures (`ReadmeShots`).
    func useSamples(_ samples: [MacMuse]) {
        muses = samples
        selection = nil
    }

    func loadForPreview() {
        if let data = try? Data(contentsOf: indexURL), let saved = try? JSONDecoder().decode([MacMuse].self, from: data) {
            muses = saved
        }
    }
    #endif

    func muses(_ filter: Filter) -> [MacMuse] {
        switch filter {
        case .all: muses
        case .streamed: muses.filter(\.isStreamed)
        case .ring: muses.filter(\.isFromRing)
        case .saved: muses.filter(\.isSaved)
        }
    }

    // MARK: - Saving

    private func save(_ capture: CompletedCapture) -> Bool {
        let source = RingBLEManager.capturesDirectory.appendingPathComponent(capture.wavFileName ?? capture.fileName)
        let name = "\(capture.id.uuidString).\(source.pathExtension.isEmpty ? "wav" : source.pathExtension)"
        let destination = audioFolder.appendingPathComponent(name)
        let fromRing = capture.source != .stream
        // A hold that ran a command ("switch tab") isn't a muse: let it go without keeping it.
        // The ring keeps nothing of a streamed hold, so there's nothing to lose by saying yes.
        if !fromRing, let index = commandHolds.firstIndex(where: { abs($0.timeIntervalSince(capture.startedAt)) < Self.sameHold }) {
            commandHolds.remove(at: index)
            print("[museo][mac] a command hold: not kept")
            return true
        }
        do {
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: source, to: destination)
            }
            var muse = MacMuse(
                id: capture.id,
                createdAt: capture.startedAt,
                duration: capture.duration,
                origin: fromRing ? "memory" : "streamed",
                audioFile: name,
                model: MacSpeech.inUse.name
            )
            if fromRing {
                muse.unseen = true
            } else if let typed = typedLately, Date.now.timeIntervalSince(typed.at) < 20 {
                muse.typedInto = typed.app
                if typed.sent { muse.wasSent = true }
                typedLately = nil
            }
            muses.insert(muse, at: 0)
            try flush()
            print("[museo][mac] saved \(muse.origin) \(Int(capture.duration))s")
            transcribe(muse.id, isNew: true)
            return true
        } catch {
            print("[museo][mac] couldn't save a recording:", error.localizedDescription)
            muses.removeAll { $0.id == capture.id }
            return false
        }
    }

    /// How far apart a hold's start and its recording's start can be and still be one hold.
    private static let sameHold: TimeInterval = 5

    /// A hold that began at `start` ran as a voice command: it doesn't stay in the library.
    /// Its recording may have landed already, or land after this.
    func forgetCommandHold(startedAt start: Date) {
        if let index = muses.firstIndex(where: { $0.isStreamed && abs($0.createdAt.timeIntervalSince(start)) < Self.sameHold }) {
            let muse = muses.remove(at: index)
            removeAudio(of: muse)
            try? flush()
            if selection == muse.id { selection = muses.first?.id }
            print("[museo][mac] a command hold: removed")
        } else {
            commandHolds.append(start)
            commandHolds.removeAll { Date.now.timeIntervalSince($0) > 120 }
        }
    }

    /// A hold's words were typed into `app` (and sent, when `sent`). Its recording may land
    /// before or after this.
    func noteTyped(into app: String?, sent: Bool = false) {
        if let index = muses.firstIndex(where: \.isStreamed),
           muses[index].typedInto == nil,
           Date.now.timeIntervalSince(muses[index].createdAt) < 60 {
            muses[index].typedInto = app
            if sent { muses[index].wasSent = true }
            try? flush()
        } else {
            typedLately = (app, sent, .now)
        }
    }

    // MARK: - Pasting

    /// ⌥⌘V: the newest muse with words, pasted where you are.
    func pasteNewest() {
        guard let index = muses.firstIndex(where: { !$0.isNote && !($0.words ?? "").isEmpty }),
              let words = muses[index].words else { return }
        let landing = TextInserter.insert(words + " ")
        muses[index].unseen = false
        if case .typed(let target?) = landing, muses[index].typedInto == nil { muses[index].typedInto = target }
        try? flush()
        if landing != .copied { RingWatch.shared.flashTyped() }
    }

    // MARK: - Reading and removing

    func audioURL(for muse: MacMuse) -> URL {
        audioFolder.appendingPathComponent(muse.audioFile)
    }

    /// Saves a muse with the bookmark, or lets it go back to the rest.
    func toggleSaved(_ id: UUID) {
        guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
        muses[index].saved = muses[index].isSaved ? nil : true
        try? flush()
    }

    /// Opened in the library: no longer amber.
    func markSeen(_ id: UUID) {
        guard let index = muses.firstIndex(where: { $0.id == id }), muses[index].isUnseen else { return }
        muses[index].unseen = false
        try? flush()
    }

    /// Deletes a muse and its audio from this mac. The ring keeps its own copy of a memory
    /// recording; nothing here touches the ring.
    func remove(_ id: UUID) {
        guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
        let muse = muses.remove(at: index)
        removeAudio(of: muse)
        try? flush()
        if selection == id { selection = muses.first?.id }
    }

    /// Deletes several muses and their audio from this mac, like `remove` one at a time.
    func remove(_ ids: Set<UUID>) {
        let gone = muses.filter { ids.contains($0.id) }
        for muse in gone { removeAudio(of: muse) }
        muses.removeAll { ids.contains($0.id) }
        try? flush()
        picked = []
        if let selection, ids.contains(selection) { self.selection = muses.first?.id }
    }

    /// The words of several muses, oldest first, a blank line between them. Blank ones are
    /// left out.
    func words(of ids: Set<UUID>) -> String {
        muses.filter { ids.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { ($0.words ?? "").isEmpty ? nil : $0.words }
            .joined(separator: "\n\n")
    }

    /// Deletes a muse's audio. A note has none: its empty file name would name the audio
    /// folder itself, so it's never passed on.
    private func removeAudio(of muse: MacMuse) {
        guard muse.hasAudio else { return }
        try? FileManager.default.removeItem(at: audioURL(for: muse))
    }

    // MARK: - Notes

    /// Writes a note's words, adding it the first time. Saved to disk a moment after the last
    /// change, so typing doesn't write the file on every key.
    func saveNote(_ id: UUID, words: String, startedAt: Date) {
        if let index = muses.firstIndex(where: { $0.id == id }) {
            guard muses[index].words != words else { return }
            muses[index].words = words
        } else {
            var note = MacMuse(id: id, createdAt: startedAt, duration: 0, origin: "note", audioFile: "")
            note.words = words
            muses.insert(note, at: 0)
            muses.sort { $0.createdAt > $1.createdAt }
        }
        flushSoon()
    }

    /// Names a note: `theirs` when you typed it, so museo never writes over it.
    func nameNote(_ id: UUID, _ name: String, theirs: Bool) {
        guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
        if !theirs, muses[index].nameIsTheirs == true { return }
        muses[index].name = name
        muses[index].nameIsTheirs = theirs ? true : nil
        try? flush()
    }

    /// A note left with nothing in it isn't kept.
    func dropNote(_ id: UUID) {
        guard let index = muses.firstIndex(where: { $0.id == id }), muses[index].isNote else { return }
        muses.remove(at: index)
        try? flush()
        if selection == id { selection = muses.first?.id }
    }

    func note(_ id: UUID) -> MacMuse? {
        muses.first { $0.id == id && $0.isNote }
    }

    @ObservationIgnored private var pendingFlush: Task<Void, Never>?

    private func flushSoon() {
        pendingFlush?.cancel()
        pendingFlush = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? flush()
        }
    }

    private func flush() throws {
        let data = try JSONEncoder().encode(muses)
        try data.write(to: indexURL, options: .atomic)
    }

    /// Hears a muse's audio. A new one that comes out short, with "leave out short muses" on,
    /// isn't kept. One that couldn't be heard at all (nil) always stays.
    private func transcribe(_ id: UUID, isNew: Bool = false, then: ((String?) -> Void)? = nil) {
        guard let muse = muses.first(where: { $0.id == id }) else { return }
        let url = audioFolder.appendingPathComponent(muse.audioFile)
        Task {
            let words = await MacSpeech.transcribe(url)
            guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
            if isNew, leavesOutShort, let words, Self.wordCount(words) < shortWords, !muses[index].isSaved {
                print("[museo][mac] a short muse: not kept")
                var gone = muses[index]
                gone.words = words
                leftOut.insert(gone, at: 0)
                leftOut = Array(leftOut.prefix(5))
                remove(id)
                then?(words)
                return
            }
            muses[index].words = words ?? ""
            try? flush()
            then?(words)
        }
    }

    /// Words with a letter or digit in them: "ok." is one, "…" is none.
    nonisolated static func wordCount(_ words: String) -> Int {
        words.split(whereSeparator: \.isWhitespace)
            .filter { $0.contains { $0.isLetter || $0.isNumber } }
            .count
    }
}
