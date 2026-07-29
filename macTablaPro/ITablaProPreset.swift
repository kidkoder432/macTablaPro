//
//  ITablaProPreset.swift
//  macTablaPro
//

import Foundation
import AppKit

// MARK: - SwarMandal Notes Container
nonisolated struct SwarMandalNotesContainer: Codable, Equatable, Sendable {
    var nsObjects: [String]?

    enum CodingKeys: String, CodingKey {
        case nsObjects = "NS.objects"
    }
}

// MARK: - iTablaPro Single Preset Schema
nonisolated struct ITablaProPreset: Codable, Equatable, Identifiable, Sendable {
    var id: String { PresetName }

    // --- Master Tuning & Metadata ---
    var PresetName: String
    var PitchName: String                // e.g. "C#3"
    var FineTuneCents: Double            // e.g. 0
    var IsFavorite: Bool                 // e.g. true
    var Tempo: Double                    // e.g. 30

    // --- Tabla Settings ---
    var TablaOn: Bool
    var TablaGain: Double
    var TablaPan: Double
    var TaalName: String                 // e.g. "Ektaal"
    var StyleName: String                // e.g. "Pro Default"
    var UseSurTabla: Bool

    // --- Tanpura 1 Settings ---
    var Tanpura1On: Bool
    var Tanpura1Gain: Double
    var Tanpura1Pan: Double
    var Tanpura1FirstString: String      // e.g. "Ni", "Pa", "Sa", "Dha", "Ma", "Kharaj"
    var Tanpura1SecondString: String?
    var Tanpura1CustomPitch: Double?
    var Tanpura1Custom2ndStringPitch: Double?

    // --- Tanpura 2 Settings ---
    var Tanpura2On: Bool
    var Tanpura2Gain: Double
    var Tanpura2Pan: Double
    var Tanpura2FirstString: String      // e.g. "Dha", "Pa", "Sa"
    var Tanpura2SecondString: String?
    var Tanpura2CustomPitch: Double?
    var Tanpura2Custom2ndStringPitch: Double?

    // --- Roadmap / Future Expansion Modules ---
    var ManjiraOn: Bool?
    var ManjiraGain: Double?
    var ManjiraPan: Double?

    var SurpetiOn: Bool?
    var SurpetiGain: Double?
    var SurpetiPan: Double?

    var SwarMandalOn: Bool?
    var SwarMandalGain: Double?
    var SwarMandalPan: Double?
    var SwarMandalLoopDuration: Int?
    var SwarMandalNotes: SwarMandalNotesContainer?

    // Helper: Default initial preset
    nonisolated static var defaultPreset: ITablaProPreset {
        ITablaProPreset(
            PresetName: "Default",
            PitchName: "C#3",
            FineTuneCents: 0,
            IsFavorite: false,
            Tempo: 100,
            TablaOn: true,
            TablaGain: 1.0,
            TablaPan: 0.0,
            TaalName: "Teentaal",
            StyleName: "Pro Default",
            UseSurTabla: false,
            Tanpura1On: true,
            Tanpura1Gain: 0.3,
            Tanpura1Pan: -0.7,
            Tanpura1FirstString: "Pa",
            Tanpura1SecondString: nil,
            Tanpura1CustomPitch: 0.0,
            Tanpura1Custom2ndStringPitch: 0.0,
            Tanpura2On: true,
            Tanpura2Gain: 0.3,
            Tanpura2Pan: 0.7,
            Tanpura2FirstString: "Sa",
            Tanpura2SecondString: nil,
            Tanpura2CustomPitch: 0.0,
            Tanpura2Custom2ndStringPitch: 0.0,
            ManjiraOn: false,
            ManjiraGain: 0.5,
            ManjiraPan: 0.0,
            SurpetiOn: false,
            SurpetiGain: 0.025,
            SurpetiPan: 0.0,
            SwarMandalOn: false,
            SwarMandalGain: 0.25,
            SwarMandalPan: 0.0,
            SwarMandalLoopDuration: 60,
            SwarMandalNotes: nil
        )
    }
}

// MARK: - iTablaPro Top-Level Container (presets.json)
nonisolated struct ITablaProPresetsContainer: Codable, Sendable {
    var keys: [String]?
    var objects: [ITablaProPreset]

    enum CodingKeys: String, CodingKey {
        case keys = "NS.keys"
        case objects = "NS.objects"
    }
}

// MARK: - Pitch & String Conversion Helpers
extension ITablaProPreset {
    /// Maps PitchName string (e.g. "C#3") to scaleOffsetCents relative to "C3"
    static func pitchNameToScaleOffsetCents(_ name: String) -> Double {
        let noteNames: [String] = [
            "A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3",
            "G3", "G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4"
        ]
        guard let index = noteNames.firstIndex(of: name) else { return 100.0 }
        let baseC3Index = 3
        return Double((index - baseC3Index) * 100)
    }

    /// Maps scaleOffsetCents back to PitchName string (e.g. 100.0 -> "C#3")
    static func scaleOffsetCentsToPitchName(_ cents: Double) -> String {
        let noteNames: [String] = [
            "A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3",
            "G3", "G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4"
        ]
        let baseC3Index = 3
        let semitoneOffset = Int(round(cents / 100.0))
        let targetIndex = baseC3Index + semitoneOffset
        guard targetIndex >= 0 && targetIndex < noteNames.count else { return "C#3" }
        return noteNames[targetIndex]
    }

    /// Maps Tanpura first string name (e.g. "Ni", "Pa", "Sa") to firstStringPitch cents
    static func stringNameToCents(_ name: String) -> Double {
        switch name {
        case "Kharaj": return 0.0
        case "Re Komal": return 100.0
        case "Re": return 200.0
        case "Ga Komal": return 300.0
        case "Ga Shuddha", "Ga": return 400.0
        case "Ma": return 500.0
        case "Ma Teevra": return 600.0
        case "Pa": return 700.0
        case "Dha Komal": return 800.0
        case "Dha": return 900.0
        case "Ni Komal": return 1000.0
        case "Ni": return 1100.0
        case "Sa": return 1200.0
        case "Re Higher Komal": return 1300.0
        case "Re Higher": return 1400.0
        case "Ga Higher Komal": return 1500.0
        case "Ga Higher": return 1600.0
        case "Ma Higher": return 1700.0
        default: return 700.0
        }
    }

    /// Maps firstStringPitch cents back to string name
    static func centsToStringName(_ cents: Double) -> String {
        let rounded = Int(round(cents))
        switch rounded {
        case 0: return "Kharaj"
        case 100: return "Re Komal"
        case 200: return "Re"
        case 300: return "Ga Komal"
        case 400: return "Ga Shuddha"
        case 500: return "Ma"
        case 600: return "Ma Teevra"
        case 700: return "Pa"
        case 800: return "Dha Komal"
        case 900: return "Dha"
        case 1000: return "Ni Komal"
        case 1100: return "Ni"
        case 1200: return "Sa"
        case 1300: return "Re Higher Komal"
        case 1400: return "Re Higher"
        case 1500: return "Ga Higher Komal"
        case 1600: return "Ga Higher"
        case 1700: return "Ma Higher"
        default: return "Pa"
        }
    }
}
