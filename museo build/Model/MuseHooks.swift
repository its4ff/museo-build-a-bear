import Foundation

/// Something that happened to a muse.
nonisolated enum MuseEvent: Sendable {
    /// A muse landed on this phone (words may still be on their way).
    case arrived(Muse)
    /// Its words landed. Fires once per muse, the first time. Typed muses fire this right
    /// after `arrived`. "transcribe again" brings new words as `updated`, not a second one.
    case transcribed(Muse)
    /// Anything else changed (title, notes, state, language, new words after "transcribe again").
    /// Keeping your own copy (a log, a local index)? Key it by `muse.id`, update it here.
    case updated(Muse)
    /// It was deleted.
    case removed(UUID)
}

/// Listen to muses from your own code. Any number of listeners, all on the main actor.
///
/// ```swift
/// MuseHooks.onTranscribed { muse in
///     print("heard:", muse.words)       // index it, log it, act on it
/// }
/// ```
///
/// A memory recording over 30 minutes arrives and is transcribed part by part, then each later
/// part folds into the first: `.updated(first)` with all the words, then `.removed(part)`.
///
/// Your hooks live in `App/YourCode.swift`. Anything that sends a muse off the phone sits
/// behind a switch the person turns on.
@MainActor
enum MuseHooks {
    /// Keep it to stop listening with `MuseHooks.cancel(_:)`. Ignore it to listen forever.
    struct Token: Hashable, Sendable {
        fileprivate let id = UUID()
    }

    private static var listeners: [Token: (MuseEvent) -> Void] = [:]

    @discardableResult
    static func on(_ listener: @escaping (MuseEvent) -> Void) -> Token {
        let token = Token()
        listeners[token] = listener
        return token
    }

    @discardableResult
    static func onArrived(_ listener: @escaping (Muse) -> Void) -> Token {
        on { if case .arrived(let muse) = $0 { listener(muse) } }
    }

    @discardableResult
    static func onTranscribed(_ listener: @escaping (Muse) -> Void) -> Token {
        on { if case .transcribed(let muse) = $0 { listener(muse) } }
    }

    @discardableResult
    static func onUpdated(_ listener: @escaping (Muse) -> Void) -> Token {
        on { if case .updated(let muse) = $0 { listener(muse) } }
    }

    @discardableResult
    static func onRemoved(_ listener: @escaping (UUID) -> Void) -> Token {
        on { if case .removed(let id) = $0 { listener(id) } }
    }

    static func cancel(_ token: Token) {
        listeners[token] = nil
    }

    /// Every event as an async sequence, for `for await` loops.
    static func events() -> AsyncStream<MuseEvent> {
        AsyncStream { continuation in
            let token = on { continuation.yield($0) }
            continuation.onTermination = { _ in
                Task { @MainActor in cancel(token) }
            }
        }
    }

    /// Called by `MuseStore`. Builders don't need this.
    static func emit(_ event: MuseEvent) {
        for listener in listeners.values { listener(event) }
    }
}
