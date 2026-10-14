import Foundation
import Observation
import OSLog

/// Every muse on this phone, newest first. A JSON file in `Documents/MuseBuild/muses.json`.
///
/// Read `muses` from any view. Change muses only through `insert`, `update`, `setTitle`
/// and `remove` so hooks fire and the file stays in step. To react to muses from
/// your own code, use `MuseHooks` (arrived, transcribed, removed), not this class.
///
/// Changes land in memory at once and reach the file a moment later, off the main
/// thread, every change in one main-actor turn in one write. `flush()` writes now, for
/// when a muse must be on disk before something else happens (the ring retiring its
/// copy, the app going to the background).
@MainActor
@Observable
final class MuseStore {
    static let shared = MuseStore()

    /// Newest first, by `createdAt`.
    private(set) var muses: [Muse] = []

    @ObservationIgnored private let fileURL: URL
    /// False for previews, and for the live store while muses.json exists but can't be read
    /// (the iphone is still locked after a restart, a passing disk error) or was only partly
    /// read with no copy kept. Nothing is written then, and `flush()` says so.
    @ObservationIgnored private var canWrite = true
    @ObservationIgnored private var isPreview = false
    /// muses.json was there but couldn't be read. `reloadIfNeeded()` tries again.
    @ObservationIgnored private var needsReload = false
    /// Saves encode and write here, in order, off the main thread.
    @ObservationIgnored private let writer = DispatchQueue(label: "museo.build.store.save", qos: .utility)
    /// A write is waiting for the end of this main-actor turn.
    @ObservationIgnored private var writeQueued = false

    nonisolated private static let log = Logger(subsystem: "museo.build", category: "store")

    init(fileURL: URL = MuseFiles.library.appendingPathComponent("muses.json")) {
        self.fileURL = fileURL
        load()
    }

    /// An in-memory store for previews and lab screens. Never touches disk.
    static func preview(_ muses: [Muse]) -> MuseStore {
        let store = MuseStore(fileURL: URL(fileURLWithPath: "/dev/null"))
        store.canWrite = false
        store.isPreview = true
        store.muses = muses.sorted { $0.createdAt > $1.createdAt }
        return store
    }

    // MARK: - Read

    /// The store can save. False while muses.json is there but couldn't be read yet: code
    /// that sweeps files muses point at (delete everything) waits.
    var isWritable: Bool { canWrite }

    func muse(id: UUID) -> Muse? {
        muses.first { $0.id == id }
    }

