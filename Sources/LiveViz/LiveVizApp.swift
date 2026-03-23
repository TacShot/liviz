import SwiftUI

@main
struct LiveVizApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = VisualizerModel()
    @StateObject private var windowManager = WindowManager()

    var body: some Scene {
        WindowGroup {
            VisualizerView(model: model)
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
            LiveVizCommands(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
