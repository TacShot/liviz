import SwiftUI

@main
struct LiveVizApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: SettingsStore
    @StateObject private var model: VisualizerModel
    @StateObject private var windowManager = WindowManager()

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _model = StateObject(wrappedValue: VisualizerModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            VisualizerView(model: model)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
                .background(WindowAccessor { window in
                    windowManager.attach(window)
                    model.attach(windowManager: windowManager)
                })
                .task {
                    await model.start()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 700)
        .commands {
            LiveVizCommands(model: model, settings: settings)
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
