import AppKit
import SwiftUI

struct LiveVizCommands: Commands {
    @ObservedObject var model: VisualizerModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            SettingsLink {
                Text("Settings…")
            }
        }

        CommandGroup(replacing: .help) {
            Button("LiveViz Controls") {
                let alert = NSAlert()
                alert.messageText = "LiveViz Controls"
                alert.informativeText = """
                Space cycles the visualizer style.
                F toggles wallpaper mode.
                D toggles blackout mode.
                T toggles system theme sync.
                M toggles mirroring.
                B toggles the dark background.
                Left and Right change the visualizer colors.
                Shift plus Left and Right change the background colors.
                Option plus Up and Down change foreground darkness.
                Shift plus Up and Down change background darkness.
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

            Button("Toggle Mirroring") {
                model.toggleMirror()
            }
            .keyboardShortcut("m", modifiers: [])

            Button("Toggle Wallpaper Mode") {
                model.toggleFullscreenDesktopMode()
            }
            .keyboardShortcut("f", modifiers: [])

            Button("Toggle Blackout Mode") {
                model.toggleBlackoutMode()
            }
            .keyboardShortcut("d", modifiers: [])

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
