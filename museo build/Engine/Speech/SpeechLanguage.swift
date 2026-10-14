import Foundation
import Speech

/// Which language a muse is transcribed in.
///
/// Neither Apple speech nor Voz can tell which language it is hearing, so every muse
/// goes in this iphone's language. Picking a language in build › speech pins every new
/// muse to it instead.
nonisolated enum SpeechLanguage {
    static let storageKey = "muse.speech.language"

    /// The picked language (BCP 47, "es-MX"), or nil for auto.
    static var chosenID: String? {
        UserDefaults.standard.string(forKey: storageKey)
    }

    static func choose(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    /// Every language this iphone can transcribe, by name: the long-form model's, and
    /// dictation's for the rest (the engine uses either).
    static func available() async -> [(id: String, name: String)] {
        var ids: [String] = []
        for locale in await SpeechTranscriber.supportedLocales + DictationTranscriber.supportedLocales {
            let id = locale.identifier(.bcp47)
            if !ids.contains(id) { ids.append(id) }
        }
        return ids
            .map { (id: $0, name: name(for: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// "english (united kingdom)", in the iphone's own language, lowercase.
    static func name(for id: String) -> String {
        (Locale.current.localizedString(forIdentifier: id) ?? id).lowercased()
    }
}
