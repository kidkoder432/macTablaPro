//
//  SettingsManager.swift
//  macTablaPro
//

import Foundation
import Combine
import AppKit

// MARK: - 1. Strongly Typed Codable State Models

nonisolated struct TanpuraSettings: Codable, Equatable, Sendable {
    var volume: Double = 1.0
    var isMuted: Bool = false
    var firstStringPitch: Double = 700.0
}

nonisolated struct TablaSettings: Codable, Equatable, Sendable {
    var activeTaal: String = "Teentaal"
    var activeVariation: String = "Pro Default"
    var tempoBPM: Double = 100.0
    var volume: Double = 1.0
    var isMuted: Bool = false
    var useSurTabla: Bool = false
}

nonisolated struct SwarMandalSettings: Codable, Equatable, Sendable {
    var volume: Double = 0.25
    var isMuted: Bool = false
    var tempoBPM: Double = 450.0
    var loopDurationSec: Int = 60
    var stringCount: Int = 20
    var stringNotes: [String] = []
}

nonisolated struct WorkstationSettings: Codable, Equatable, Sendable {
    var scaleOffsetCents: Double = 100.0
    var fineTuneCents: Double = 0.0
    var sharedTanpuraBPM: Double = 60.0
    var masterVolume: Double = 1.0
    var isAntiqueThemeEnabled: Bool = false

    var tanpura1: TanpuraSettings = TanpuraSettings()
    var tanpura2: TanpuraSettings = TanpuraSettings()
    var tabla: TablaSettings = TablaSettings()
    var swarMandal: SwarMandalSettings = SwarMandalSettings()
}

// MARK: - 2. Thread-Separated Background Storage Engine

actor SettingsStorageService {
    static let shared = SettingsStorageService()

    private let fileManager = FileManager.default
    private var cachedPresetsContainer: ITablaProPresetsContainer? = nil

    private var appSupportURL: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("macTablaPro", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var activeSettingsFileURL: URL {
        appSupportURL.appendingPathComponent("active_settings.json")
    }

    var userPresetsFileURL: URL {
        appSupportURL.appendingPathComponent("presets.json")
    }

    init() {
        ensureUserPresetsExist()
    }

    // MARK: - Initial Bundle Copy & Setup

    nonisolated private func ensureUserPresetsExist() {
        let fm = FileManager.default
        let urls = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("macTablaPro", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let presetsURL = dir.appendingPathComponent("presets.json")
        if !fm.fileExists(atPath: presetsURL.path) {
            if let bundledURL = Bundle.main.url(forResource: "presets", withExtension: "json") {
                try? fm.copyItem(at: bundledURL, to: presetsURL)
                print("📁 Copied bundled presets.json to Application Support.")
            }
        }
    }

    func resetPresetsToDefault() {
        cachedPresetsContainer = nil
        if fileManager.fileExists(atPath: userPresetsFileURL.path) {
            try? fileManager.removeItem(at: userPresetsFileURL)
        }
        ensureUserPresetsExist()
        _ = loadAllPresetsContainer()
    }

    func openPresetsFolderInFinder() {
        ensureUserPresetsExist()
        let fileURL = userPresetsFileURL
        let parentURL = appSupportURL
        Task { @MainActor in
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: parentURL.path)
        }
    }

    // MARK: - Workstation State Persistence (active_settings.json)

    func loadActiveSettings() -> ITablaProPreset {
        ensureUserPresetsExist()
        guard fileManager.fileExists(atPath: activeSettingsFileURL.path),
            let data = try? Data(contentsOf: activeSettingsFileURL),
            let preset = try? JSONDecoder().decode(ITablaProPreset.self, from: data) else {
            let container = loadAllPresetsContainer()
            return container.objects.first ?? ITablaProPreset.defaultPreset
        }
        return preset
    }

    func saveActiveSettings(_ preset: ITablaProPreset) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(preset)
            try data.write(to: activeSettingsFileURL, options: .atomic)
        } catch {
            print("❌ Background I/O Failure: Failed to write active settings: \(error)")
        }
    }

    // MARK: - Presets Container Operations (presets.json Cached In Memory)

    func loadAllPresetsContainer() -> ITablaProPresetsContainer {
        if let cached = cachedPresetsContainer {
            return cached
        }
        ensureUserPresetsExist()
        guard fileManager.fileExists(atPath: userPresetsFileURL.path),
            let data = try? Data(contentsOf: userPresetsFileURL),
            let container = try? JSONDecoder().decode(ITablaProPresetsContainer.self, from: data) else {
            let empty = ITablaProPresetsContainer(keys: [], objects: [])
            cachedPresetsContainer = empty
            return empty
        }
        cachedPresetsContainer = container
        return container
    }

    func savePresetsContainer(_ container: ITablaProPresetsContainer) {
        cachedPresetsContainer = container
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(container)
            try data.write(to: userPresetsFileURL, options: .atomic)
        } catch {
            print("❌ Background I/O Failure: Failed to write presets.json: \(error)")
        }
    }

    func loadPreset(name: String) -> ITablaProPreset? {
        let container = loadAllPresetsContainer()
        return container.objects.first(where: { $0.PresetName == name })
    }

    func savePreset(_ preset: ITablaProPreset) {
        var container = loadAllPresetsContainer()
        if let index = container.objects.firstIndex(where: { $0.PresetName == preset.PresetName }) {
            container.objects[index] = preset
        } else {
            container.objects.append(preset)
            if container.keys != nil {
                container.keys?.append(preset.PresetName)
            }
        }
        savePresetsContainer(container)
    }

    func toggleFavorite(presetName: String) {
        var container = loadAllPresetsContainer()
        if let index = container.objects.firstIndex(where: { $0.PresetName == presetName }) {
            container.objects[index].IsFavorite.toggle()
            savePresetsContainer(container)
        }
    }

    func deletePreset(name: String) {
        var container = loadAllPresetsContainer()
        container.objects.removeAll(where: { $0.PresetName == name })
        container.keys?.removeAll(where: { $0 == name })
        savePresetsContainer(container)
    }
}
