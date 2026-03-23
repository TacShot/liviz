import AppKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {
    weak var window: NSWindow?
    private(set) var isImmersiveMode = false

    private var savedFrame: NSRect = .zero
    private var savedStyleMask: NSWindow.StyleMask = []
    private var savedLevel: NSWindow.Level = .normal
    private var savedCollectionBehavior: NSWindow.CollectionBehavior = []
    private var savedPresentationOptions: NSApplication.PresentationOptions = []

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        configure(window)
    }

    func toggleImmersiveMode() {
        guard let window else { return }
        isImmersiveMode ? restore(window) : enterImmersiveMode(window)
        isImmersiveMode.toggle()
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenPrimary)
    }

    private func enterImmersiveMode(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        savedFrame = window.frame
        savedStyleMask = window.styleMask
        savedLevel = window.level
        savedCollectionBehavior = window.collectionBehavior
        savedPresentationOptions = NSApp.presentationOptions

        window.styleMask = [.borderless, .fullSizeContentView]
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .fullScreenDisallowsTiling]
        window.setFrame(screen.frame, display: true, animate: false)

        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }

        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    }

    private func restore(_ window: NSWindow) {
        window.styleMask = savedStyleMask
        window.level = savedLevel
        window.collectionBehavior = savedCollectionBehavior
        window.setFrame(savedFrame, display: true, animate: false)
        configure(window)

        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = false
        }

        NSApp.presentationOptions = savedPresentationOptions
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @ObservedObject var model: VisualizerModel

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.model = model
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.model = model
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class KeyView: NSView {
        weak var model: VisualizerModel?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            model?.handleKey(event: event)
        }
    }
}
