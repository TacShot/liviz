import AppKit
import Foundation

@MainActor
final class VisualizerModel: ObservableObject {
    @Published private(set) var bands: [CGFloat] = Array(repeating: 0.04, count: 96)
    @Published private(set) var backgroundVisible = false
    @Published private(set) var intensity: CGFloat = 1.0

    private var captureController: SystemAudioCapture?
    private weak var windowManager: WindowManager?
    private var hasStarted = false

    func attach(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        let capture = SystemAudioCapture { [weak self] samples in
            Task { @MainActor [weak self] in
                self?.consume(samples: samples)
            }
        } onError: { error in
            Task { @MainActor in
                Self.presentCaptureError(error)
            }
        }

        captureController = capture
        await capture.start()
    }

    func toggleBackground() {
        backgroundVisible.toggle()
    }

    func toggleFullscreenDesktopMode() {
        windowManager?.toggleImmersiveMode()
    }

    func increaseIntensity() {
        intensity = min(intensity + 0.12, 3.0)
    }

    func decreaseIntensity() {
        intensity = max(intensity - 0.12, 0.2)
    }

    func handleKey(event: NSEvent) {
        switch event.keyCode {
        case 3:
            toggleFullscreenDesktopMode()
        case 11:
            toggleBackground()
        case 126:
            increaseIntensity()
        case 125:
            decreaseIntensity()
        case 53:
            if windowManager?.isImmersiveMode == true {
                windowManager?.toggleImmersiveMode()
            }
        default:
            break
        }
    }

    private func consume(samples: [Float]) {
        guard !samples.isEmpty else { return }

        let targetCount = bands.count
        let chunkSize = max(samples.count / targetCount, 1)
        var next = Array(repeating: CGFloat(0), count: targetCount)

        for index in 0..<targetCount {
            let start = index * chunkSize
            guard start < samples.count else { break }

            let end = min(start + chunkSize, samples.count)
            let slice = samples[start..<end]
            let sum = slice.reduce(Float.zero) { partial, value in
                partial + abs(value)
            }
            let normalized = CGFloat(sum / Float(slice.count)) * intensity * 4.4
            let eased = pow(min(normalized, 1.5), 0.82)
            next[index] = max(0.015, eased)
        }

        for index in next.indices {
            let smoothed = (bands[index] * 0.68) + (next[index] * 0.32)
            bands[index] = max(0.012, smoothed)
        }
    }

    private static func presentCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "LiveViz captures system audio through ScreenCaptureKit. Grant Screen Recording access in System Settings, then reopen the app.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
