import AppKit
import Foundation
import SwiftUI

enum VisualizerStyle: CaseIterable {
    case neonWave
    case prismBars
    case pulseLine
    case horizonDots
    case tidalWaves
}

@MainActor
final class VisualizerModel: ObservableObject {
    @Published private(set) var bands: [CGFloat] = Array(repeating: 0.04, count: 96)
    @Published private(set) var backgroundVisible = false
    @Published private(set) var intensity: CGFloat = 1.0
    @Published private(set) var style: VisualizerStyle = .neonWave
    @Published private(set) var followsSystemTheme = true
    @Published private(set) var blackoutMode = false
    @Published private(set) var foregroundHueRotation: Double = 0
    @Published private(set) var backgroundHueRotation: Double = 0
    @Published private(set) var foregroundBrightness: Double = 1.0
    @Published private(set) var backgroundBrightness: Double = 1.0

    private var captureController: SystemAudioCapture?
    private weak var windowManager: WindowManager?
    private var hasStarted = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isRestartingCapture = false
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func attach(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        installLifecycleObservers()
        await restartCapture()
    }

    private func makeCaptureController() -> SystemAudioCapture {
        SystemAudioCapture { [weak self] samples in
            Task { @MainActor [weak self] in
                self?.consume(samples: samples)
            }
        } onError: { error in
            Task { @MainActor in
                Self.presentCaptureError(error)
            }
        }
    }

    func toggleBackground() {
        backgroundVisible.toggle()
    }

    func toggleFullscreenDesktopMode() {
        windowManager?.toggleImmersiveMode()
    }

    func cycleStyle() {
        let allStyles = VisualizerStyle.allCases
        guard let currentIndex = allStyles.firstIndex(of: style) else {
            style = .neonWave
            return
        }
        style = allStyles[(currentIndex + 1) % allStyles.count]
    }

    func increaseIntensity() {
        intensity = min(intensity + 0.12, 3.0)
    }

    func decreaseIntensity() {
        intensity = max(intensity - 0.12, 0.2)
    }

    func toggleThemeSync() {
        followsSystemTheme.toggle()
    }

    func toggleBlackoutMode() {
        blackoutMode.toggle()
    }

    func toggleMirror() {
        settings.mirrorEnabled.toggle()
    }

    func shiftVisualizerColor(direction: Double) {
        withAnimation(.easeInOut(duration: 0.28)) {
            foregroundHueRotation = normalizedHue(foregroundHueRotation + direction)
        }
    }

    func shiftBackgroundColor(direction: Double) {
        withAnimation(.easeInOut(duration: 0.28)) {
            backgroundHueRotation = normalizedHue(backgroundHueRotation + direction)
        }
    }

    func adjustForegroundBrightness(delta: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            foregroundBrightness = clampedBrightness(foregroundBrightness + delta)
        }
    }

    func adjustBackgroundBrightness(delta: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            backgroundBrightness = clampedBrightness(backgroundBrightness + delta)
        }
    }

    func handleKey(event: NSEvent) {
        guard let action = settings.action(for: event) else { return }

        switch action {
        case .wallpaperMode:
            toggleFullscreenDesktopMode()
        case .blackoutMode:
            toggleBlackoutMode()
        case .themeSync:
            toggleThemeSync()
        case .toggleBackground:
            toggleBackground()
        case .cycleStyle:
            cycleStyle()
        case .toggleMirror:
            toggleMirror()
        case .visualizerHueLeft:
            shiftVisualizerColor(direction: -0.08)
        case .visualizerHueRight:
            shiftVisualizerColor(direction: 0.08)
        case .backgroundHueLeft:
            shiftBackgroundColor(direction: -0.08)
        case .backgroundHueRight:
            shiftBackgroundColor(direction: 0.08)
        case .intensityUp:
            increaseIntensity()
        case .intensityDown:
            decreaseIntensity()
        case .foregroundBrightnessUp:
            adjustForegroundBrightness(delta: 0.08)
        case .foregroundBrightnessDown:
            adjustForegroundBrightness(delta: -0.08)
        case .backgroundBrightnessUp:
            adjustBackgroundBrightness(delta: 0.08)
        case .backgroundBrightnessDown:
            adjustBackgroundBrightness(delta: -0.08)
        case .exitWallpaper:
            if windowManager?.isImmersiveMode == true {
                windowManager?.toggleImmersiveMode()
            }
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

    private func installLifecycleObservers() {
        guard workspaceObservers.isEmpty else { return }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let mainCenter = NotificationCenter.default

        let notifications: [(NotificationCenter, Notification.Name)] = [
            (workspaceCenter, NSWorkspace.didWakeNotification),
            (workspaceCenter, NSWorkspace.screensDidWakeNotification),
            (workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification),
            (mainCenter, NSApplication.didBecomeActiveNotification)
        ]

        workspaceObservers = notifications.map { center, name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.restartCapture()
                }
            }
        }
    }

    private func restartCapture() async {
        guard !isRestartingCapture else { return }
        isRestartingCapture = true
        defer { isRestartingCapture = false }

        if let captureController {
            await captureController.stop()
            self.captureController = nil
        }

        let capture = makeCaptureController()
        captureController = capture
        await capture.start()
    }

    private func normalizedHue(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }

    private func clampedBrightness(_ value: Double) -> Double {
        min(max(value, 0.2), 1.4)
    }

    private static func presentCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "LiveViz captures system audio through ScreenCaptureKit. Grant Screen Recording access in System Settings, then reopen the app.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
