#if DEBUG
import Foundation

/// Checks the reading of commands at a hold's edge against made-up holds:
/// `MuseoMac -edgeCheck YES`. Prints each case and whether it read as expected.
enum EdgeCheck {
    static func run() {
        let commands = VoiceCommands.shared
        var failed = 0
        func check(_ name: String, _ words: String, _ audio: [Int16], expect: String) {
            let pauses = HoldPauses(samples: audio)
            let got: String
            switch commands.read(apple: words, local: words, pauses: pauses) {
            case .wordsThenCommand(let kept, _, let said): got = "words[\(kept)] then \(said)"
            case .commandThenWords(_, let said, let rest): got = "\(said) then words[\(rest)]"
            case .command(_, let said): got = "command \(said)"
            case .typeThenSend(let kept): got = "send[\(kept)]"
            case .ask: got = "ask"
            case .words(let words): got = "words[\(words)]"
            }
            let ok = got == expect
            if !ok { failed += 1 }
            print("[edge] \(ok ? "ok  " : "FAIL") \(name): \(got)\(ok ? "" : "  (wanted \(expect))")")
        }
        // Talking for a while, a pause, then a short stretch: a command set apart.
        let paused = talk(3) + quiet(0.7) + talk(0.7)
        let led = talk(0.7) + quiet(0.7) + talk(3)
        let oneBreath = talk(4)
        let hesitant = talk(2) + quiet(0.7) + talk(2.6)

        check("pause, then new tab", "That's the plan for friday. New tab.", paused, expect: "words[That's the plan for friday.] then new tab")
        check("same words, one breath", "Let's open a new tab", oneBreath, expect: "words[Let's open a new tab]")
        check("a pause mid thought, long tail", "I think we should close tab", hesitant, expect: "words[I think we should close tab]")
        check("new line needs no pause", "First point, new line", oneBreath, expect: "words[First point] then new line")
        check("new tab, pause, words", "New tab, flights to lisbon", led, expect: "new tab then words[Flights to lisbon]")
        check("opening command, one breath", "New tab is what i want", oneBreath, expect: "words[New tab is what i want]")
        check("closing send still sends", "Tell the team, send", oneBreath, expect: "send[Tell the team]")
        check("whole hold still a command", "Switch tab.", talk(0.8), expect: "command switch tab")
        check("undo after a pause", "Move it to ten. Undo that.", paused, expect: "words[Move it to ten.] then undo that")
        check("undo inside a sentence", "I had to undo that", oneBreath, expect: "words[I had to undo that]")
        commands.readsEdges = false
        check("switched off", "That's the plan for friday. New tab.", paused, expect: "words[That's the plan for friday. New tab.]")
        commands.readsEdges = true
        print(failed == 0 ? "[edge] all read as expected" : "[edge] \(failed) read wrong")
    }

    /// Made-up audio at 16 kHz: noise as loud as a voice, and near silence.
    private static func talk(_ seconds: Double) -> [Int16] {
        var seed: UInt32 = 12_345
        return (0..<Int(seconds * 16_000)).map { _ in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Int16(truncatingIfNeeded: Int32(seed >> 16) % 3_000)
        }
    }

    private static func quiet(_ seconds: Double) -> [Int16] {
        var seed: UInt32 = 54_321
        return (0..<Int(seconds * 16_000)).map { _ in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Int16(truncatingIfNeeded: Int32(seed >> 16) % 30)
        }
    }
}
#endif
