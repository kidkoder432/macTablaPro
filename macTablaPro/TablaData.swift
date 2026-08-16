import Foundation
import SwiftCSV

// MARK: - Compound Bol Sub-Stroke Tuning Map
nonisolated struct SubStrokeRecipe: Sendable {
    let ratio1: Double
    let left1: String?
    let right1: String?
    let ratio2: Double
    let left2: String?
    let right2: String?
    let fixedDelaySec: Double?

    init(
        ratio1: Double,
        left1: String?,
        right1: String?,
        ratio2: Double,
        left2: String?,
        right2: String?,
        fixedDelaySec: Double? = nil
    ) {
        self.ratio1 = ratio1
        self.left1 = left1
        self.right1 = right1
        self.ratio2 = ratio2
        self.left2 = left2
        self.right2 = right2
        self.fixedDelaySec = fixedDelaySec
    }
}

/// Declarative Tuning Map for Compound Tabla Bols
/// Key: Compound bol string from CSV (e.g. "KDa", "TaKa", "NaKa", "Tra", "TiTaL")
/// Value: Recipe specifying duration split ratios or fixed physical delay (in seconds) for ornaments.
nonisolated let compoundBolTuningMap: [String: SubStrokeRecipe] = [
    "KDa": SubStrokeRecipe(
        ratio1: 0.0, left1: "Ka", right1: nil,
        ratio2: 1.0, left2: nil, right2: "TTaL",
        fixedDelaySec: 0.0625
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
        ratio1: 0.0, left1: nil, right1: "Ti",
        ratio2: 1.0, left2: nil, right2: "Ra",
        fixedDelaySec: 0.05
    ),
    "TiTaL": SubStrokeRecipe(
        ratio1: 0.50, left1: nil, right1: "TiL",
        ratio2: 0.50, left2: nil, right2: "TTaL"
    ),
    "Ge-S": SubStrokeRecipe(
        ratio1: 2/3, left1: "Ge-B", right1: nil,
        ratio2: 1/3, left2: "Ge-T60", right2: nil
    )
]

// MARK: - 1. Taal Core Metadata
/// Represents a single rhythm cycle (e.g., "Teentaal" or "Jhaptal")
/// Derived from: Taal.csv
nonisolated struct TaalDefinition: Identifiable, Sendable {
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
    /// Preserves original CSV dataset insertion order for style variations.
    var orderedVariationNames: [String] = []
}

// MARK: - 2. The Variation/Style Container
/// Represents a specific played variation (e.g., "Variation #1" vs "Pro Default")
nonisolated struct TablaStyleVariation: Identifiable, Sendable {
    let id: Int                 // TaalBols.csv: `styleNum`
    let name: String            // TaalBols.csv: `style`
    var allowedTempos: Set<Int> = [] // Unique tempo tier indices present (e.g. 0, 1, 2)
    
    // Key: `tempoTier` (0: Ati-Vilambit, 1: Vilambit, 55: Vilambit Fine, 2: Madhya, 3: Drut, 4: Ati-Drut)
    // Value: Sorted array of atomic stroke events for THIS specific speed tier.
    var timelinesByTempoTier: [Int: [TablaStrokeEvent]] = [:]
}

// MARK: - 3. The Atomic Audio Trigger
/// Represents a single millisecond of action for the engine.
/// Derived from: TaalBols.csv rows
nonisolated struct TablaStrokeEvent: Identifiable, Sendable {
    let id = UUID()
    let seqNum: Int             // The order in the sequence (1, 2, 3...)
    let matra: Int              // The beat index this stroke falls inside
    let startBeatFraction: Double // Absolute beat timestamp relative to Sam (e.g. 0.0, 0.25, 0.5)
    let durationFraction: Double // How long this stroke lasts (e.g., 1.0, 0.5, 0.25)
    
    let leftSampleName: String?  // e.g., "Ge-OP"
    let rightSampleName: String? // e.g., "Ti"
    
    let leftVolume: Float        // e.g., 1.0
    let rightVolume: Float       // e.g., 1.0
    
    let bolName: String?         // The phonetic name (e.g., "Dha", "TiTa")

    // Fixed physical delay secondary ornament (e.g. KDa, Tra flams)
    let secondaryDelaySec: Double?
    let secondaryLeftSample: String?
    let secondaryRightSample: String?

    init(
        seqNum: Int,
        matra: Int,
        startBeatFraction: Double,
        durationFraction: Double,
        leftSampleName: String?,
        rightSampleName: String?,
        leftVolume: Float,
        rightVolume: Float,
        bolName: String?,
        secondaryDelaySec: Double? = nil,
        secondaryLeftSample: String? = nil,
        secondaryRightSample: String? = nil
    ) {
        self.seqNum = seqNum
        self.matra = matra
        self.startBeatFraction = startBeatFraction
        self.durationFraction = durationFraction
        self.leftSampleName = leftSampleName
        self.rightSampleName = rightSampleName
        self.leftVolume = leftVolume
        self.rightVolume = rightVolume
        self.bolName = bolName
        self.secondaryDelaySec = secondaryDelaySec
        self.secondaryLeftSample = secondaryLeftSample
        self.secondaryRightSample = secondaryRightSample
    }
}

