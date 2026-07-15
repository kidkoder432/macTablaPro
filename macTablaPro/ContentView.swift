import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioEngine()
    
    // UI State mapped to the audio engine properties
    @State private var pitchOffset: Double = 0.0
    @State private var tempo: Double = 120.0
    @State private var firstString: Int = 0 // 0 = Pa, 1 = Ni
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Tanpura and Tabla App")
                .font(.largeTitle)
                .bold()
            
            Button(action: {
                audio.togglePlay()
            }) {
                Text(audio.isPlaying ? "Stop" : "Play")
                    .font(.title2)
                    .frame(width: 140, height: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(audio.isPlaying ? .red : .blue)
            
            // First String Picker
            Picker("First String", selection: $firstString) {
                Text("Pancham (Pa)").tag(0)
                Text("Nishad (Ni)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .onChange(of: firstString) { newValue in
                audio.firstStringIsPa = (newValue == 0)
            }
            
            // Pitch Slider
            VStack(spacing: 5) {
                Text(getNoteName(offset: pitchOffset))
                    .font(.headline)
                    .monospacedDigit()
                
                Slider(value: $pitchOffset, in: -4...15, step: 1.0)
                    .onChange(of: pitchOffset) { newValue in
                        audio.pitchOffset = newValue
                    }
                    .padding(.horizontal, 40)
            }
            
            // Tempo Slider
            VStack(spacing: 5) {
                Text(String(format: "Tempo: %.0f BPM", tempo))
                    .font(.headline)
                    .monospacedDigit()
                
                Slider(value: $tempo, in: 60...240, step: 1.0)
                    .onChange(of: tempo) { newValue in
                        audio.tempo = newValue
                    }
                    .padding(.horizontal, 40)
            }
        }
        .frame(width: 400, height: 400)
    }
    
    func getNoteName(offset: Double) -> String {
        let notes = ["A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4"]
        let baseIndex = 4 // C#3
        let currentIndex = baseIndex + Int(offset)
        return "Pitch: \(notes[currentIndex])"
    }
}
