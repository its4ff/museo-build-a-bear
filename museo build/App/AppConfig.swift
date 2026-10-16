import Foundation

/// The few knobs that make this app yours. Change them here, not across the code.
nonisolated enum AppConfig {
    /// Your app's name, lowercase. The home title reads "\(appName)." with the period.
    static let appName = "museo"

    /// What the AccessorySetupKit picker calls the ring. The first app to set a ring up
    /// names it for every app, so keep it plain.
    static let ringName = "museo"

    /// Words for the on-device recognizer to expect (names, products, jargon).
    static let vocabulary = ["museo", "muse"]

    /// The line under your app's name in build › about: what it is, and who made it.
    static let madeBy = "a simple kit by 4ff, to build anything you can imagine on museo."

    /// A way for people to reach you, as a row in build › about. Nil leaves the row out.
    ///
    /// ```swift
    /// static let contact: Contact? = Contact(
    ///     title: "message me on x",
    ///     detail: "questions, or what you made with it",
    ///     url: URL(string: "https://x.com/yourname")!
    /// )
    /// ```
    static let contact: Contact? = nil

    /// A row in build › about that opens a link: X, email (`mailto:`), a site.
    struct Contact: Sendable {
        let title: String
        let detail: String
        let url: URL
    }

    /// How the one ring icon looks.
    static let ringButtonStyle: RingButtonStyle = .island

    /// Fresh muses type their words in, letter by letter, with light key taps.
    static let typesNewWords = true

    /// The app leaves recordings on the ring after it brings them in, so another app
    /// (or a reinstall) never loses one. Turn on in the ring sheet to wipe the ring after
    /// every clean sync instead.
    static let clearsRingAfterSyncByDefault = false

    enum RingButtonStyle: String, CaseIterable, Identifiable, Sendable {
        /// The ring as a gauge: band is battery, fill is the link, a count while syncing.
        case glyph
        /// The gauge plus the battery percent.
        case glyphPercent
        /// A text pill: "ring · linked".
        case pill
        /// One capsule that says what the ring is doing ("bringing in 3", a clock while
        /// you hold), then settles back to the battery.
        case island
        var id: String { rawValue }
    }
}
