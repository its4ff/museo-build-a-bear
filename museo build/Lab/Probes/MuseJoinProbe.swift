#if DEBUG
import AVFoundation
import Foundation

/// Proves the join of a long memory recording's parts without a ring. Launch with
/// `-museJoinProbe`: it writes short tone wavs, saves them as parts of ring recordings in
/// the live store (complete words and timings), lets `MusePipeline.joinParts` fold them,
/// checks every result, removes everything it made, prints `[muse][join probe]` lines and
/// exits (0 when every check passed).
///
/// ```
/// scripts/lab.sh build
/// xcrun simctl install "museo build lab" ".build/DerivedData/Build/Products/Debug-iphonesimulator/museo build.app"
/// xcrun simctl launch --console-pty "museo build lab" <bundle id> -museJoinProbe
/// ```
///
/// The pairs:
/// - record 42: parts 0 (29.5 min, a JUNK chunk before its samples) and 1, 30 minutes
///   apart. They join.
/// - record 44: parts 0, 1 and 2. They fold left into one muse.
/// - record 45: part 1 is blank. It joins and adds no words.
/// - record 46: part 0 is 5 minutes long (a double click ended it). They stay apart.
/// - record 47: part 1 starts 35 minutes after part 0. They stay apart.
/// - record 48: they named part 1, not part 0. The joined muse keeps their title.
/// - record 49: they named both. Part 0's title stays.
///
/// It also checks the stray sweep (only "muse-joining-" files, by the cutoff it was given),
/// sync keys from a ring whose clock reset, and that muses.json no longer lists a removed
/// part when the join first lets go of the main actor.
@MainActor
enum MuseJoinProbe {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-museJoinProbe")
    }

    /// Runs once, then ends the app.
    static func run(_ pipeline: MusePipeline) {
        Task {
            await probe(pipeline)
            say(failures == 0 ? "all \(passes) checks passed" : "\(failures) of \(passes + failures) checks failed")
            exit(failures == 0 ? 0 : 1)
        }
    }

    // MARK: - Private

    /// Every muse the probe makes carries it (as `textModel`), so a run cut short is cleaned
    /// up by the next one.
    private static let tag = "join-probe"
    private static let rate = 16_000
    private static let full: TimeInterval = 29.5 * 60
    private static var passes = 0
    private static var failures = 0
    private static var heard: [String] = []
    private static var names: [UUID: String] = [:]
    /// Whether muses.json on disk still listed B the first moment the main actor was free
    /// after B was removed. Nil until then.
    private static var diskListedB: Bool?

    private static func probe(_ pipeline: MusePipeline) async {
        let store = MuseStore.shared
        guard store.isWritable else {
            check(false, "muses.json can be written")
            return
        }
        removeLeftovers(store)
        checkSyncKeys()
        // Before any join, so no sweep of the app's own is running alongside.
        checkStrays()

        let t0 = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - 8 * 3_600).rounded(.down))
        do {
            // record 42: the pair from the brief.
            let a = try part("A", record: 42, part: 0, at: t0, duration: full, hz: 440, seconds: 3, junk: true,
                             words: [("hello", 0, 300), ("from", 300, 500), ("the", 500, 600), ("first", 600, 900), ("part.", 900, 1_300)],
                             confidence: 0.9, store: store)
            let b = try part("B", record: 42, part: 1, at: t0.addingTimeInterval(1_800), duration: 12 * 60, hz: 660, seconds: 2,
                             words: [("and", 120, 300), ("this", 300, 450), ("is", 450, 550), ("the", 550, 650), ("second", 650, 1_000), ("part.", 1_000, 1_400)],
                             confidence: 0.8, store: store)
            // record 44: three parts, folded left.
            let c0 = try part("C0", record: 44, part: 0, at: t0.addingTimeInterval(3_600), duration: full, hz: 300, seconds: 1,
                              words: [("one.", 100, 400)], store: store)
            let c1 = try part("C1", record: 44, part: 1, at: t0.addingTimeInterval(5_400 + 40), duration: full, hz: 350, seconds: 1,
                              words: [("two.", 50, 300)], store: store)
            let c2 = try part("C2", record: 44, part: 2, at: t0.addingTimeInterval(7_200 + 75), duration: 4 * 60, hz: 400, seconds: 1,
                              words: [("three.", 20, 500)], store: store)
            // record 45: the second part heard nothing.
            let d0 = try part("D0", record: 45, part: 0, at: t0.addingTimeInterval(9_000), duration: full, hz: 500, seconds: 1,
                              words: [("still", 0, 300), ("here.", 300, 700)], store: store)
            let d1 = try part("D1", record: 45, part: 1, at: t0.addingTimeInterval(10_800 - 30), duration: 60, hz: 550, seconds: 1,
                              words: [("you", 100, 300)], blank: true, store: store)
            // record 46: part 0 was a 5 minute recording, so part 1 isn't its neighbor.
            let e0 = try part("E0", record: 46, part: 0, at: t0.addingTimeInterval(12_600), duration: 5 * 60, hz: 600, seconds: 1,
                              words: [("short.", 0, 400)], store: store)
            let e1 = try part("E1", record: 46, part: 1, at: t0.addingTimeInterval(14_400), duration: full, hz: 650, seconds: 1,
                              words: [("stranger.", 0, 400)], store: store)
            // record 47: 35 minutes apart.
            let f0 = try part("F0", record: 47, part: 0, at: t0.addingTimeInterval(16_200), duration: full, hz: 700, seconds: 1,
                              words: [("early.", 0, 400)], store: store)
            let f1 = try part("F1", record: 47, part: 1, at: t0.addingTimeInterval(16_200 + 2_100), duration: full, hz: 750, seconds: 1,
                              words: [("late.", 0, 400)], store: store)
            // record 48: a model title on part 0, theirs on part 1.
            let g0 = try part("G0", record: 48, part: 0, at: t0.addingTimeInterval(19_800), duration: full, hz: 800, seconds: 1,
                              words: [("morning.", 0, 400)], title: "a model title", store: store)
            let g1 = try part("G1", record: 48, part: 1, at: t0.addingTimeInterval(21_600), duration: 60, hz: 850, seconds: 1,
                              words: [("afternoon.", 0, 400)], title: "afternoon walk", theirs: true, store: store)
            // record 49: theirs on both.
            let h0 = try part("H0", record: 49, part: 0, at: t0.addingTimeInterval(23_400), duration: full, hz: 900, seconds: 1,
                              words: [("first.", 0, 400)], title: "first half", theirs: true, store: store)
            let h1 = try part("H1", record: 49, part: 1, at: t0.addingTimeInterval(25_200), duration: 60, hz: 950, seconds: 1,
                              words: [("second.", 0, 400)], title: "second half", theirs: true, store: store)

            check(MuseJoiner.follows(b.muse, a.muse), "B follows A (record 42, parts 0 then 1, 30 min apart, A is full)")
            check(!MuseJoiner.follows(a.muse, b.muse), "A doesn't follow B")
            check(!MuseJoiner.follows(e1.muse, e0.muse), "E1 doesn't follow E0: E0 is 5 min, not a full part")
            check(!MuseJoiner.follows(f1.muse, f0.muse), "F1 doesn't follow F0: it starts 35 min on")

            let token = MuseHooks.on { event in
                switch event {
                case .updated(let muse): if let name = names[muse.id] { heard.append("updated(\(name))") }
                case .removed(let id):
                    guard let name = names[id] else { break }
                    heard.append("removed(\(name))")
                    // Runs the first moment the join lets go of the main actor after this.
                    if name == "B" { Task { diskListedB = onDisk(id) } }
                default: break
                }
            }
            let started = ContinuousClock.now
            await pipeline.joinParts()
            MuseHooks.cancel(token)
            say("joinParts took \(started.duration(to: .now).formatted(.units(allowed: [.milliseconds])))")

            let joining = ((try? FileManager.default.contentsOfDirectory(atPath: MuseFiles.audio.path)) ?? [])
                .filter { $0.hasPrefix("muse-joining-") }
            check(joining.isEmpty, "every join renamed its wav to its finished name (\(joining.count) muse-joining- left)")
            checkPair(a, b, store: store)
            checkChain([c0, c1, c2], store: store)
            checkBlank(d0, d1, store: store)
            checkTitles(theirsLater: (g0, g1), theirsBoth: (h0, h1), store: store)
            for (first, second, why) in [(e0, e1, "a 5 min part 0"), (f0, f1, "parts 35 min apart")] {
                let kept = [first, second].allSatisfy { made in
                    store.muse(id: made.muse.id).map { $0.ringParts == made.muse.ringParts && $0.audioFileName == made.muse.audioFileName } ?? false
                }
                check(kept, "\(why): both muses still there, unjoined, with their own audio")
            }
            let probeMuses = store.muses.filter { names[$0.id] != nil }
            check(MuseJoiner.nextPair(in: probeMuses, skipping: [], isFree: { _ in true }) == nil, "nothing left to join among the probe's muses")
        } catch {
            check(false, "made the probe's parts: \(error.localizedDescription)")
        }

        // Clean up: every muse the probe made, with its files and timings.
        let joinedFiles = store.muses.filter { $0.textModel == tag }.compactMap(\.audioURL)
        removeLeftovers(store)
        check(store.muses.allSatisfy { $0.textModel != tag }, "cleaned up: no probe muse left")
        check(joinedFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "cleaned up: the joined wavs are gone")
    }

    // MARK: - Checks

    private static func checkSyncKeys() {
        let start = Date(timeIntervalSince1970: 1_791_000_000)
        let epoch = Int(start.timeIntervalSince1970)
        check(
            RingParts(syncKey: "07-0200.ops|57600|\(epoch)", startedAt: start, duration: 1_767)
                == RingParts(record: 7, first: 2, last: 2, lastStartedAt: start, lastDuration: 1_767),
            "sync key 07-0200.ops reads as record 7, part 2"
        )
        let refused = [
            "07-0200.ops|57600|no-date",
            "07-0201.ops|57600|\(epoch)",
            "7A-0200.ops|57600|\(epoch)",
            "07-0200.ogg|57600|\(epoch)",
            "07-0200.ops|57600|\(epoch + 60)",
            "07-0200.ops|\(epoch)",
            "107-0200.ops|57600|\(epoch)",
        ]
        let read = refused.filter { RingParts(syncKey: $0, startedAt: start, duration: 1_767) != nil }
        check(read.isEmpty, "odd sync keys give no parts (undated, reserved byte, not digits, not .ops, wrong date, short, long)\(read.isEmpty ? "" : ": \(read)")")
        // A ring reset starts its clock again at 2024-01-01: 00:03 and 00:33 that day.
        let reset = [1_704_067_380, 1_704_069_180].map { Date(timeIntervalSince1970: $0) }
        check(
            reset.enumerated().allSatisfy { part, start in
                RingParts(syncKey: "07-0\(part)00.ops|57600|\(Int(start.timeIntervalSince1970))", startedAt: start, duration: 1_767) == nil
            },
            "parts stamped by a reset clock (2024-01-01) give no parts, so they never join"
        )
    }

    private static func checkPair(_ a: Made, _ b: Made, store: MuseStore) {
        say("── record 42: A (3 s at 440 hz, JUNK chunk first) + B (2 s at 660 hz)")
        guard let joined = store.muse(id: a.muse.id) else {
            check(false, "A is still in the store")
            return
        }
        say("duration \(joined.duration) s · \(joined.duration.museDuration)")
        say("transcript \(String(reflecting: joined.transcript ?? ""))")
        if let parts = joined.ringParts {
            say("ringParts record \(parts.record) · parts \(parts.first)…\(parts.last) · last started \(parts.lastStartedAt.timeIntervalSince(a.muse.createdAt)) s after A · last \(parts.lastDuration) s")
        }
        say("title \(joined.title ?? "(none)") · confidence \(joined.wordConfidence.map { String(format: "%.4f", $0) } ?? "(none)")")
        check(joined.duration == a.muse.duration + b.muse.duration, "duration is A's plus B's (\(a.muse.duration) + \(b.muse.duration))")
        check(joined.transcript == "hello from the first part.\n\nand this is the second part.", "transcript is A's words, a blank line, B's words")
        check(joined.ringParts == RingParts(record: 42, first: 0, last: 1, lastStartedAt: b.muse.createdAt, lastDuration: b.muse.duration),
              "ringParts cover parts 0…1, the last one B's")
        check(joined.createdAt == a.muse.createdAt && joined.endedAt == b.muse.endedAt, "starts when A did, ends when B did")
        check(joined.sourceFileName == a.muse.sourceFileName && joined.origin == .offline, "keeps A's original and origin")
        let expected = (0.9 * a.muse.duration + 0.8 * b.muse.duration) / (a.muse.duration + b.muse.duration)
        check(abs((joined.wordConfidence ?? 0) - expected) < 0.000_1, "word confidence weighted by duration (\(String(format: "%.4f", expected)))")
        check(store.muse(id: b.muse.id) == nil, "B is gone from the store")

        // The joined wav.
        let name = joined.audioFileName ?? ""
        check(name.hasPrefix("muse-joined-"), "audio is a new joined wav (\(name))")
        let out = joined.audioURL.map { frames($0) } ?? -1
        say("samples: A \(a.frames) + B \(b.frames) = \(a.frames + b.frames) · joined \(out)")
        check(a.frames == 48_000 && b.frames == 32_000, "AVAudioFile reads both parts (A past its JUNK chunk)")
        check(out == a.frames + b.frames, "joined sample count is the sum of both parts")
        if let url = joined.audioURL, let data = try? Data(contentsOf: url) {
            check(data.count == 44 + a.samples.count + b.samples.count && data.dropFirst(44) == a.samples + b.samples,
                  "joined samples are A's bytes then B's, under a 44-byte header")
            let found = try? WavSamples.find(in: url)
            check(found?.offset == 44 && found?.bytes == UInt64(a.samples.count + b.samples.count), "joined header holds the right data size")
        } else {
            check(false, "joined wav can be read")
        }

        // Word timings.
        let timed = TimedTranscriptStore.load(joined.id)
        let aMs = 48_000 * 1_000 / rate
        let firstB = timed.flatMap { $0.words.count > 5 ? $0.words[5] : nil }
        say("timings: \(timed?.words.count ?? 0) words · B's first word \(String(reflecting: firstB?.text ?? "")) at \(firstB?.startMs ?? -1) ms (A is \(aMs) ms, it was at 120)")
        check(firstB?.startMs == aMs + 120 && firstB?.text == "and", "B's first word moved on by A's length: \(aMs) + 120 ms")
        check(timed?.words.prefix(5).map(\.startMs) == [0, 300, 500, 600, 900], "A's words keep their times")
        check(timed?.segments.map(\.startMs) == [0, aMs + 120], "segments moved too")
        check(timed?.tokens(for: joined.transcript) != nil, "timings line up with the joined words, so the page lights them")
        check(TimedTranscriptStore.load(b.muse.id) == nil, "B's timings are gone")

        // Files.
        check(!exists(b.url) && !exists(b.muse.sourceURL), "B's wav and original are gone")
        check(!exists(a.url), "A's old part wav is gone")
        check(exists(a.muse.sourceURL), "A's original (part 00) stays")

        // Hooks.
        let order = heard.filter { $0.hasSuffix("(A)") || $0.hasSuffix("(B)") }
        say("hooks: \(order.joined(separator: ", "))")
        check(order.prefix(2) == ["updated(A)", "removed(B)"], "hooks: .updated(A) with all the words, then .removed(B)")
        say("muses.json listed B when the main actor was next free: \(diskListedB.map { "\($0)" } ?? "never checked")")
        check(diskListedB == false, "B's removal was on disk before the join let go of the main actor")
    }

    private static func checkTitles(theirsLater: (Made, Made), theirsBoth: (Made, Made), store: MuseStore) {
        say("── records 48 and 49: titles they wrote")
        let joined = store.muse(id: theirsLater.0.muse.id)
        say("record 48 title \(String(reflecting: joined?.title ?? "")) · theirs \(joined?.titleIsTheirs ?? false)")
        check(store.muse(id: theirsLater.1.muse.id) == nil, "record 48 joined")
        check(joined?.title == "afternoon walk" && joined?.titleIsTheirs == true,
              "the title they gave the later part goes with it into the joined muse")
        let both = store.muse(id: theirsBoth.0.muse.id)
        say("record 49 title \(String(reflecting: both?.title ?? "")) · theirs \(both?.titleIsTheirs ?? false)")
        check(store.muse(id: theirsBoth.1.muse.id) == nil, "record 49 joined")
        check(both?.title == "first half" && both?.titleIsTheirs == true, "when both titles are theirs, part 0's stays")
    }

    /// The stray sweep takes only "muse-joining-" wavs (a join cut short), and only those
    /// last written before the cutoff it was handed, not one taken when it finally runs.
    private static func checkStrays() {
        say("── stray sweep")
        let folder = MuseFiles.audio
        let stem = "\(tag)-\(UUID().uuidString.prefix(8).lowercased())"
        // As if asked two hours ago, and only running now (the app was suspended between).
        let settled = Date.now.addingTimeInterval(-7_200 - 120)
        let stale = folder.appendingPathComponent("muse-joining-\(stem)-stale.wav")
        let late = folder.appendingPathComponent("muse-joining-\(stem)-late.wav")
        let finished = folder.appendingPathComponent("muse-joined-\(stem).wav")
        let ages: [(URL, TimeInterval)] = [(stale, 3 * 3_600), (late, 30 * 60), (finished, 3 * 3_600)]
        for (url, age) in ages {
            try? Data("stray".utf8).write(to: url)
            try? FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        }
        MuseJoiner.removeStrays(settled: settled)
        check(!exists(stale), "the sweep takes a muse-joining- wav older than its cutoff")
        check(exists(late), "the sweep keeps a muse-joining- wav written after its cutoff, though minutes old now")
        check(exists(finished), "the sweep never takes a muse-joined- wav, even one no muse in the store points at")
        for (url, _) in ages { try? FileManager.default.removeItem(at: url) }
    }

    private static func checkChain(_ parts: [Made], store: MuseStore) {
        say("── record 44: three parts")
        let left = parts.filter { store.muse(id: $0.muse.id) != nil }.map(\.name)
        check(left == ["C0"], "one muse left, part 0's (\(left))")
        guard let joined = store.muse(id: parts[0].muse.id) else { return }
        say("transcript \(String(reflecting: joined.transcript ?? "")) · parts \(joined.ringParts.map { "\($0.first)…\($0.last)" } ?? "none")")
        check(joined.transcript == "one.\n\ntwo.\n\nthree.", "words of all three, in order")
        check(joined.ringParts?.first == 0 && joined.ringParts?.last == 2 && joined.ringParts?.lastStartedAt == parts[2].muse.createdAt,
              "ringParts cover 0…2")
        check(joined.audioURL.map { frames($0) } == 3 * rate, "audio holds all three seconds")
        let starts = TimedTranscriptStore.load(joined.id)?.words.map(\.startMs)
        check(starts == [100, 1_050, 2_020], "each part's words start a part later (\(starts ?? []))")
        check(parts.allSatisfy { !exists($0.url) }, "every part's own wav is gone")
    }

    private static func checkBlank(_ spoken: Made, _ blank: Made, store: MuseStore) {
        say("── record 45: part 1 is blank")
        guard let joined = store.muse(id: spoken.muse.id) else {
            check(false, "D0 is still in the store")
            return
        }
        check(store.muse(id: blank.muse.id) == nil, "the blank part joined")
        check(joined.transcript == "still here." && !joined.isBlank, "a blank part adds no words, and the whole isn't blank")
        check(joined.audioURL.map { frames($0) } == 2 * rate, "its audio is still in")
        check(TimedTranscriptStore.load(joined.id)?.tokens(for: joined.transcript) != nil, "timings still line up")
    }

    // MARK: - Parts

    private struct Made {
        let name: String
        let muse: Muse
        let url: URL
        let samples: Data
        /// Its length by AVAudioFile, read before any join.
        let frames: Int
    }

    /// One ring part: a tone wav, a stand-in original, a complete muse and its timings.
    private static func part(
        _ name: String,
        record: Int,
        part: Int,
        at start: Date,
        duration: TimeInterval,
        hz: Double,
        seconds: Double,
        junk: Bool = false,
        words: [(String, Int, Int)],
        confidence: Double? = nil,
        blank: Bool = false,
        title: String? = nil,
        theirs: Bool = false,
        store: MuseStore
    ) throws -> Made {
        let stem = "\(tag)-\(name.lowercased())-\(UUID().uuidString.prefix(8).lowercased())"
        let samples = tone(hz, seconds: seconds)
        let url = MuseFiles.audio.appendingPathComponent("\(stem).wav")
        try wav(samples, junk: junk).write(to: url)
        try Data("not opus".utf8).write(to: MuseFiles.audio.appendingPathComponent("\(stem).ops"))
        let text = words.map(\.0).joined(separator: " ")
        let muse = Muse(
            createdAt: start,
            duration: duration,
            origin: .offline,
            transcript: text,
            transcriptionState: .complete,
            title: title,
            titleIsTheirs: theirs,
            language: "en",
            wordConfidence: confidence,
            textModel: tag,
            isBlank: blank,
            audioFileName: "\(stem).wav",
            sourceFileName: "\(stem).ops",
            arrivedAt: .now,
            ringParts: RingParts(record: record, first: part, last: part, lastStartedAt: start, lastDuration: duration)
        )
        names[muse.id] = name
        store.insert(muse)
        let timed = words.map { TimedWord(text: $0.0, startMs: $0.1, endMs: $0.2) }
        TimedTranscriptStore.save(TimedTranscript(
            version: TimedTranscript.currentVersion,
            transcript: text,
            words: timed,
            segments: [TimedSegment(text: text, startMs: timed.first?.startMs ?? 0, endMs: timed.last?.endMs ?? 0)],
            language: "en",
            textModel: tag,
            timingModel: tag,
            updatedAt: .now
        ), for: muse.id)
        return Made(name: name, muse: muse, url: url, samples: samples, frames: frames(url))
    }

    /// `seconds` of a sine at `hz`, as 16-bit little-endian samples at 16 kHz.
    private static func tone(_ hz: Double, seconds: Double) -> Data {
        let count = Int(seconds * Double(rate))
        var data = Data(capacity: count * 2)
        for index in 0..<count {
            data.appendLE(Int16(sin(2 * .pi * hz * Double(index) / Double(rate)) * 12_000))
        }
        return data
    }

    /// A 16 kHz mono 16-bit wav. `junk` puts an odd-length JUNK chunk (and its pad byte)
    /// before the samples, so "data" isn't at byte 44.
    private static func wav(_ samples: Data, junk: Bool) -> Data {
        let extra = junk ? Data("JUNK".utf8) + le32(7) + Data("museo\u{0}\u{0}".utf8) + Data([0]) : Data()
        var file = Data("RIFF".utf8)
        file.appendLE(UInt32(4 + 24 + extra.count + 8 + samples.count))
        file.append(Data("WAVEfmt ".utf8))
        file.appendLE(UInt32(16))
        file.appendLE(UInt16(1))
        file.appendLE(UInt16(1))
        file.appendLE(UInt32(rate))
        file.appendLE(UInt32(rate * 2))
        file.appendLE(UInt16(2))
        file.appendLE(UInt16(16))
        file.append(extra)
        file.append(Data("data".utf8))
        file.appendLE(UInt32(samples.count))
        file.append(samples)
        return file
    }

    private static func le32(_ value: UInt32) -> Data {
        var data = Data()
        data.appendLE(value)
        return data
    }

    // MARK: - Helpers

    /// Frames by AVAudioFile, the reader the app plays and transcribes with. -1 when it
    /// can't be opened.
    private static func frames(_ url: URL) -> Int {
        guard let file = try? AVAudioFile(forReading: url) else { return -1 }
        return Int(file.length)
    }

    /// Whether muses.json on disk holds this id. True when it can't be read: the check
    /// fails rather than passes on a file it never saw.
    private static func onDisk(_ id: UUID) -> Bool {
        let url = MuseFiles.library.appendingPathComponent("muses.json")
        guard let data = try? Data(contentsOf: url) else { return true }
        return String(decoding: data, as: UTF8.self).contains(id.uuidString)
    }

    private static func exists(_ url: URL?) -> Bool {
        url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    /// Muses (and stray files) an earlier run left behind.
    private static func removeLeftovers(_ store: MuseStore) {
        for muse in store.muses where muse.textModel == tag {
            store.remove(muse.id)
        }
        store.flush()
        let folder = MuseFiles.audio
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasPrefix("\(tag)-") {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    private static func check(_ ok: Bool, _ line: String) {
        if ok { passes += 1 } else { failures += 1 }
        say("\(ok ? "pass" : "FAIL") · \(line)")
    }

    private static func say(_ line: String) {
        print("[muse][join probe] \(line)")
    }
}
#endif
