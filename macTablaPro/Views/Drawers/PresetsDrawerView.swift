import SwiftUI
import AppKit

// MARK: - Left Presets Translucent Glass Drawer View
struct PresetsDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var searchFilter: String = ""
    @State private var newPresetName: String = ""
    @State private var isShowingSaveField = false

    var filteredPresets: [ITablaProPreset] {
        let baseList = audio.allPresets.sorted { $0.PresetName.localizedStandardCompare($1.PresetName) == .orderedAscending }
        if searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return baseList
        }
        return baseList.filter { $0.PresetName.localizedCaseInsensitiveContains(searchFilter) }
    }

    private func presetTooltipText(for preset: ITablaProPreset) -> String {
        """
        🎵 Preset: \(preset.PresetName)
        • Pitch: \(preset.PitchName)
        • Tanpura 1: \(preset.Tanpura1FirstString) (\(Int(preset.Tanpura1Gain * 100))%)
        • Tanpura 2: \(preset.Tanpura2FirstString) (\(Int(preset.Tanpura2Gain * 100))%)
        • Tabla: \(preset.TaalName) - \(preset.StyleName) (\(Int(preset.Tempo)) BPM)
        """
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Workstation Presets")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        audio.isPresetsPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Search Bar Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Filter presets...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            Divider()

            // Presets Scroll List (Auto-centered on active preset)
            if filteredPresets.isEmpty {
                Text("No matching presets found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredPresets) { preset in
                                let isActive = (audio.activePresetName == preset.PresetName)
                                HStack(spacing: 6) {
                                    // Favorite Star Toggle
                                    Button(action: {
                                        Task {
                                            await SettingsStorageService.shared.toggleFavorite(presetName: preset.PresetName)
                                            audio.refreshAllPresets()
                                        }
                                    }) {
                                        Image(systemName: preset.IsFavorite ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(preset.IsFavorite ? .yellow : .secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)

                                    // Apply Preset Button with Hover Tooltip & Right-Click Context Menu
                                    Button(action: {
                                        audio.applyPreset(preset)
                                        Task {
                                            await SettingsStorageService.shared.saveActiveSettings(preset)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isActive ? (audio.isAntiqueThemeEnabled ? .orange : .accentColor) : .secondary)
                                            Text(preset.PresetName)
                                                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                                                .foregroundColor(isActive ? .primary : .secondary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isActive ?
                                                    (audio.isAntiqueThemeEnabled ? Color.orange.opacity(0.25) : Color.accentColor.opacity(0.2)) :
                                                    Color(NSColor.controlBackgroundColor).opacity(0.4)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isActive ? (audio.isAntiqueThemeEnabled ? Color.orange : Color.accentColor) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help(presetTooltipText(for: preset))
                                    .contextMenu {
                                        Text("🎵 \(preset.PresetName)").font(.headline)
                                        Divider()
                                        Text("Pitch: \(preset.PitchName)")
                                        Text("Tanpura 1: \(preset.Tanpura1FirstString) (\(Int(preset.Tanpura1Gain * 100))%)")
                                        Text("Tanpura 2: \(preset.Tanpura2FirstString) (\(Int(preset.Tanpura2Gain * 100))%)")
                                        Text("Tabla: \(preset.TaalName) (\(preset.StyleName)) @ \(Int(preset.Tempo)) BPM")
                                    }

                                    // Delete Preset Button
                                    Button(action: {
                                        Task {
                                            await SettingsStorageService.shared.deletePreset(name: preset.PresetName)
                                            if audio.activePresetName == preset.PresetName {
                                                audio.activePresetName = nil
                                            }
                                            audio.refreshAllPresets()
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Preset")
                                }
                                .id(preset.PresetName)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                    .onAppear {
                        if let activeName = audio.activePresetName {
                            scrollProxy.scrollTo(activeName, anchor: .center)
                        }
                    }
                    .onChange(of: audio.isPresetsPresented) { isPresented in
                        if isPresented, let activeName = audio.activePresetName {
                            scrollProxy.scrollTo(activeName, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Save Custom Preset Field
            if isShowingSaveField {
                VStack(spacing: 8) {
                    TextField("Preset Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Cancel") {
                            isShowingSaveField = false
                            newPresetName = ""
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Save") {
                            let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let snapshot = audio.capturePreset(name: name)
                            Task {
                                await SettingsStorageService.shared.savePreset(snapshot)
                                audio.activePresetName = name
                                audio.refreshAllPresets()
                                isShowingSaveField = false
                                newPresetName = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                Button(action: {
                    isShowingSaveField = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Current as Preset")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            // Finder & Reset Utility Buttons
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await SettingsStorageService.shared.openPresetsFolderInFinder()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text("Reveal in Finder")
                    }
                    .font(.system(size: 11, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Open Application Support folder containing presets.json to share")

                Spacer()

                Button(action: {
                    Task {
                        await SettingsStorageService.shared.resetPresetsToDefault()
                        audio.refreshAllPresets()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Defaults")
                    }
                    .font(.system(size: 11, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange.opacity(0.8))
                .help("Restore factory presets.json from app bundle")
            }
        }
        .padding(16)
        .frame(width: 300)
        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 20)
        .padding(.leading, 24)
        .padding(.top, 12)
    }
}
