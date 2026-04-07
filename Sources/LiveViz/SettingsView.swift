import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var importingLUT = false
    @State private var importError: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("App appearance", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("Mirror visualizations", isOn: $settings.mirrorEnabled)
            }

            Section("Performance") {
                Picker("Render mode", selection: $settings.renderMode) {
                    ForEach(RenderMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("Frame rate", selection: $settings.frameRatePreset) {
                    ForEach(FrameRatePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Text("Low Power reduces redraw detail and compositing. High Fidelity keeps the richer layered look and uses more GPU-assisted compositing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Color Processing") {
                if let lut = settings.importedLUT {
                    HStack {
                        Text("Imported LUT")
                        Spacer()
                        Text(lut.name)
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear LUT") {
                        settings.clearImportedLUT()
                    }
                }

                Button("Import LUT (.cube)") {
                    importingLUT = true
                }

                if let importError {
                    Text(importError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("Keybindings") {
                ForEach(ShortcutAction.allCases) { action in
                    KeyBindingRow(title: action.title, binding: settings.binding(for: action))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 760)
        .padding(20)
        .fileImporter(
            isPresented: $importingLUT,
            allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                try settings.importLUT(from: url)
                importError = nil
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

private struct KeyBindingRow: View {
    let title: String
    @Binding var binding: KeyBinding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack {
                Picker("Key", selection: $binding.key) {
                    ForEach(KeyOption.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }
                Toggle("Shift", isOn: $binding.shift)
                Toggle("Ctrl", isOn: $binding.control)
                Toggle("Option", isOn: $binding.option)
                Toggle("Cmd", isOn: $binding.command)
            }
            Text(binding.displayString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
