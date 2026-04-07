import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum RenderMode: String, CaseIterable, Codable, Identifiable {
    case lowPower
    case highFidelity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowPower: "Low Power"
        case .highFidelity: "High Fidelity"
        }
    }

    var prefersGPUCompositing: Bool {
        self == .highFidelity
    }

    var neonStrands: Int {
        switch self {
        case .lowPower: 8
        case .highFidelity: 18
        }
    }

    var tidalLayers: Int {
        switch self {
        case .lowPower: 3
        case .highFidelity: 6
        }
    }

    var targetBandCount: Int {
        switch self {
        case .lowPower: 36
        case .highFidelity: 96
        }
    }
}

enum FrameRatePreset: String, CaseIterable, Codable, Identifiable {
    case adaptive
    case fps30
    case fps45
    case fps60

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: "Adaptive"
        case .fps30: "30 FPS"
        case .fps45: "45 FPS"
        case .fps60: "60 FPS"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .adaptive: 1.0 / 45.0
        case .fps30: 1.0 / 30.0
        case .fps45: 1.0 / 45.0
        case .fps60: 1.0 / 60.0
        }
    }
}

enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case wallpaperMode
    case blackoutMode
    case themeSync
    case toggleBackground
    case cycleStyle
    case toggleMirror
    case visualizerHueLeft
    case visualizerHueRight
    case backgroundHueLeft
    case backgroundHueRight
    case intensityUp
    case intensityDown
    case foregroundBrightnessUp
    case foregroundBrightnessDown
    case backgroundBrightnessUp
    case backgroundBrightnessDown
    case exitWallpaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallpaperMode: "Toggle wallpaper mode"
        case .blackoutMode: "Toggle blackout mode"
        case .themeSync: "Toggle system theme sync"
        case .toggleBackground: "Toggle background"
        case .cycleStyle: "Cycle visualizer"
        case .toggleMirror: "Toggle mirroring"
        case .visualizerHueLeft: "Visualizer hue left"
        case .visualizerHueRight: "Visualizer hue right"
        case .backgroundHueLeft: "Background hue left"
        case .backgroundHueRight: "Background hue right"
        case .intensityUp: "Increase intensity"
        case .intensityDown: "Decrease intensity"
        case .foregroundBrightnessUp: "Foreground brighter"
        case .foregroundBrightnessDown: "Foreground darker"
        case .backgroundBrightnessUp: "Background brighter"
        case .backgroundBrightnessDown: "Background darker"
        case .exitWallpaper: "Exit wallpaper mode"
        }
    }
}

enum KeyOption: String, CaseIterable, Codable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case space
    case escape
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow

    var id: String { rawValue }

    var keyCode: UInt16 {
        switch self {
        case .a: 0
        case .b: 11
        case .c: 8
        case .d: 2
        case .e: 14
        case .f: 3
        case .g: 5
        case .h: 4
        case .i: 34
        case .j: 38
        case .k: 40
        case .l: 37
        case .m: 46
        case .n: 45
        case .o: 31
        case .p: 35
        case .q: 12
        case .r: 15
        case .s: 1
        case .t: 17
        case .u: 32
        case .v: 9
        case .w: 13
        case .x: 7
        case .y: 16
        case .z: 6
        case .space: 49
        case .escape: 53
        case .leftArrow: 123
        case .rightArrow: 124
        case .downArrow: 125
        case .upArrow: 126
        }
    }

    var label: String {
        switch self {
        case .space: "Space"
        case .escape: "Escape"
        case .leftArrow: "Left Arrow"
        case .rightArrow: "Right Arrow"
        case .upArrow: "Up Arrow"
        case .downArrow: "Down Arrow"
        default: rawValue.uppercased()
        }
    }

    static func from(keyCode: UInt16) -> KeyOption? {
        allCases.first { $0.keyCode == keyCode }
    }
}

struct KeyBinding: Codable, Equatable {
    var key: KeyOption
    var shift: Bool = false
    var control: Bool = false
    var option: Bool = false
    var command: Bool = false

