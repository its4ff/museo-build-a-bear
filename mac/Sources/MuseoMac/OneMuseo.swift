import AppKit
import Foundation

/// One museo at a time on a mac. Two copies (the released one and a build from this repo)
/// would share the one ring and write over the same library, so the newest one opened
/// takes over and the older one quits.
enum OneMuseo {
    /// Quits any other running museo and waits for it to go, before the ring or the
    /// library are touched. A copy with no bundle (a render from the command line) is left out.
    static func takeOver() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let mine = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != mine }
        guard !others.isEmpty else { return }
        print("[museo][mac] another museo is open: taking over from it")
        others.forEach { $0.terminate() }
        // It saves its library as it quits, so give it a moment before reading the same file.
        let deadline = Date().addingTimeInterval(3)
        while others.contains(where: { !$0.isTerminated }), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    }
}
