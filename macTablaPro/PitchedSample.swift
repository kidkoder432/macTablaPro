import Foundation
import AVFoundation
import Combine

/*
 
 Pitches for detuned playback must be relative to C3.
 
 */

enum BufferError: Error {
    case e(String)
}

nonisolated final class PitchedSample: @unchecked Sendable {
    var fileName: String
    var absolutePitch: Double
    var role = ""
    
    var isLoaded: Bool
    var buffer: AVAudioPCMBuffer?
    /// Holds the currently active resampled buffer matching the active pitch selection.
    var resampledBuffer: AVAudioPCMBuffer?
    var resampledPitch: Double
    
    
    init(fileName: String, pitch: Double, role: String = "") {
        self.fileName = fileName
        self.buffer = nil
        self.isLoaded = false
        self.absolutePitch = pitch
        self.role = role
        
        self.resampledBuffer = nil
        self.resampledPitch = pitch
        
    }
    
    func getFileName() -> String {
        return fileName
    }

    func setFileName(fileName: String) {
        self.fileName = fileName
    }
    
    func ensureBuffer() throws {
        if !isLoaded {
            throw BufferError.e("Buffer not loaded")
        }
    }
    
    func load() {
        // 1. Locate the file path inside the app package
        guard let fileURL = Bundle.main.url(forResource: self.fileName, withExtension: "wav") else {
            print("Error: Could not find file named \(self.fileName).wav")
            return
        }
        
        do {
            // 2. Open the file to read its format metadata
            let file = try AVAudioFile(forReading: fileURL)
            
            // 3. Allocate physical RAM matching the file's format and length
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                print("Error: Failed to allocate RAM buffer for \(self.fileName)")
                return
            }
            
            // 4. Stream the raw audio data from the SSD into the allocated RAM
            try file.read(into: buffer)
            self.buffer = buffer
            self.resampledBuffer = buffer
            
        } catch {
            print("Error reading audio file: \(error)")
        }
    }
    
    func getFormat() -> AVAudioFormat? {
        try! ensureBuffer();
        return self.buffer!.format
    }
    
}