    init(key: KeyOption, shift: Bool = false, control: Bool = false, option: Bool = false, command: Bool = false) {
        self.key = key
        self.shift = shift
        self.control = control
        self.option = option
        self.command = command
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == key.keyCode else { return false }
        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
        return shift == flags.contains(.shift)
            && control == flags.contains(.control)
            && option == flags.contains(.option)
            && command == flags.contains(.command)
    }

    var displayString: String {
        var parts: [String] = []
        if control { parts.append("Ctrl") }
        if option { parts.append("Option") }
        if shift { parts.append("Shift") }
        if command { parts.append("Cmd") }
        parts.append(key.label)
        return parts.joined(separator: " + ")
    }
}

struct ColorToken: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static func from(_ color: NSColor) -> ColorToken {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return ColorToken(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            opacity: Double(rgb.alphaComponent)
        )
    }
}

struct LUTTheme: Codable {
    var name: String
    var palette: [ColorToken]
    var backgroundGradient: [ColorToken]
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    @Published var mirrorEnabled: Bool {
        didSet { defaults.set(mirrorEnabled, forKey: Keys.mirrorEnabled) }
    }

    @Published var importedLUT: LUTTheme? {
        didSet { persistLUT() }
    }

    @Published var renderMode: RenderMode {
        didSet { defaults.set(renderMode.rawValue, forKey: Keys.renderMode) }
    }

    @Published var frameRatePreset: FrameRatePreset {
        didSet { defaults.set(frameRatePreset.rawValue, forKey: Keys.frameRatePreset) }
    }

    @Published var keyBindings: [ShortcutAction: KeyBinding] {
        didSet { persistKeyBindings() }
    }

    private let defaults = UserDefaults.standard

    init() {
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? .auto
        mirrorEnabled = defaults.object(forKey: Keys.mirrorEnabled) as? Bool ?? true
        importedLUT = SettingsStore.loadLUT(from: defaults)
        renderMode = RenderMode(rawValue: defaults.string(forKey: Keys.renderMode) ?? "") ?? .lowPower
        frameRatePreset = FrameRatePreset(rawValue: defaults.string(forKey: Keys.frameRatePreset) ?? "") ?? .adaptive
        keyBindings = SettingsStore.migratedBindings(SettingsStore.loadBindings(from: defaults))
    }

    func binding(for action: ShortcutAction) -> Binding<KeyBinding> {
        Binding(
            get: { self.keyBindings[action] ?? Self.defaultBindings[action] ?? KeyBinding(key: .space) },
            set: { self.keyBindings[action] = $0 }
        )
    }

    func action(for event: NSEvent) -> ShortcutAction? {
        ShortcutAction.allCases.first { action in
            guard let binding = keyBindings[action] else { return false }
            return binding.matches(event)
        }
    }

    func importLUT(from url: URL) throws {
        let contents = try String(contentsOf: url)
        let parsed = try LUTParser.parse(contents: contents, fallbackName: url.deletingPathExtension().lastPathComponent)
        importedLUT = parsed
    }

    func clearImportedLUT() {
        importedLUT = nil
    }

    private func persistKeyBindings() {
        let data = try? JSONEncoder().encode(keyBindings)
        defaults.set(data, forKey: Keys.keyBindings)
    }

    private func persistLUT() {
        let data = try? JSONEncoder().encode(importedLUT)
        defaults.set(data, forKey: Keys.importedLUT)
    }

    private static func loadBindings(from defaults: UserDefaults) -> [ShortcutAction: KeyBinding] {
        guard
            let data = defaults.data(forKey: Keys.keyBindings),
            let decoded = try? JSONDecoder().decode([ShortcutAction: KeyBinding].self, from: data)
        else {
            return defaultBindings
        }
        return decoded.merging(defaultBindings) { current, _ in current }
    }