    /// Muses grouped by calendar day, newest day first.
    var days: [(day: Date, muses: [Muse])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: muses) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    func muses(on day: Date) -> [Muse] {
        let calendar = Calendar.current
        return muses.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    // MARK: - Write

    /// Adds a muse in time order (an offline muse from this morning lands below this afternoon's).
    func insert(_ muse: Muse) {
        if let index = muses.firstIndex(where: { $0.id == muse.id }) {
            muses[index] = muse
        } else {
            let index = muses.firstIndex { $0.createdAt < muse.createdAt } ?? muses.endIndex
            muses.insert(muse, at: index)
        }
        persist()
        MuseHooks.emit(.arrived(muse))
        if muse.transcriptionState == .complete {
            MuseHooks.emit(.transcribed(muse))
        }
    }

    /// Changes one muse in place. Fires `transcribed` once per muse, when its words first
    /// land (it had none before). New words after "transcribe again" are an `updated`.
    @discardableResult
    func update(_ id: UUID, _ change: (inout Muse) -> Void) -> Muse? {
        guard let index = muses.firstIndex(where: { $0.id == id }) else { return nil }
        let before = muses[index]
        var after = before
        change(&after)
        after.id = before.id
        guard after != before else { return after }
        muses[index] = after
        if after.createdAt != before.createdAt {
            muses.sort { $0.createdAt > $1.createdAt }
        }
        persist()
        MuseHooks.emit(.updated(after))
        // First words only: a muse transcribed again (or a sample replaying) already had them.
        if before.transcriptionState != .complete, after.transcriptionState == .complete, before.transcript == nil {
            MuseHooks.emit(.transcribed(after))
        }
        return after
    }

    /// The person's own title for a muse (the muse page's edit). The model never replaces
    /// one of theirs. Names they write keep their capitals ("lunch with Priya"); the first
    /// word goes lowercase like every title. Empty clears it, and the muse shows the first
    /// line of its words until `MusePipeline.retitle` asks the model again.
    @discardableResult
    func setTitle(_ title: String, for id: UUID) -> Muse? {
        let line = title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = TheirNames(line).calm(line)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return update(id) { muse in
            muse.title = clean.isEmpty ? nil : clean
            muse.titleIsTheirs = !clean.isEmpty
        }
    }

    /// Deletes the muse, its audio, the ring's original file and any studio sound copy.
    /// Hooks clean up the rest (word timings). A file another muse still
    /// points at stays.
    func remove(_ id: UUID) {
        guard let index = muses.firstIndex(where: { $0.id == id }) else { return }
        let muse = muses.remove(at: index)
        persist()
        discardFiles(of: [muse])
        MuseHooks.emit(.removed(muse.id))
    }

    /// Deletes every muse and its files. Used by build › your muses › delete everything.
    /// One write and one pass over the files, however many muses there were.
    func removeAll() {
        let gone = muses
        guard !gone.isEmpty else { return }
        muses = []
        flush()
        discardFiles(of: gone)
        for muse in gone { MuseHooks.emit(.removed(muse.id)) }
    }

    // MARK: - Disk

    /// Writes muses.json now, after any write already on its way. True only when it's on
    /// disk (previews say true; a store that can't write says false). Call it before telling
    /// anyone a muse is safe, like the ring retiring its copy, and when the app goes to the
    /// background.
    @discardableResult
    func flush() -> Bool {
        guard canWrite else { return isPreview }
        writeQueued = false
        let snapshot = muses
        let url = fileURL
        return writer.sync { Self.write(snapshot, to: url) }
    }

    /// One write at the end of this main-actor turn, however many changes it holds.
    private func persist() {
        guard canWrite, !writeQueued else { return }
        writeQueued = true
        Task { @MainActor [weak self] in
            // A `flush()` in between already wrote these changes.
            guard let self, self.writeQueued else { return }
            self.writeQueued = false
            let snapshot = self.muses
            let url = self.fileURL
            self.writer.async { _ = Self.write(snapshot, to: url) }
        }
    }

    @discardableResult
    nonisolated private static func write(_ muses: [Muse], to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(muses)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            log.error("save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Deletes these muses' audio, the ring's originals and studio sound's clean copies,
    /// off the main thread. Samples have no files of their own; a file another muse
    /// still points at stays (a ring recording that came in twice shares one).
    private func discardFiles(of gone: [Muse]) {
        guard canWrite else { return }
        let owned = gone.filter { $0.origin != .sample }
        guard !owned.isEmpty else { return }
        let kept = Set(muses.flatMap { [$0.audioFileName, $0.sourceFileName].compactMap { $0 } })
        let folder = MuseFiles.audio
        var files: [URL] = []
        var audio: [URL] = []
        for muse in owned {
            for name in [muse.audioFileName, muse.sourceFileName].compactMap({ $0 }) where !kept.contains(name) {
                files.append(folder.appendingPathComponent(name))
            }
            if let name = muse.audioFileName, !kept.contains(name) {
                audio.append(folder.appendingPathComponent(name))
            }
        }
        guard !files.isEmpty else { return }
        writer.async {
            for url in audio { StudioSound.removeCopies(of: url) }
            for url in files { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// Tries muses.json again when it was there but couldn't be read at launch (the iphone
    /// was still locked after a restart). Muses that came in meanwhile are kept: they join
    /// what the file held, and the store writes again. `AppStart` calls it when the iphone
    /// unlocks and on every foreground.
    func reloadIfNeeded() {
        guard needsReload, !isPreview else { return }
        let waiting = muses
        needsReload = false
        canWrite = true
        load()
        // Muses made meanwhile (typed, say) join what the file held, whatever
        // the load decided; they're only written once the store can write.
        let known = Set(muses.map(\.id))
        let added = waiting.filter { !known.contains($0.id) }
        guard !added.isEmpty else { return }
        muses = (muses + added).sorted { $0.createdAt > $1.createdAt }
        if canWrite { persist() }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // There, but not readable right now. Never write over it: wait and try again.
            canWrite = false
            needsReload = true
            Self.log.error("couldn't read muses.json yet, saving waits: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !data.isEmpty else { return }
        let rows: [Lossy<Muse>]
        do {
            rows = try JSONDecoder().decode([Lossy<Muse>].self, from: data)
        } catch {
            // Never overwrite a file we couldn't read. Set it aside and start clean.
            let aside = fileURL.deletingPathExtension()
                .appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            Self.log.error("could not read muses.json, kept it at \(aside.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        let good = rows.compactMap(\.value)
        muses = good.sorted { $0.createdAt > $1.createdAt }
        let skipped = rows.count - good.count
        guard skipped > 0 else { return }
        // Some muses didn't decode (a new field read with `decode`, not `decodeIfPresent`?).
        // The next save would drop them, so keep a full copy first.
        let copy = fileURL.deletingPathExtension()
            .appendingPathExtension("partial-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try FileManager.default.copyItem(at: fileURL, to: copy)
            Self.log.error("skipped \(skipped) muses that could not be read, kept the original at \(copy.lastPathComponent, privacy: .public)")
        } catch where (try? FileManager.default.moveItem(at: fileURL, to: copy)) != nil {
            // No room for a copy (a full iphone): moving the original aside needs none.
            Self.log.error("skipped \(skipped) muses that could not be read, moved the original to \(copy.lastPathComponent, privacy: .public)")
        } catch {
            // Neither: never write over the only full one.
            canWrite = false
            Self.log.error("skipped \(skipped) muses that could not be read and couldn't copy muses.json, so nothing will be saved this launch: \(error.localizedDescription, privacy: .public)")
        }
    }
}
