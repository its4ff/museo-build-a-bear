import CoreText
import Foundation

/// Registers Lora and Satoshi from `Shared/` before the first view draws.
/// `MuseFont` resolves names once and caches them, so this must run in `App.init`.
nonisolated enum FontRegistrar {
    static func registerBundledFonts() {
        for fileName in ["Lora-Variable", "Satoshi-Variable"] {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "ttf") else {
                print("[muse][font] missing \(fileName).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error), let error {
                print("[muse][font] \(fileName): \(error.takeRetainedValue().localizedDescription)")
            }
        }
    }
}
