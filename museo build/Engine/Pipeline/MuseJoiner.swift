import Foundation

/// Folds the parts of one long memory recording back into one muse.
///
/// The ring cuts a memory recording into 30-minute files (`RingParts`). Each part still
/// lands, is saved, lets the ring retire its copy and gets its words like any recording.
/// Afterwards, once two neighbors both have their words, the earlier one takes in the later:
///
/// ```
/// part 00 ─▶ muse A ─┐
///                    ├─▶ A holds parts 0…1: one wav, A's words then B's, timings shifted
/// part 01 ─▶ muse B ─┘   then B is removed (hooks: .updated(A), then .removed(B))
/// ```
///
/// Chains fold left: parts 0…1 then take part 2. `MusePipeline` decides when (both
/// transcribed, neither busy) and asks for the new title and notes; this file does the join.
@MainActor
enum MuseJoiner {
    /// The ring starts a new file every 30 minutes of its own clock.
    nonisolated static let partSpacing: TimeInterval = 1_800
    /// How far from 30 minutes on the next part may start.
    nonisolated static let spacingSlack: TimeInterval = 120
    /// A last part at least this long was cut by the ring, not ended with a double click.
    nonisolated static let fullPart: TimeInterval = 25 * 60
    /// Every ring wav is 16 kHz mono 16-bit.
    nonisolated static let sampleRate = 16_000

    /// A joined wav is written under `joiningPrefix` and renamed to `joinedPrefix` just
    /// before a muse points at it, so only a join cut short leaves a "muse-joining-" file.
    nonisolated private static let joiningPrefix = "muse-joining-"
    nonisolated private static let joinedPrefix = "muse-joined-"
    private static var sweptStrays = false

    // MARK: - Which muses

    /// True when `later` is the next part of the recording `earlier` holds: both memory
    /// muses from the ring, one record number, the next part, starting about 30 minutes after
    /// `earlier`'s last part began, and that last part was a full one. The ring reuses record
    /// numbers after a delete, so the clock and the length keep strangers apart.
    nonisolated static func follows(_ later: Muse, _ earlier: Muse) -> Bool {
        guard later.id != earlier.id, later.origin == .offline, earlier.origin == .offline,
              let next = later.ringParts, let held = earlier.ringParts,
              next.record == held.record, next.first == held.last + 1,
              held.lastDuration >= fullPart
        else { return false }
        let gap = later.createdAt.timeIntervalSince(held.lastStartedAt)
        return abs(gap - partSpacing) <= spacingSlack
    }

    /// The muses next to `muse` in one recording: the part before, then the part after.
    static func neighbors(of muse: Muse, in muses: [Muse]) -> [(earlier: Muse, later: Muse)] {
        guard muse.ringParts != nil else { return [] }
        let parts = muses.filter { $0.ringParts != nil }
        let before = parts.filter { follows(muse, $0) }.map { (earlier: $0, later: muse) }
        let after = parts.filter { follows($0, muse) }.map { (earlier: muse, later: $0) }
        return before + after
    }

