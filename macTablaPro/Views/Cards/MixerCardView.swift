import SwiftUI

// MARK: - Dedicated Mixer Hub Card View
struct MixerCardView: View {
    @ObservedObject var audio: AppAudioOrchestrator

    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(spacing: 16) {
            // Header with Master Play/Stop Transport Button
            HStack {
                Text("Master Mixer")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
                
                Button(action: { audio.toggleMasterTransport() }) {
                    HStack(spacing: 4) {
                        Image(systemName: audio.isAnyInstrumentPlaying ? "square.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(audio.isAnyInstrumentPlaying ? "Stop All" : "Play All")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(CustomTagButtonStyle(isSelected: audio.isAnyInstrumentPlaying, isAntique: isAntique))
            }

            // System Master Volume Controller
            VStack(spacing: 6) {
                HStack {
                    Text("Master Volume")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Spacer()
                    Text("\(Int(audio.masterVolume * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(isAntique ? Color.yellow : .secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").font(.caption).foregroundColor(isAntique ? Color.orange : .secondary)
                    Slider(value: $audio.masterVolume, in: 0.0...1.0) { isEditing in
                        if !isEditing {
                            let snapshot = audio.capturePreset()
                            Task.detached(priority: .utility) {
                                await SettingsStorageService.shared.saveActiveSettings(snapshot)
                            }
                        }
                    }
                    .tint(isAntique ? .orange : .accentColor)
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundColor(isAntique ? Color.orange : .secondary)
                }
            }
            .padding(10)
            .background(isAntique ? Color.black.opacity(0.2) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()

            VStack(spacing: 14) {
                if let tanpura1 = audio.tanpura1 {
                    MixerChannelRow(name: "Tanpura 1", instrument: tanpura1, isAntique: isAntique)
                }
                
                if let tanpura2 = audio.tanpura2 {
                    MixerChannelRow(name: "Tanpura 2", instrument: tanpura2, isAntique: isAntique)
                }

                if let tabla = audio.tabla {
                    MixerChannelRow(name: "Tabla", instrument: tabla, isAntique: isAntique)
                }
                
                if let swarMandal = audio.swarMandal {
                    MixerChannelRow(name: "Swar Mandal", instrument: swarMandal, isAntique: isAntique)
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }
}

// Extracted channel strip row with strictly-scoped @ObservedObject bindings
struct MixerChannelRow: View {
    let name: String
    @ObservedObject var instrument: Instrument
    var isAntique: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { instrument.togglePlay() }) {
                Text(name)
                    .font(isAntique ? .custom("Baskerville-Italic", size: 14).weight(.semibold) : .caption)
                    .frame(width: 70, alignment: .leading)
            }
            .buttonStyle(CustomTagButtonStyle(isSelected: instrument.isPlaying, isAntique: isAntique))

            // Mute Toggle Button
            Button(action: { instrument.isMuted.toggle() }) {
                Image(systemName: instrument.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(instrument.isMuted ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(instrument.isMuted ? "Unmute channel" : "Mute channel")

            // Volume Slider
            Slider(value: $instrument.volume, in: 0.0...1.0) { isEditing in
                if !isEditing {
                    let snapshot = instrument.orchestrator.capturePreset()
                    Task.detached(priority: .utility) {
                        await SettingsStorageService.shared.saveActiveSettings(snapshot)
                    }
                }
            }
            .tint((instrument.isPlaying && !instrument.isMuted) ? .accentColor : .gray)
        }
    }
}
