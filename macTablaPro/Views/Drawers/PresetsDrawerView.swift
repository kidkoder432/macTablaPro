import SwiftUI
import AppKit

// MARK: - Preset Tab Filter
enum PresetTab: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

// MARK: - Full-Height Presets Sidebar View
struct PresetsDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var selectedTab: PresetTab = .all
    @State private var searchFilter: String = ""
    @State private var newPresetName: String = ""
    @State private var isShowingSaveField = false

    var allPresetsSorted: [ITablaProPreset] {
        audio.allPresets.sorted { $0.PresetName.localizedStandardCompare($1.PresetName) == .orderedAscending }
    }

    var favoritePresetsCount: Int {
        audio.allPresets.filter { $0.IsFavorite }.count
    }

    var filteredPresets: [ITablaProPreset] {
        var baseList = allPresetsSorted
        if selectedTab == .favorites {
            baseList = baseList.filter { $0.IsFavorite }
        }
        if !searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseList = baseList.filter { $0.PresetName.localizedCaseInsensitiveContains(searchFilter) }
        }
        return baseList
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
        let isAntique = audio.isAntiqueThemeEnabled

        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header: Title & Close / Collapse Button
            HStack {
                Label("Presets", systemImage: "slider.horizontal.2.square")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isAntique ? Color.orange : .primary)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        audio.isPresetsPresented = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide Presets Sidebar")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // MARK: - Tab Segment: All vs Favorites
            Picker("", selection: $selectedTab) {
                Text("All (\(audio.allPresets.count))").tag(PresetTab.all)
                Text("★ Favorites (\(favoritePresetsCount))").tag(PresetTab.favorites)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)

            // MARK: - Search Bar Filter
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
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAntique ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 14)

            // MARK: - Preset Load Options (Scope Checkboxes)
            VStack(alignment: .leading, spacing: 5) {
                Text("APPLY TO PRESET LOADING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isAntique ? Color.orange.opacity(0.8) : .secondary)

                HStack(spacing: 8) {
                    Toggle("Tanpuras", isOn: $audio.presetLoadOptions.loadTanpura)
                    Toggle("Swar Mandal", isOn: $audio.presetLoadOptions.loadSwarMandal)
                    Toggle("Mixer", isOn: $audio.presetLoadOptions.loadMixer)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 10))

                HStack(spacing: 8) {
                    Toggle("Pitch", isOn: $audio.presetLoadOptions.loadPitch)
                    Toggle("Tabla", isOn: $audio.presetLoadOptions.loadTabla)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 10))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAntique ? Color.orange.opacity(0.2) : Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 14)

            Divider()
                .padding(.horizontal, 10)

            // MARK: - Presets Scroll List (Full Height)
            if filteredPresets.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    if selectedTab == .favorites {
                        Image(systemName: "star.slash")
                            .font(.system(size: 32))
                            .foregroundColor(isAntique ? Color.orange.opacity(0.5) : Color.secondary.opacity(0.4))
                        Text("No Favorite Presets")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Click the star on any preset to add it to your favorites.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No matching presets found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredPresets) { preset in
                                let isActive = (audio.activePresetName == preset.PresetName)
                                let isModified = isActive && audio.isPresetModified

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
                                            .foregroundColor(preset.IsFavorite ? .yellow : .secondary.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help(preset.IsFavorite ? "Remove from Favorites" : "Add to Favorites")

                                    // Apply / Restore Preset Button
                                    Button(action: {
                                        audio.applyPreset(preset)
                                        Task {
                                            await SettingsStorageService.shared.saveActiveSettings(preset)
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            if isModified {
                                                Image(systemName: "pencil.circle.fill")
                                                    .foregroundColor(isAntique ? Color.yellow : Color.orange)
                                                    .font(.system(size: 11, weight: .semibold))
                                            } else {
                                                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(isActive ? (isAntique ? .orange : .accentColor) : .secondary.opacity(0.5))
                                                    .font(.system(size: 11))
                                            }

                                            Text(preset.PresetName)
                                                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                                                .foregroundColor(isActive ? .primary : .secondary)
                                                .lineLimit(1)

                                            if isModified {
                                                Text("(Modified)")
                                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                                    .foregroundColor(isAntique ? Color.yellow : Color.orange)
                                            }

                                            Spacer()
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isActive ?
                                                    (isModified ?
                                                        (isAntique ? Color.yellow.opacity(0.18) : Color.orange.opacity(0.18)) :
                                                        (isAntique ? Color.orange.opacity(0.25) : Color.accentColor.opacity(0.2))) :
                                                    Color.clear
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isActive ?
                                                    (isModified ? (isAntique ? Color.yellow : Color.orange) : (isAntique ? Color.orange : Color.accentColor)) :
                                                    Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    .help(isModified ? "Modified from saved preset. Click to restore '\(preset.PresetName)'" : presetTooltipText(for: preset))
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
                                            .font(.system(size: 10))
                                            .foregroundColor(.red.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Preset")
                                }
                                .id(preset.PresetName)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(maxHeight: .infinity)
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
                .padding(.horizontal, 10)

            // MARK: - Save Custom Preset Field / Trigger
            VStack(spacing: 8) {
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
                        .frame(maxWidth: .infinity)
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
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 275)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                if isAntique {
                    Color.black.opacity(0.55)
                } else {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                }
            }
            .ignoresSafeArea()
        )
    }
}