nonisolated final class TablaDatabase: @unchecked Sendable {
    nonisolated static let shared = TablaDatabase()
    
    // Master Dictionary: Quick lookup by Taal Name (e.g., "Teentaal")
    nonisolated(unsafe) private(set) var taalCatalog: [String: TaalDefinition] = [:]
    
    init() {
        loadDatabase()
    }
    
    private func loadDatabase() {
        do {
            try parseTaalMetadata()
            try parseTaalBolsTimeline()
        } catch {
            print("❌ Failed to parse Tabla databases: \(error)")
        }
    }
    
    // MARK: - Parse Taal.csv
    private func parseMatraList(_ rawString: String?) -> [Int] {
        guard let raw = rawString?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return [] }
        return raw.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private func parseTaalMetadata() throws {
        guard let url = Bundle.main.url(forResource: "Taal", withExtension: "csv") else {
            print("❌ Error: Could not find Taal.csv")
            return
        }
        
        // SwiftCSV automatically parses the headers and handles quoted commas flawlessly
        let csv = try CSV<Named>(url: url)
        
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
        
        // Skip -99 dummy / non-production rows
        if cleaned == "-99" {
            return []
        }
        
        return cleaned.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { ($0 >= 0 && $0 <= 4) || $0 == 55 }
    }

    private func parseTaalBolsTimeline() throws {
        guard let url = Bundle.main.url(forResource: "TaalBols", withExtension: "csv") else {
            print("❌ Error: Could not find TaalBols.csv")
            return
        }
        
        let csv = try CSV<Named>(url: url)
        
        // Dictionary tracking running beat position per timeline key (e.g. "Teentaal_Default_0")
        var accumulatedBeats: [String: Double] = [:]
        
        for row in csv.rows {
            guard let taalName = row["taalName"]?.trimmingCharacters(in: .whitespaces),
                  taalCatalog[taalName] != nil else { continue }
            
            let temposString = row["tempos"] ?? ""
            let validTiers = parseTempoTiers(from: temposString)
            
            // Skip invalid rows
            if validTiers.isEmpty { continue }
            
            let styleNum = Int(row["styleNum"] ?? "1") ?? 1
            let styleName = row["style"]?.trimmingCharacters(in: .whitespaces) ?? "Default"

            // 1. Initialize variation safely if it doesn't exist
            if taalCatalog[taalName]?.variations[styleName] == nil {
                taalCatalog[taalName]?.variations[styleName] = TablaStyleVariation(
                    id: styleNum,
                    name: styleName
                )
                taalCatalog[taalName]?.orderedVariationNames.append(styleName)
            }
            
            let seqNum = Int(row["seqNum"] ?? "0") ?? 0
            let matra = Int(row["matra"] ?? "0") ?? 0
            let totalDuration = Double(row["numBeats"] ?? "1.0") ?? 1.0
            
            let leftSample = row["bolLeft"]?.trimmingCharacters(in: .whitespaces)
            let rightSample = row["bolRight"]?.trimmingCharacters(in: .whitespaces)
            
            let leftVol = Float(row["volLeft"] ?? "1.0") ?? 1.0
            let rightVol = Float(row["volRight"] ?? "1.0") ?? 1.0
            let originalBolName = row["bolName"]
            
            var recipe: SubStrokeRecipe? = nil
            var recipeKey: String? = nil
            
            if let left = leftSample, !left.isEmpty, let r = compoundBolTuningMap[left] {
                recipe = r
                recipeKey = left
            } else if let right = rightSample, !right.isEmpty, let r = compoundBolTuningMap[right] {
                recipe = r
                recipeKey = right
            }
            
            // Calculate starting beat fraction for this CSV row
            let firstTier = validTiers[0]
            let firstKey = "\(taalName)_\(styleName)_\(firstTier)"
            let rowStartBeat = accumulatedBeats[firstKey] ?? max(0.0, Double(matra - 1))
            
            if let recipe = recipe {
                let effectiveLeft1 = recipe.left1 ?? (leftSample != recipeKey && leftSample?.isEmpty == false ? leftSample : nil)
                let effectiveRight1 = recipe.right1 ?? (rightSample != recipeKey && rightSample?.isEmpty == false ? rightSample : nil)

                if let fixedDelay = recipe.fixedDelaySec {
                    // Single atomic event with fixed-delay secondary stroke (e.g. KDa, Tra flams)
                    let event = TablaStrokeEvent(
                        seqNum: seqNum,
                        matra: matra,
                        startBeatFraction: rowStartBeat,
                        durationFraction: totalDuration,
                        leftSampleName: effectiveLeft1,
                        rightSampleName: effectiveRight1,
                        leftVolume: leftVol,
                        rightVolume: rightVol,
                        bolName: originalBolName,
                        secondaryDelaySec: fixedDelay,
                        secondaryLeftSample: recipe.left2,
                        secondaryRightSample: recipe.right2
                    )

                    for tempoTier in validTiers {
                        let timelineKey = "\(taalName)_\(styleName)_\(tempoTier)"
                        taalCatalog[taalName]?.variations[styleName]?.allowedTempos.insert(tempoTier)
                        taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event)
                        accumulatedBeats[timelineKey] = rowStartBeat + totalDuration
                    }
                } else {
                    // Rhythmic beat-fraction split (e.g. TaKa, NaKa, TiTaL)
                    let duration1 = totalDuration * recipe.ratio1
                    let duration2 = totalDuration * recipe.ratio2

                    let event1 = TablaStrokeEvent(
                        seqNum: seqNum,
                        matra: matra,
                        startBeatFraction: rowStartBeat,
                        durationFraction: duration1,
                        leftSampleName: effectiveLeft1,
                        rightSampleName: effectiveRight1,
                        leftVolume: leftVol,
                        rightVolume: rightVol,
                        bolName: originalBolName
                    )

                    let event2 = TablaStrokeEvent(
                        seqNum: seqNum,
                        matra: matra,
                        startBeatFraction: rowStartBeat + duration1,
                        durationFraction: duration2,
                        leftSampleName: recipe.left2,
                        rightSampleName: recipe.right2,
                        leftVolume: leftVol,
                        rightVolume: rightVol,
                        bolName: nil
                    )

                    for tempoTier in validTiers {
                        let timelineKey = "\(taalName)_\(styleName)_\(tempoTier)"
                        taalCatalog[taalName]?.variations[styleName]?.allowedTempos.insert(tempoTier)
                        taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event1)
                        taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event2)
                        accumulatedBeats[timelineKey] = rowStartBeat + totalDuration
                    }
                }
            } else {
                let event = TablaStrokeEvent(
                    seqNum: seqNum,
                    matra: matra,
                    startBeatFraction: rowStartBeat,
                    durationFraction: totalDuration,
                    leftSampleName: (leftSample == nil || leftSample!.isEmpty) ? nil : leftSample,
                    rightSampleName: (rightSample == nil || rightSample!.isEmpty) ? nil : rightSample,
                    leftVolume: leftVol,
                    rightVolume: rightVol,
                    bolName: originalBolName
                )
                
                for tempoTier in validTiers {
                    let timelineKey = "\(taalName)_\(styleName)_\(tempoTier)"
                    taalCatalog[taalName]?.variations[styleName]?.allowedTempos.insert(tempoTier)
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tempoTier, default: []].append(event)
                    accumulatedBeats[timelineKey] = rowStartBeat + totalDuration
                }
            }
        }
        
        // 3. Final Pass: Sort each tier's timeline perfectly by startBeatFraction
        for (taalName, _) in taalCatalog {
            for (styleName, variation) in taalCatalog[taalName]!.variations {
                for (tier, timeline) in variation.timelinesByTempoTier {
                    taalCatalog[taalName]?.variations[styleName]?.timelinesByTempoTier[tier] = timeline.sorted(by: { $0.startBeatFraction < $1.startBeatFraction })
                }
            }
        }
    }
    
    func getVariationNames(taal: String) -> [String] {
        return Array(taalCatalog[taal]!.variations.keys)
    }
}
