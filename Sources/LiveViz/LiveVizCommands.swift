import AppKit
import SwiftUI

struct LiveVizCommands: Commands {
    @ObservedObject var model: VisualizerModel

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("LiveViz Controls") {
                let alert = NSAlert()
                alert.messageText = "LiveViz Controls"
                alert.informativeText = """
                Space cycles the visualizer style.
                F toggles wallpaper mode.
                T toggles system theme sync.
                B toggles the dark background.
                Up Arrow increases visual intensity.
                Down Arrow decreases visual intensity.
                Esc exits wallpaper mode.
                """
                alert.alertStyle = .informational
                alert.runModal()
            }

            Divider()

            Button("Next Visualizer") {
                model.cycleStyle()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Toggle Wallpaper Mode") {
                model.toggleFullscreenDesktopMode()
            }
            .keyboardShortcut("f", modifiers: [])

            Button("Toggle Theme Sync") {
                model.toggleThemeSync()
            }
            .keyboardShortcut("t", modifiers: [])

            Button("Toggle Background") {
                model.toggleBackground()
            }
            .keyboardShortcut("b", modifiers: [])

            Button("Increase Intensity") {
                model.increaseIntensity()
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Decrease Intensity") {
                model.decreaseIntensity()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
        }
    }
}
