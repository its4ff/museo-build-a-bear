import AppKit
import Foundation
import MuseoKit
import Observation

/// One recording on this mac.
nonisolated struct MacMuse: Codable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    /// "streamed" (a hold) or "memory" (brought in from the ring).
    var origin: String
    var audioFile: String
    var words: String?
    /// Which model heard it: "apple speech".
    var model: String?
    /// The app its words were typed into, when they were.
    var typedInto: String?
    /// From the ring's memory and not looked at yet: amber until it is.
    var unseen: Bool?

    var isFromRing: Bool { origin == "memory" }
    var isUnseen: Bool { unseen == true }

    /// A title from its own words until titles are written on this mac: the first sentence,
    /// seven words at most.
    var title: String {
        guard let words, !words.isEmpty else { return words == nil ? "hearing it…" : "blank muse" }
        let sentence = words.split(whereSeparator: { ".?!".contains($0) }).first.map(String.init) ?? words
        let picked = sentence.split(separator: " ").prefix(7)
        let cut = picked.count < sentence.split(separator: " ").count
        return picked.joined(separator: " ") + (cut ? "…" : "")
    }

    /// "streamed · 0:06", "from the ring · 12:04".
    var meta: String {
        "\(isFromRing ? "from the ring" : "streamed") · \(duration.museDuration)"
    }
}

/// Every recording the ring hands this mac, kept in ~/Library/Application Support/museo mac.
///
/// The kit's rule holds here too: save first, then return true, and only then may the ring
/// let go of its copy. Memory recordings stay on the ring anyway (clearsRingAfterSync is off).
///
/// A memory recording that comes over fresh (stopped under 2 minutes ago, up to 3 minutes
/// long, the same app in front, a text field focused) is typed in like a hold. Anything else
/// waits here in amber, and ⌥⌘V pastes the newest muse.
@MainActor
@Observable
final class MacLibrary {
    static let shared = MacLibrary()

    nonisolated enum Filter: CaseIterable, Sendable {
        case all, streamed, ring
    }

    private(set) var muses: [MacMuse] = []
    /// The muse open in the library window. The panel's recent list sets it.
    var selection: UUID?

    /// Recordings from the ring nobody has looked at yet.
    var unseenCount: Int { muses.filter(\.isUnseen).count }

    let folder: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("museo mac", isDirectory: true)
    }()
    private var audioFolder: URL { folder.appendingPathComponent("audio", isDirectory: true) }
    private var indexURL: URL { folder.appendingPathComponent("muses.json") }

    /// Where the last hold was typed, until its recording lands.
    @ObservationIgnored private var typedLately: (app: String?, at: Date)?

    /// Fresh means stopped this recently.
    private static let freshFor: TimeInterval = 120
    /// Longer than this, a fresh recording asks (⌥⌘V) instead of typing itself.
    private static let longest: TimeInterval = 180
    private static let model = "apple speech"

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
        for muse in muses where (muse.words ?? "").isEmpty { transcribe(muse.id) }
    }

    func muses(_ filter: Filter) -> [MacMuse] {
        switch filter {
        case .all: muses
        case .streamed: muses.filter { !$0.isFromRing }
        case .ring: muses.filter(\.isFromRing)
        }
    }

    // MARK: - Saving

    private func save(_ capture: CompletedCapture) -> Bool {
        let source = RingBLEManager.capturesDirectory.appendingPathComponent(capture.wavFileName ?? capture.fileName)
        let name = "\(capture.id.uuidString).\(source.pathExtension.isEmpty ? "wav" : source.pathExtension)"
        let destination = audioFolder.appendingPathComponent(name)
        let fromRing = capture.source != .stream
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
                model: Self.model
            )
            if fromRing {
                muse.unseen = true
            } else if let typed = typedLately, Date.now.timeIntervalSince(typed.at) < 20 {
                muse.typedInto = typed.app
                typedLately = nil
            }
            muses.insert(muse, at: 0)
            try flush()
            print("[museo][mac] saved \(muse.origin) \(Int(capture.duration))s")
            let recording = fromRing ? RingWatch.shared.takeLastRecording() : nil
            transcribe(muse.id) { [weak self] words in
                guard fromRing, let recording else { return }
                self?.landFromRing(muse.id, words: words, recording: recording)
            }
            return true
        } catch {
            print("[museo][mac] couldn't save a recording:", error.localizedDescription)
            muses.removeAll { $0.id == capture.id }
            return false
        }
    }

    /// A hold's words were typed into `app`. Its recording may land before or after this.
    func noteTyped(into app: String?) {
        if let index = muses.firstIndex(where: { !$0.isFromRing }),
           muses[index].typedInto == nil,
           Date.now.timeIntervalSince(muses[index].createdAt) < 60 {
            muses[index].typedInto = app
            try? flush()
        } else {
            typedLately = (app, .now)
        }
    }

    // MARK: - From the ring

    /// The fresh rule: type a memory recording in only when it's fresh, short enough, and
    /// headed back where it started. Otherwise it waits, amber.
    private func landFromRing(_ id: UUID, words: String?, recording: (stopped: Date, app: String?)) {
        guard let words, !words.isEmpty, let index = muses.firstIndex(where: { $0.id == id }) else { return }
        let muse = muses[index]
        guard Date.now.timeIntervalSince(recording.stopped) < Self.freshFor else { return }
        guard muse.duration <= Self.longest else {
            FlowBar.shared.ring(words, note: "\(muse.duration.museDuration) from the ring · ⌥⌘V to paste")
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        guard Dictation.shared.typesIntoApps, TextInserter.canType,
              front?.bundleIdentifier == recording.app, TextInserter.isTypingSomewhere,
              TextInserter.insert(words + " ")
        else {
            FlowBar.shared.ring(words, note: "from the ring · ⌥⌘V to paste")
            return
        }
        muses[index].unseen = false
        muses[index].typedInto = front?.localizedName
        try? flush()
        RingWatch.shared.flashTyped()
        FlowBar.shared.ring(words, note: front?.localizedName.map { "from the ring · typed into \($0)" } ?? "from the ring · typed")
    }

    /// ⌥⌘V: the newest muse with words, pasted where you are.
    func pasteNewest() {
        guard let index = muses.firstIndex(where: { !($0.words ?? "").isEmpty }),
              let words = muses[index].words else { return }
        let app = NSWorkspace.shared.frontmostApplication?.localizedName
        let typed = TextInserter.insert(words + " ")
        muses[index].unseen = false
        if typed, muses[index].typedInto == nil { muses[index].typedInto = app }
        try? flush()
        if typed { RingWatch.shared.flashTyped() }
    }

    // MARK: - Reading and removing

    func audioURL(for muse: MacMuse) -> URL {
        audioFolder.appendingPathComponent(muse.audioFile)
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
        try? FileManager.default.removeItem(at: audioURL(for: muse))
        try? flush()
        if selection == id { selection = muses.first?.id }
    }

    private func flush() throws {
        let data = try JSONEncoder().encode(muses)
        try data.write(to: indexURL, options: .atomic)
    }

    private func transcribe(_ id: UUID, then: ((String?) -> Void)? = nil) {
        guard let muse = muses.first(where: { $0.id == id }) else { return }
        let url = audioFolder.appendingPathComponent(muse.audioFile)
        Task {
            let words = await MacSpeech.transcribe(url)
            guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
            muses[index].words = words ?? ""
            try? flush()
            then?(words)
        }
    }
}
