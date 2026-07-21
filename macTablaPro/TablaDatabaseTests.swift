import XCTest
import AVFoundation

@testable import macTablaPro

final class TablaDatabaseTests: XCTestCase {

    var database: TablaDatabase!
    var allWavFileNames: Set<String> = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = TablaDatabase()

        // Gather all WAV file names available in the main bundle
        let wavURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        allWavFileNames = Set(wavURLs.map { $0.deletingPathExtension().lastPathComponent })
    }

    override func tearDownWithError() throws {
        database = nil
        allWavFileNames.removeAll()
        try super.tearDownWithError()
    }

    // MARK: - 1. Database Parsing & Catalog Integrity
    func testDatabaseCatalogIntegrity() throws {
        XCTAssertFalse(database.taalCatalog.isEmpty, "❌ TablaDatabase failed to load any Taals.")

        for (taalName, taalDef) in database.taalCatalog {
            XCTAssertGreaterThan(taalDef.matras, 0, "❌ Taal '\(taalName)' has invalid matras count: \(taalDef.matras)")
            XCTAssertFalse(taalDef.variations.isEmpty, "❌ Taal '\(taalName)' contains 0 style variations.")

            for (styleName, variation) in taalDef.variations {
                XCTAssertFalse(variation.timelinesByTempoTier.isEmpty, "❌ Variation '\(styleName)' in Taal '\(taalName)' has no tempo tier timelines.")
            }
        }
    }

    // MARK: - 2. Sample Asset Resolution Coverage (Batched Report)
    func testSampleRegistryAssetCoverage() throws {
        var missingAssets: [String] = []
        var totalEventsTested = 0

        for (taalName, taalDef) in database.taalCatalog {
            for (styleName, variation) in taalDef.variations {
                for (tierIndex, timeline) in variation.timelinesByTempoTier {
                    for event in timeline {
                        totalEventsTested += 1

                        // Test Bayan (Left hand)
                        if let left = event.leftSampleName {
                            let leftKey = "Bayaan_" + left
                            if !allWavFileNames.contains(leftKey) {
                                missingAssets.append("Missing Left Sample: '\(leftKey)' [Taal: \(taalName), Style: \(styleName), Tier: \(tierIndex), Matra: \(event.matra)]")
                            }
                        }

                        // Test Dayan (Right hand) - Check default pitch C#
                        if let right = event.rightSampleName {
                            let rightKeySur = "Dayaan_C#_Sur_" + right
                            let rightKeyTip = "Dayaan_C#_Tip_" + right
                            
                            if !allWavFileNames.contains(rightKeySur) && !allWavFileNames.contains(rightKeyTip) && !allWavFileNames.contains("Dayaan_C#_" + right) {
                                missingAssets.append("Missing Right Sample: '\(rightKeyTip)' or '\(rightKeySur)' [Taal: \(taalName), Style: \(styleName), Tier: \(tierIndex), Matra: \(event.matra)]")
                            }
                        }
                    }
                }
            }
        }

        print("📊 Tested \(totalEventsTested) stroke events across all Taals & Variations.")

        if !missingAssets.isEmpty {
            let failureReport = missingAssets.joined(separator: "\n")
            XCTFail("❌ Found \(missingAssets.count) missing audio assets out of \(totalEventsTested) events:\n\(failureReport)")
        }
    }

    // MARK: - 3. Manifest Isolation & Pitch Integrity
    
    func testTanpuraManifestIsolationAndPitchIntegrity() throws {
        // Ensure tablaManifest does not ingest Tanpura samples
        let tablaSampleNames = tablaManifest.map { $0.fileName }
        for sample in tanpuraManifest {
            XCTAssertFalse(tablaSampleNames.contains(sample.fileName), "❌ tablaManifest ingested Tanpura asset: \(sample.fileName)")
        }
        
        // Verify Tanpura sample absolute pitches
        guard let paSample = tanpuraManifest.first(where: { $0.fileName == "Tanpura_C#3_Pa" }) else {
            XCTFail("❌ Tanpura_C#3_Pa missing from tanpuraManifest")
            return
        }
        XCTAssertEqual(paSample.absolutePitch, 800.0, "❌ Tanpura_C#3_Pa pitch corrupted")

        guard let saSample = tanpuraManifest.first(where: { $0.fileName == "Tanpura_C#3_Sa" }) else {
            XCTFail("❌ Tanpura_C#3_Sa missing from tanpuraManifest")
            return
        }
        XCTAssertEqual(saSample.absolutePitch, 1300.0, "❌ Tanpura_C#3_Sa pitch corrupted")
    }

    // MARK: - 4. DSP Varispeed Latency and Timing Diagnostics
    
    func testVarispeedLatencyDiagnostics() throws {
        let engine = AVAudioEngine()
        let varispeedNode = AVAudioUnitVarispeed()
        engine.attach(varispeedNode)
        
        print("\n=== 📊 AVAudioUnitVarispeed Latency Profile ===")
        let rates: [Float] = [1.0, 1.05946, 1.25, 1.5, 1.5874, 2.0]
        for rate in rates {
            varispeedNode.rate = rate
            // Read latency in seconds
            let latencySec = varispeedNode.latency
            let latencyMs = latencySec * 1000.0
            print("Rate: \(String(format: "%.5f", rate)) | Latency: \(String(format: "%.6f", latencySec))s (\(String(format: "%.3f", latencyMs))ms)")
        }
        print("============================================\n")
        
        print("=== ⏱️ Sequential Playback Trigger Overhead ===")
        // Measure execution time gap between triggering two player nodes sequentially
        let player1 = AVAudioPlayerNode()
        let player2 = AVAudioPlayerNode()
        engine.attach(player1)
        engine.attach(player2)
        
        let startHost = mach_absolute_time()
        player1.play()
        let player1TriggeredHost = mach_absolute_time()
        player2.play()
        let player2TriggeredHost = mach_absolute_time()
        
        let info = try XCTUnwrap(Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil)).isEmpty ? mach_timebase_info() : mach_timebase_info()
        var timebase = info
        mach_timebase_info(&timebase)
        
        let gapTicks = player2TriggeredHost - player1TriggeredHost
        let gapNs = Double(gapTicks) * Double(timebase.numer) / Double(timebase.denom)
        let gapMs = gapNs / 1e6
        print("Sequential play() gap: \(String(format: "%.6f", gapMs))ms")
        print("==============================================\n")
        
        // Formats check
        print("=== 📁 Bundle Audio Asset Formats ===")
        let wavURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        for url in wavURLs.prefix(5) {
            if let file = try? AVAudioFile(forReading: url) {
                print("File: \(url.lastPathComponent) | Format: \(file.fileFormat.sampleRate)Hz, \(file.fileFormat.channelCount)ch, FormatID: \(file.fileFormat.commonFormat.rawValue)")
            }
        }
        print("======================================\n")
        
        XCTAssert(true)
    }

    func testCustomStateAssertionsStub() throws {
        // Implement your custom domain assertions here
        XCTAssertTrue(true)
    }
}
