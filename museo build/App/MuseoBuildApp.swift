import SwiftUI

@main
struct MuseoBuildApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = MuseLab.requested {
                LabRoot(id: screen)
                    .preferredColorScheme(.light)
            } else {
                AppRoot()
            }
            #else
            AppRoot()
            #endif
        }
    }
}

/// Starts the app at launch, before any screen.
///
/// The ring starts here (`Museo.start`, inside `AppStart.start`), never inside a view, so
/// iOS can relaunch the app for the ring in the background (CoreBluetooth state
/// restoration) and recordings still come in while no screen is showing.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        // Lab screens are mock-only: no ring, no stores, no prompts.
        if MuseLab.requested != nil { return true }
        #endif
        AppStart.start()
        return true
    }
}

/// The real app: the home, with everything else one tap away.
struct AppRoot: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootView()
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: AppStart.becameActive()
                case .background: AppStart.wentToBackground()
                default: break
                }
            }
    }
}