    private static func loadLUT(from defaults: UserDefaults) -> LUTTheme? {
        guard
            let data = defaults.data(forKey: Keys.importedLUT),
            let decoded = try? JSONDecoder().decode(LUTTheme.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    static let defaultBindings: [ShortcutAction: KeyBinding] = [
        .wallpaperMode: KeyBinding(key: .f),
        .blackoutMode: KeyBinding(key: .d),
        .themeSync: KeyBinding(key: .t),
        .toggleBackground: KeyBinding(key: .b),
        .cycleStyle: KeyBinding(key: .space),
        .toggleMirror: KeyBinding(key: .m),
        .visualizerHueLeft: KeyBinding(key: .leftArrow),
        .visualizerHueRight: KeyBinding(key: .rightArrow),
        .backgroundHueLeft: KeyBinding(key: .leftArrow, shift: true),
        .backgroundHueRight: KeyBinding(key: .rightArrow, shift: true),
        .intensityUp: KeyBinding(key: .upArrow),
        .intensityDown: KeyBinding(key: .downArrow),
        .foregroundBrightnessUp: KeyBinding(key: .upArrow, option: true),
        .foregroundBrightnessDown: KeyBinding(key: .downArrow, option: true),
        .backgroundBrightnessUp: KeyBinding(key: .upArrow, shift: true),
        .backgroundBrightnessDown: KeyBinding(key: .downArrow, shift: true),
        .exitWallpaper: KeyBinding(key: .escape)
    ]

    private static func migratedBindings(_ bindings: [ShortcutAction: KeyBinding]) -> [ShortcutAction: KeyBinding] {
        var updated = bindings

        let oldForegroundUp = KeyBinding(key: .upArrow, control: true)
        let oldForegroundDown = KeyBinding(key: .downArrow, control: true)

        if updated[.foregroundBrightnessUp] == oldForegroundUp {
            updated[.foregroundBrightnessUp] = defaultBindings[.foregroundBrightnessUp]
        }

        if updated[.foregroundBrightnessDown] == oldForegroundDown {
            updated[.foregroundBrightnessDown] = defaultBindings[.foregroundBrightnessDown]
        }

        return updated
    }

    private enum Keys {
        static let appearanceMode = "appearanceMode"
        static let mirrorEnabled = "mirrorEnabled"
        static let importedLUT = "importedLUT"
        static let renderMode = "renderMode"
        static let frameRatePreset = "frameRatePreset"
        static let keyBindings = "keyBindings"
    }
}

private enum LUTParser {
    static func parse(contents: String, fallbackName: String) throws -> LUTTheme {
        var name = fallbackName
        var values: [[Double]] = []

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("TITLE") {
                name = extractQuotedValue(from: line) ?? fallbackName
                continue
            }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count == 3 else { continue }
            let triple = parts.compactMap { Double($0) }
            if triple.count == 3 {
                values.append(triple)
            }
        }

        guard values.count >= 3 else {
            throw NSError(domain: "LiveVizLUT", code: 1, userInfo: [NSLocalizedDescriptionKey: "The LUT file did not contain enough color values."])
        }

        func sample(at fraction: Double) -> ColorToken {
            let index = min(max(Int(Double(values.count - 1) * fraction), 0), values.count - 1)
            let triple = values[index]
            return ColorToken(red: triple[0], green: triple[1], blue: triple[2], opacity: 1)
        }

        let palette = [sample(at: 0.12), sample(at: 0.46), sample(at: 0.82)]
        let background = [sample(at: 0.02), sample(at: 0.24), sample(at: 0.62)].map(darken)
        return LUTTheme(name: name, palette: palette, backgroundGradient: background)
    }

    private static func extractQuotedValue(from line: String) -> String? {
        guard
            let start = line.firstIndex(of: "\""),
            let end = line.lastIndex(of: "\""),
            start < end
        else {
            return nil
        }
        return String(line[line.index(after: start)..<end])
    }

    private static func darken(_ token: ColorToken) -> ColorToken {
        ColorToken(
            red: token.red * 0.28,
            green: token.green * 0.28,
            blue: token.blue * 0.32,
            opacity: 1
        )
    }
}
