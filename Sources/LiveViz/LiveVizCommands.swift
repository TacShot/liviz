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
                F toggles desktop-style fullscreen.
                B toggles the dark background.
                Up Arrow increases visual intensity.
                Down Arrow decreases visual intensity.
                Esc exits desktop-style fullscreen.
                """
                alert.alertStyle = .informational
                alert.runModal()
            }

            Divider()

            Button("Toggle Desktop Fullscreen") {
                model.toggleFullscreenDesktopMode()
            }
            .keyboardShortcut("f", modifiers: [])

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
