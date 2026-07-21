import Foundation
import SwiftCSV

// MARK: - Compound Bol Sub-Stroke Tuning Map
struct SubStrokeRecipe {
    let ratio1: Double
    let left1: String?
    let right1: String?
    let ratio2: Double
    let left2: String?
    let right2: String?
}

/// Declarative Tuning Map for Compound Tabla Bols
/// Key: Compound bol string from CSV (e.g. "KDa", "TaKa", "NaKa", "Tra", "TiTaL")
/// Value: Recipe specifying duration split ratios and single-stroke sample names.
let compoundBolTuningMap: [String: SubStrokeRecipe] = [
    "KDa": SubStrokeRecipe(
        ratio1: 0.25, left1: "Ka", right1: nil,
        ratio2: 0.75, left2: nil, right2: "Din"
    ),
    "TaKa": SubStrokeRecipe(
        ratio1: 0.50, left1: nil, right1: "Ta",
        ratio2: 0.50, left2: "Ka", right2: nil
    ),
    "NaKa": SubStrokeRecipe(
        ratio1: 0.50, left1: nil, right1: "Na",
        ratio2: 0.50, left2: "Ka", right2: nil
    ),
    "Tra": SubStrokeRecipe(
        ratio1: 0.2, left1: nil, right1: "Ti",
        ratio2: 0.8, left2: nil, right2: "Ra"
    ),
    "TiTaL": SubStrokeRecipe(
        ratio1: 0.50, left1: nil, right1: "TiL",
        ratio2: 0.50, left2: nil, right2: "TTaL"
    )
]

// MARK: - 1. Taal Core Metadata
/// Represents a single rhythm cycle (e.g., "Teentaal" or "Jhaptal")
/// Derived from: Taal.csv
struct TaalDefinition: Identifiable {
    let id = UUID()
    let name: String            // Taal.csv: `taalName`
    let displayName: String     // Taal.csv: `taalDisplayName`
    let matras: Double          // Taal.csv: `matras` (Total beats in cycle)
    let taaliMatras: [Int]      // Parsed from `taaliMatras` string (e.g., "1,5,13" -> [1, 5, 13])
    let khaaliMatras: [Int]     // Parsed from `khaaliMatras` string (e.g., "9" -> [9])
    let forceSur: Bool          // If it's a Pakhawaj taal, force Sur tabla
    
    // The dictionary holds every style variation for THIS specific Taal.
    // Key: `styleNum` (e.g., 1 for Pro Default, 2 for Variation 1)
    // Value: The full timeline sequence for that variation.
    var variations: [String: TablaStyleVariation] = [:]
}

// MARK: - 2. The Variation/Style Container
/// Represents a specific played variation (e.g., "Variation #1" vs "Pro Default")
struct TablaStyleVariation: Identifiable {
    let id: Int                 // TaalBols.csv: `styleNum`
    let name: String            // TaalBols.csv: `style`
    var allowedTempos: Set<Int> = [] // Unique tempo tier indices present (e.g. 0, 1, 2)
    
    // Key: Tempo Tier Index (0..4) -> Value: Array of ordered events for that tier
    var timelinesByTempoTier: [Int: [TablaStrokeEvent]] = [:]
}

// MARK: - 3. The Atomic Audio Trigger
/// Represents a single millisecond of action for the engine.
/// Derived from: TaalBols.csv rows
struct TablaStrokeEvent: Identifiable {
    let id = UUID()
    let seqNum: Int             // The order in the sequence (1, 2, 3...)
    let matra: Int              // The beat index this stroke falls inside
    let durationFraction: Double // How long this stroke lasts (e.g., 1.0, 0.5, 0.25)
    
    let leftSampleName: String?  // e.g., "Ge-OP"
    let rightSampleName: String? // e.g., "Ti"
    
    let leftVolume: Float        // e.g., 1.0
    let rightVolume: Float       // e.g., 1.0
    
    let bolName: String?         // The phonetic name (e.g., "Dha", "TiTa")
}

class TablaDatabase {
    // Master Dictionary: Quick lookup by Taal Name (e.g., "Teentaal")
    private(set) var taalCatalog: [String: TaalDefinition] = [:]
    
    init() {
        loadDatabase()
    }
    
    private func loadDatabase() {
        do {
            try parseTaalMetadata()
            try parseTaalBolsTimeline()
            print("✅ Tabla Database Built. Loaded \(taalCatalog.count) distinct Taals.")
        } catch {
            print("❌ Critical Error loading CSVs: \(error)")
        }
    }
    
