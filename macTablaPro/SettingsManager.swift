//
//  SettingsManager.swift
//  macTablaPro
//

import Foundation
import Combine

// MARK: - 1. Strongly Typed Codable State Models

struct TanpuraSettings: Codable, Equatable {
    var volume: Double = 1.0
    var isMuted: Bool = false
    var firstStringPitch: Double = 700.0
}

struct TablaSettings: Codable, Equatable {
    var activeTaal: String = "Teentaal"
    var activeVariation: String = "Pro Default"
    var tempoBPM: Double = 100.0
    var volume: Double = 1.0
    var isMuted: Bool = false
    var useSurTabla: Bool = false
}

struct WorkstationSettings: Codable, Equatable {
    var scaleOffsetCents: Double = 100.0
    var fineTuneCents: Double = 0.0
    var sharedTanpuraBPM: Double = 60.0
    var masterVolume: Double = 1.0
    var isAntiqueThemeEnabled: Bool = false

    var tanpura1: TanpuraSettings = TanpuraSettings()
    var tanpura2: TanpuraSettings = TanpuraSettings()
    var tabla: TablaSettings = TablaSettings()
}

// MARK: - 2. Thread-Separated Background Storage Engine

actor SettingsStorageService {
    static let shared = SettingsStorageService()

    private let fileManager = FileManager.default

    private var appSupportURL: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("macTablaPro", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var activeSettingsURL: URL {
        appSupportURL.appendingPathComponent("active_settings.json")
    }

    private var presetsDirectoryURL: URL {
        let dir = appSupportURL.appendingPathComponent("Presets", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: Active Settings Operations

    func loadActiveSettings() -> WorkstationSettings {
        guard fileManager.fileExists(atPath: activeSettingsURL.path),
              let data = try? Data(contentsOf: activeSettingsURL),
              let decoded = try? JSONDecoder().decode(WorkstationSettings.self, from: data) else {
            let defaults = WorkstationSettings()
            saveActiveSettings(defaults)
            return defaults
        }
        return decoded
    }

    func saveActiveSettings(_ settings: WorkstationSettings) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: activeSettingsURL, options: .atomic)
        } catch {
            print("❌ Background I/O Failure: Failed to write active settings: \(error)")
        }
    }

    // MARK: Presets Operations

    func listPresetNames() -> [String] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: presetsDirectoryURL.path) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }

    func savePreset(name: String, settings: WorkstationSettings) {
        let sanitizeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizeName.isEmpty else { return }
        let presetURL = presetsDirectoryURL.appendingPathComponent("\(sanitizeName).json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: presetURL, options: .atomic)
        } catch {
            print("❌ Background I/O Failure: Failed to save preset '\(name)': \(error)")
        }
    }

    func loadPreset(name: String) -> WorkstationSettings? {
        let presetURL = presetsDirectoryURL.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: presetURL),
              let decoded = try? JSONDecoder().decode(WorkstationSettings.self, from: data) else {
            return nil
        }
        return decoded
    }

    func deletePreset(name: String) {
        let presetURL = presetsDirectoryURL.appendingPathComponent("\(name).json")
        try? fileManager.removeItem(at: presetURL)
    }
}