    /// The earliest pair ready to fold: both transcribed (a blank part counts, with no
    /// words), both `isFree`, and not a pair that already failed (`failed` holds the later
    /// part's id).
    static func nextPair(
        in muses: [Muse],
        skipping failed: Set<UUID>,
        isFree: (UUID) -> Bool
    ) -> (earlier: Muse, later: Muse)? {
        let parts = muses
            .filter { $0.ringParts != nil && $0.origin == .offline && $0.isTranscribed && isFree($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        for earlier in parts {
            if let later = parts.first(where: { !failed.contains($0.id) && follows($0, earlier) }) {
                return (earlier, later)
            }
        }
        return nil
    }

    // MARK: - Join

    /// Folds `later` into `earlier` and returns the joined muse, or nil when nothing changed:
    /// a wav couldn't be read or written, either muse changed or went meanwhile, or
    /// muses.json couldn't be saved. Nothing is deleted before the joined muse is on disk.
    static func join(_ earlier: Muse, _ later: Muse, in store: MuseStore) async -> Muse? {
        guard let firstURL = earlier.audioURL, let secondURL = later.audioURL else {
            say("skipped \(earlier.shortID) + \(later.shortID): a part has no audio")
            return nil
        }
        let stem = "\(UUID().uuidString.lowercased()).wav"
        let name = joinedPrefix + stem
        let joiningURL = MuseFiles.audio.appendingPathComponent(joiningPrefix + stem)
        let joinedURL = MuseFiles.audio.appendingPathComponent(name)

        // a. One wav, streamed off the main actor, under its in-progress name.
        let audio: JoinedAudio
        do {
            audio = try await writeJoined(firstURL, secondURL, to: joiningURL)
        } catch {
            say("couldn't write the joined audio for \(earlier.shortID) + \(later.shortID): \(error.localizedDescription)")
            return nil
        }

        // b. Word timings: the earlier's, then the later's moved on by the earlier's length.
        let words = joinedWords(earlier, later)
        let oldTimings = await loadTimings(earlier.id)
        let timings = await joinedTimings(earlier, later, text: words.text, shiftMs: audio.firstMs)
        // Saved before the muse changes, so a page showing it reads the new ones with the new words.
        if let timings { await saveTimings(timings, for: earlier.id) }
        let wroteTimings = timings != nil

        // Nothing may have changed under the join while it was off the main actor.
        guard let current = store.muse(id: earlier.id), let next = store.muse(id: later.id),
              current.isTranscribed, next.isTranscribed,
              current.audioFileName == earlier.audioFileName, next.audioFileName == later.audioFileName,
              current.transcript == earlier.transcript, next.transcript == later.transcript,
              current.ringParts == earlier.ringParts, next.ringParts == later.ringParts,
              let held = current.ringParts, let added = next.ringParts
        else {
            say("left \(earlier.shortID) + \(later.shortID) alone: one changed while joining")
            undo(joiningURL, timings: oldTimings, for: earlier.id, wrote: wroteTimings, in: store)
            return nil
        }
        // Its finished name, in the same folder (an atomic rename), before a muse points at
        // it: the stray sweep only ever takes "muse-joining-" files.
        do {
            try FileManager.default.moveItem(at: joiningURL, to: joinedURL)
        } catch {
            say("couldn't name the joined audio for \(earlier.shortID) + \(later.shortID): \(error.localizedDescription)")
            undo(joiningURL, timings: oldTimings, for: earlier.id, wrote: wroteTimings, in: store)
            return nil
        }

        // c. The earlier muse becomes the whole recording.
        let before = current
        store.update(current.id) { muse in
            muse.audioFileName = name
            muse.transcript = words.text
            muse.duration = current.duration + next.duration
            muse.endedAt = next.endedAt
            muse.isBlank = current.isBlank && next.isBlank
            muse.wordConfidence = joinedConfidence(current, next)
            muse.language = current.language ?? next.language
            muse.textModel = current.textModel ?? next.textModel
            muse.ringParts = RingParts(
                record: held.record,
                first: held.first,
                last: added.last,
                lastStartedAt: added.lastStartedAt,
                lastDuration: added.lastDuration
            )
            // The whole gets its own notes, and a new title unless a title is theirs: A's
            // first, else the one they gave the later part, which goes with it.
            muse.notes = nil
            if !muse.titleIsTheirs {
                muse.title = next.titleIsTheirs ? next.title : nil
                muse.titleIsTheirs = next.titleIsTheirs
            }
            // It landed in full when its last part did (the home's "new" mark).
            muse.arrivedAt = max(current.arrivedAt, next.arrivedAt)
        }

        // d. On disk before anything goes.
        guard store.flush() else {
            store.update(current.id) { $0 = before }
            undo(joinedURL, timings: oldTimings, for: earlier.id, wrote: wroteTimings, in: store)
            say("muses.json not saved; put \(earlier.shortID) back and left \(later.shortID) alone")
            return nil
        }

        // e. The later part goes (its audio, its original, its timings through the hook), on
        // disk before the join lets go of the main actor: its files are already on their way
        // out, so muses.json must never list it after a suspension. Then the earlier part's
        // own wav, once no muse points at it.
        store.remove(next.id)
        store.flush()
        if let old = current.audioFileName, !store.muses.contains(where: { $0.audioFileName == old || $0.sourceFileName == old }) {
            await removeAudio(MuseFiles.audio.appendingPathComponent(old))
        }
        store.flush()
        // Deleted while the old wav went (its hook took its timings).
        guard let joined = store.muse(id: current.id) else { return nil }

        // g.
        let seconds = Int(joined.duration.rounded())
        say("""
            record \(String(format: "%02d", held.record)) · parts \(held.first)…\(added.last) · \
            \(seconds / 60)m \(seconds % 60)s · \(next.shortID) into \(joined.shortID)\(timings == nil ? " · no word timings" : "")
            """)
        return joined
    }

    /// Wavs a join cut short left behind (the app ended mid-copy): only "muse-joining-"
    /// files, which no muse ever points at, so what the store holds doesn't matter. Once a
    /// launch, before the first join. The cutoff is taken now, on the main actor: a file a
    /// join writes after this call can never qualify, however late the sweep runs.
    static func sweepStrays() {
        guard !sweptStrays else { return }
        sweptStrays = true
        let settled = Date.now.addingTimeInterval(-120)
        Task.detached(priority: .utility) {
            MuseJoiner.removeStrays(settled: settled)
        }
    }

    // MARK: - Words

    /// The joined words: A's, a blank line, then B's. A blank part adds none; two blank parts
    /// keep A's. `usesFirst` and `usesSecond` say whose words are in, for the timings.
    nonisolated static func joinedWords(_ a: Muse, _ b: Muse) -> (text: String?, usesFirst: Bool, usesSecond: Bool) {
        if a.isBlank, b.isBlank { return (a.transcript, false, false) }
        let usesFirst = !a.isBlank && !a.words.isEmpty
        let usesSecond = !b.isBlank && !b.words.isEmpty
        let text = [usesFirst ? a.words : nil, usesSecond ? b.words : nil]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        return (text, usesFirst, usesSecond)
    }

    /// Mean word confidence by duration, over the parts whose words are in. Nil when one of
    /// them has none (a mix of known and unknown isn't worth a number).
    nonisolated private static func joinedConfidence(_ a: Muse, _ b: Muse) -> Double? {
        let words = joinedWords(a, b)
        let sides = [words.usesFirst ? a : nil, words.usesSecond ? b : nil].compactMap { $0 }
        guard !sides.isEmpty else { return a.wordConfidence }
        let rated = sides.compactMap { side in side.wordConfidence.map { ($0, max(side.duration, 1)) } }
        guard rated.count == sides.count else { return nil }
        let total = rated.reduce(0) { $0 + $1.1 }
        return rated.reduce(0) { $0 + $1.0 * $1.1 } / total
    }

    /// A's timings, then B's moved on by `shiftMs`. Nil when a part whose words are in has no
    /// timings that match them: A keeps its own, and the page shows plain words rather than
    /// lighting words at the wrong time.
    @concurrent
    nonisolated private static func joinedTimings(_ a: Muse, _ b: Muse, text: String?, shiftMs: Int) async -> TimedTranscript? {
        let uses = joinedWords(a, b)
        guard let text, uses.usesFirst || uses.usesSecond else { return nil }
        var parts: [(timed: TimedTranscript, shift: Int)] = []
        for (muse, used, shift) in [(a, uses.usesFirst, 0), (b, uses.usesSecond, shiftMs)] where used {
            guard let timed = TimedTranscriptStore.load(muse.id), timed.tokens(for: muse.transcript) != nil else { return nil }
            parts.append((timed, shift))
        }
        guard let lead = parts.first?.timed else { return nil }
        let words = parts.flatMap { part in
            part.timed.words.map { TimedWord(text: $0.text, startMs: $0.startMs + part.shift, endMs: $0.endMs + part.shift) }
        }
        let segments = parts.flatMap { part in
            part.timed.segments.map { TimedSegment(text: $0.text, startMs: $0.startMs + part.shift, endMs: $0.endMs + part.shift) }
        }
        return TimedTranscript(
            version: TimedTranscript.currentVersion,
            transcript: text,
            words: words,
            segments: segments,
            language: a.language ?? lead.language,
            textModel: lead.textModel,
            timingModel: lead.timingModel,
            updatedAt: .now
        )
    }

    @concurrent
    nonisolated private static func loadTimings(_ id: UUID) async -> TimedTranscript? {
        TimedTranscriptStore.load(id)
    }

    @concurrent
    nonisolated private static func saveTimings(_ timings: TimedTranscript, for id: UUID) async {
        TimedTranscriptStore.save(timings, for: id)
    }

    /// A join that won't land: the joined wav goes, and A's own timings come back.
    private static func undo(_ joined: URL, timings old: TimedTranscript?, for id: UUID, wrote: Bool, in store: MuseStore) {
        try? FileManager.default.removeItem(at: joined)
        guard wrote else { return }
        if let old, store.muse(id: id) != nil {
            TimedTranscriptStore.save(old, for: id)
        } else {
            TimedTranscriptStore.delete(id)
        }
    }

    // MARK: - Audio

    /// How much of the joined wav each part filled, in bytes of samples.
    nonisolated struct JoinedAudio: Sendable {
        let firstBytes: UInt64
        let secondBytes: UInt64

        var firstSamples: Int { Int(firstBytes / 2) }
        var secondSamples: Int { Int(secondBytes / 2) }
        /// The first part's length in milliseconds: where the second part's words start.
        var firstMs: Int { firstSamples * 1_000 / MuseJoiner.sampleRate }
    }

    nonisolated enum JoinError: LocalizedError {
        case notRingAudio(String)
        case tooLong
        case shortFile(String)

        var errorDescription: String? {
            switch self {
            case .notRingAudio(let name): "\(name) isn't 16 khz mono 16-bit pcm."
            case .tooLong: "the joined audio would pass the 4 gb a wav can hold."
            case .shortFile(let name): "\(name) ended before its samples did."
            }
        }
    }

    /// A's samples, then B's, into one 16 kHz mono 16-bit wav at `target`. Streams a
    /// megabyte at a time (a part is about 58 MB), with a placeholder header patched at the
    /// end. A file cut short is removed.
    @concurrent
    nonisolated static func writeJoined(_ first: URL, _ second: URL, to target: URL) async throws -> JoinedAudio {
        guard let a = try WavSamples.find(in: first) else { throw JoinError.notRingAudio(first.lastPathComponent) }
        guard let b = try WavSamples.find(in: second) else { throw JoinError.notRingAudio(second.lastPathComponent) }
        let total = a.bytes + b.bytes
        guard total <= UInt64(UInt32.max) - 36 else { throw JoinError.tooLong }
        guard FileManager.default.createFile(atPath: target.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let out = try FileHandle(forWritingTo: target)
            defer { try? out.close() }
            try out.write(contentsOf: WavSamples.header(dataBytes: 0))
            try a.copy(from: first, into: out)
            try b.copy(from: second, into: out)
            try out.seek(toOffset: 0)
            try out.write(contentsOf: WavSamples.header(dataBytes: UInt32(total)))
            try out.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
        return JoinedAudio(firstBytes: a.bytes, secondBytes: b.bytes)
    }

    /// The earlier part's own wav and its studio sound copies, off the main actor.
    @concurrent
    nonisolated private static func removeAudio(_ url: URL) async {
        StudioSound.removeCopies(of: url)
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes "muse-joining-" wavs last written before `settled`.
    nonisolated static func removeStrays(settled: Date) {
        let files = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let urls = try? files.contentsOfDirectory(at: MuseFiles.audio, includingPropertiesForKeys: keys) else { return }
        for url in urls where url.lastPathComponent.hasPrefix(joiningPrefix) {
            guard let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate,
                  modified < settled else { continue }
            try? files.removeItem(at: url)
            say("removed \(url.lastPathComponent), left by a join cut short")
        }
    }

    nonisolated private static func say(_ line: String) {
        print("[muse][join] \(line)")
    }
}

// MARK: - Wav samples

/// Where a 16 kHz mono 16-bit wav keeps its samples, found by walking its RIFF chunks (the
/// "data" chunk isn't always at byte 44).
nonisolated struct WavSamples: Sendable {
    /// Where the samples start, and how many bytes of them there are (whole samples only).
    let offset: UInt64
    let bytes: UInt64

    private static let chunkSize: UInt64 = 1 << 20

    /// Nil unless the file is 16 kHz mono 16-bit PCM with a "data" chunk.
    static func find(in url: URL) throws -> WavSamples? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        guard let head = try handle.read(upToCount: 12), head.count == 12,
              head.prefix(4) == Data("RIFF".utf8), head.suffix(4) == Data("WAVE".utf8)
        else { return nil }
        var offset: UInt64 = 12
        var isRingFormat = false
        // A wav has a handful of chunks; a damaged one must not walk forever.
        for _ in 0..<64 {
            guard offset + 8 <= size else { return nil }
            try handle.seek(toOffset: offset)
            guard let header = try handle.read(upToCount: 8), header.count == 8 else { return nil }
            let id = String(decoding: header.prefix(4), as: UTF8.self)
            let length = UInt64(header.le32(at: 4))
            let body = offset + 8
            switch id {
            case "fmt ":
                guard length >= 16, let format = try handle.read(upToCount: 16), format.count == 16 else { return nil }
                let tag = format.le16(at: 0)
                isRingFormat = (tag == 1 || tag == 0xFFFE)
                    && format.le16(at: 2) == 1
                    && format.le32(at: 4) == UInt32(MuseJoiner.sampleRate)
                    && format.le16(at: 14) == 16
            case "data":
                guard isRingFormat else { return nil }
                // A header never patched (0, or 0xFFFFFFFF) or one promising more than the
                // file holds: take what's there.
                let there = size - body
                var bytes = (length == 0 || length > there) ? there : length
                bytes -= bytes % 2
                return WavSamples(offset: body, bytes: bytes)
            default:
                break
            }
            // Chunks are padded to an even length.
            offset = body + length + (length & 1)
        }
        return nil
    }

    /// Copies these samples from `url` into `out`, a megabyte at a time.
    func copy(from url: URL, into out: FileHandle) throws {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        try input.seek(toOffset: offset)
        var left = bytes
        while left > 0 {
            try autoreleasepool {
                let chunk = try input.read(upToCount: Int(min(left, Self.chunkSize))) ?? Data()
                guard !chunk.isEmpty else { throw MuseJoiner.JoinError.shortFile(url.lastPathComponent) }
                try out.write(contentsOf: chunk)
                left -= UInt64(chunk.count)
            }
        }
    }

    /// A canonical 44-byte header for `dataBytes` of 16 kHz mono 16-bit samples.
    static func header(dataBytes: UInt32) -> Data {
        let rate = UInt32(MuseJoiner.sampleRate)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLE(UInt32(36) &+ dataBytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(rate)
        data.appendLE(rate * 2)
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.appendLE(dataBytes)
        return data
    }
}

nonisolated extension Data {
    fileprivate func le16(at offset: Int) -> UInt16 {
        let start = startIndex + offset
        return UInt16(self[start]) | UInt16(self[start + 1]) << 8
    }

    fileprivate func le32(at offset: Int) -> UInt32 {
        let start = startIndex + offset
        return UInt32(self[start]) | UInt32(self[start + 1]) << 8 | UInt32(self[start + 2]) << 16 | UInt32(self[start + 3]) << 24
    }

    /// Appends `value` little-endian, as wav headers hold numbers.
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

nonisolated private extension Muse {
    /// The start of its id, for logs. Never its words.
    var shortID: String { String(id.uuidString.prefix(8)).lowercased() }
}