    // MARK: - Parse Taal.csv
    private func parseTaalMetadata() throws {
        guard let url = Bundle.main.url(forResource: "Taal", withExtension: "csv") else {
            print("❌ Error: Could not find Taal.csv")
            return
        }
        
        // SwiftCSV automatically parses the headers and handles quoted commas flawlessly
        let csv = try CSV<Named>(url: url)
        
        // Helper function safely processes optionals now
        let parseMatraList: (String?) -> [Int] = { str in
            guard let str = str, !str.isEmpty else { return [] }
            return str.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        for row in csv.rows {
            // Safe unwrap using exact column names from your Python dump
            guard let name = row["taalName"]?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            
            let rawDisplayName = row["taalDisplayName"]?.trimmingCharacters(in: .whitespaces) ?? ""
            let displayName = rawDisplayName.isEmpty ? name : rawDisplayName
            
            let matras = Double(row["matras"] ?? "0") ?? 0.0
            let taali = parseMatraList(row["taaliMatras"])
            let khaali = parseMatraList(row["khaaliMatras"])
            
            let isPakhawaj = row["pakhawajTaal"] == "1" ? true : false
            
            taalCatalog[name] = TaalDefinition(
                name: name,
                displayName: displayName,
                matras: matras,
                taaliMatras: taali,
                khaaliMatras: khaali,
                forceSur: isPakhawaj
            )
        }
    }
    
    // MARK: - Parse TaalBols.csv
    private func parseTempoTiers(from rawTempos: String) -> [Int] {
        let cleaned = rawTempos.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
        
        // Skip 55 and -99 rows as requested (testing/non-production rows)
        if cleaned == "55" || cleaned == "-99" {
            return []
        }
        
        return cleaned.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 0 && $0 <= 4 }
    }

    private func parseTaalBolsTimeline() throws {
        guard let url = Bundle.main.url(forResource: "TaalBols", withExtension: "csv") else {
            print("❌ Error: Could not find TaalBols.csv")
            return
        }
        
        let csv = try CSV<Named>(url: url)
        
        for row in csv.rows {
            guard let taalName = row["taalName"]?.trimmingCharacters(in: .whitespaces),
                  taalCatalog[taalName] != nil else { continue }
            
            let temposString = row["tempos"] ?? ""
            let validTiers = parseTempoTiers(from: temposString)
            
            // Skip rows marked 55, -99, or invalid
            if validTiers.isEmpty { continue }
            
            let styleNum = Int(row["styleNum"] ?? "1") ?? 1
            let styleName = row["style"]?.trimmingCharacters(in: .whitespaces) ?? "Default"

            // 1. Initialize variation safely if it doesn't exist
            if taalCatalog[taalName]?.variations[styleName] == nil {
                taalCatalog[taalName]?.variations[styleName] = TablaStyleVariation(
                    id: styleNum,
                    name: styleName
                )
            }
            
            let seqNum = Int(row["seqNum"] ?? "0") ?? 0
            let matra = Int(row["matra"] ?? "0") ?? 0
            let totalDuration = Double(row["numBeats"] ?? "1.0") ?? 1.0
            
            let leftSample = row["bolLeft"]?.trimmingCharacters(in: .whitespaces)
            let rightSample = row["bolRight"]?.trimmingCharacters(in: .whitespaces)
            
            let leftVol = Float(row["volLeft"] ?? "1.0") ?? 1.0
            let rightVol = Float(row["volRight"] ?? "1.0") ?? 1.0
            let originalBolName = row["bolName"]
            
            // Check if right or left sample is a compound bol registered in tuning map
            let targetKey = rightSample ?? leftSample ?? ""
            
            if let recipe = compoundBolTuningMap[targetKey] {
                // Event 1 (First sub-stroke)
                let event1 = TablaStrokeEvent(
                    seqNum: seqNum,
                    matra: matra,
                    durationFraction: totalDuration * recipe.ratio1,
                    leftSampleName: recipe.left1,
                    rightSampleName: recipe.right1,
                    leftVolume: leftVol,
                    rightVolume: rightVol,
                    bolName: originalBolName // Keeps original compound name for UI!
                )
                
                // Event 2 (Second sub-stroke)
                let event2 = TablaStrokeEvent(
                    seqNum: seqNum,
                    matra: matra,
                    durationFraction: totalDuration * recipe.ratio2,
                    leftSampleName: recipe.left2,
                    rightSampleName: recipe.right2,
                    leftVolume: leftVol,
                    rightVolume: rightVol,
                    bolName: nil // Prevents duplicate UI label
                )
                
                for tempoTier in validTiers {
                    taalCatalog[taalName]?.variations[styleName]?.allowedTempos.insert(tempoTier)
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event1)
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event2)
                }
            } else {
                // Standard single-stroke event
                let event = TablaStrokeEvent(
                    seqNum: seqNum,
                    matra: matra,
                    durationFraction: totalDuration,
                    leftSampleName: (leftSample == nil || leftSample!.isEmpty) ? nil : leftSample,
                    rightSampleName: (rightSample == nil || rightSample!.isEmpty) ? nil : rightSample,
                    leftVolume: leftVol,
                    rightVolume: rightVol,
                    bolName: originalBolName
                )
                
                for tempoTier in validTiers {
                    taalCatalog[taalName]?.variations[styleName]?.allowedTempos.insert(tempoTier)
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event)
                }
            }
        }
        
        // 3. Final Pass: Sort each tier's timeline perfectly by sequence number
        for (taalName, _) in taalCatalog {
            for (styleName, variation) in taalCatalog[taalName]!.variations {
                for (tier, timeline) in variation.timelinesByTempoTier {
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tier] = timeline.sorted(by: { $0.seqNum < $1.seqNum })
                }
            }
        }
    }
    
    func getVariationNames(taal: String) -> [String] {
        return Array(taalCatalog[taal]!.variations.keys)
    }
}
