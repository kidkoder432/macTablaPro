import SwiftUI
import AppKit

// MARK: - Tuner Cents Needle Gauge Component
struct TunerNeedleGaugeView: View {
    let cents: Double          // Range -50 ... +50
    let isSignalDetected: Bool
    let isAntique: Bool

    // Gauge geometry constants
    private let maxAngle: Double = 50.0 // +/- 50 degrees

    var needleColor: Color {
        guard isSignalDetected else { return .secondary.opacity(0.4) }
        let absCents = abs(cents)
        if absCents <= 3.0 {
            return .green
        } else if absCents <= 15.0 {
            return .yellow
        } else {
            return isAntique ? .orange : .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Gauge Arc & Tick Marks
                GaugeArcShape()
                    .stroke(
                        Color.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(height: 70)

                // Colored Center "In-Tune" Notch
                Rectangle()
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 3, height: 16)
                    .offset(y: -26)

                // Intermediate Tick Marks (-25, +25)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 1.5, height: 10)
                    .offset(y: -26)
                    .rotationEffect(.degrees(-25))

                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 1.5, height: 10)
                    .offset(y: -26)
                    .rotationEffect(.degrees(25))

                // The Precision Needle
                if isSignalDetected {
                    NeedleShape()
                        .fill(needleColor)
                        .frame(width: 4, height: 50)
                        .offset(y: -20)
                        .rotationEffect(.degrees(min(maxAngle, max(-maxAngle, cents))))
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.85), value: cents)
                        .shadow(color: needleColor.opacity(0.6), radius: 4)
                }

                // Center Pivot Knob
                Circle()
                    .fill(isAntique ? Color.orange : Color.accentColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    .offset(y: 10)
            }
            .frame(height: 75)

            // Tick Mark Labels: -50¢, -25¢, 0, +25¢, +50¢
            HStack {
                Text("-50¢").font(.system(size: 10, weight: .semibold, design: .monospaced))
                Spacer()
                Text("-25¢").font(.system(size: 9, weight: .regular, design: .monospaced))
                Spacer()
                Text("0¢").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.green)
                Spacer()
                Text("+25¢").font(.system(size: 9, weight: .regular, design: .monospaced))
                Spacer()
                Text("+50¢").font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Gauge Helper Shapes
struct GaugeArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY - 10)
        let radius: CGFloat = 55
        path.addArc(center: center, radius: radius, startAngle: .degrees(180 + 35), endAngle: .degrees(360 - 35), clockwise: false)
        return path
    }
}

struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Root Tuner Drawer / Popover View
struct TunerDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @StateObject private var tuner = TunerService()
    @State private var showCapturedFeedback = false

    var isAntique: Bool { audio.isAntiqueThemeEnabled }

    var currentTanpuraDisplay: NoteDisplayData {
        let baseIndex = 3 // C3 is index 3
        let semitoneOffset = Int(audio.scaleOffsetCents / 100.0)
        let currentIndex = baseIndex + semitoneOffset

        guard currentIndex >= 0 && currentIndex < TunerService.allNoteNames.count else {
            return NoteDisplayData(noteName: "---", fineCentsString: nil)
        }

        var fineString: String? = nil
        if audio.fineTuneCents != 0 {
            let sign = audio.fineTuneCents > 0 ? "+" : ""
            fineString = "\(sign)\(Int(audio.fineTuneCents))¢"
        }
        return NoteDisplayData(noteName: TunerService.allNoteNames[currentIndex], fineCentsString: fineString)
    }

    var effectiveMicPitch: (noteName: String, scaleOffset: Double, fineCents: Double, hz: Double)? {
        guard let detected = tuner.detectedPitch else { return nil }
        let targetMIDI = max(TunerService.minMIDINote, min(TunerService.maxMIDINote, detected.midiNoteNumber))

        let noteName = "\(TunerService.allNoteNames[targetMIDI - TunerService.minMIDINote])"
        let scaleOffset = Double((targetMIDI - TunerService.baseC3MIDI) * 100)
        let fineCents = tuner.smoothedCents
        let hz = detected.rawFrequencyHz

        return (noteName: noteName, scaleOffset: scaleOffset, fineCents: fineCents, hz: hz)
    }

    private func pitchColor(cents: Double, isAntique: Bool) -> Color {
        let absCents = abs(cents)
        if absCents <= 3.5 {
            return .green
        } else if absCents <= 15.0 {
            return isAntique ? Color.orange : Color.yellow
        } else {
            return isAntique ? Color.red.opacity(0.85) : Color.orange
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tuningfork")
                        .font(.title3)
                        .foregroundColor(isAntique ? Color.orange : Color.accentColor)

                    Text("Acoustic Instrument Tuner")
                        .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                        .foregroundColor(isAntique ? Color.orange : .primary)
                }

                Spacer()

                // Live Audio Activity Dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(tuner.isSignalDetected ? Color.green : (tuner.isListening ? Color.orange : Color.red))
                        .frame(width: 8, height: 8)
                        .shadow(color: (tuner.isSignalDetected ? Color.green : Color.orange).opacity(0.8), radius: 3)

                    Text(tuner.isSignalDetected ? "SIGNAL DETECTED" : (tuner.isListening ? "LISTENING..." : "MUTED"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        audio.isTunerPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !tuner.hasMicPermission {
                VStack(spacing: 8) {
                    Image(systemName: "mic.slash.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Microphone Access Required")
                        .font(.headline)
                    Text("Please enable Microphone permissions for macTablaPro in System Settings > Privacy & Security > Microphone.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // RMS Input Level Meter
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("MIC INPUT LEVEL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f dBFS", tuner.inputLevelDBFS))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .yellow, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(tuner.inputLevelRMS))
                                .animation(.linear(duration: 0.05), value: tuner.inputLevelRMS)
                        }
                    }
                    .frame(height: 6)
                }

                // Dual Pitch Display Box (Tanpura vs Captured Mic)
                HStack(spacing: 16) {
                    // Left: Current Master / Tanpura Target
                    VStack(spacing: 6) {
                        Text("CURRENT TANPURA")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        NativeDisplayBox(width: 140, height: 90, isAntique: isAntique) {
                            ZStack(alignment: .topLeading) {
                                Text(currentTanpuraDisplay.noteName)
                                    .font(isAntique ?
                                        .system(size: 42, weight: .bold, design: .monospaced) :
                                        .system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(isAntique ? Color.orange : .accentColor)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                if let centsText = currentTanpuraDisplay.fineCentsString {
                                    Text(centsText)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(isAntique ? Color.yellow : (audio.fineTuneCents > 0 ? Color.green : Color.orange))
                                        .padding([.top, .leading], 8)
                                }
                            }
                        }
                    }

                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    // Right: Detected Microphone Pitch
                    VStack(spacing: 6) {
                        Text("DETECTED ACOUSTIC PITCH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        NativeDisplayBox(width: 140, height: 90, isAntique: isAntique) {
                            if let mic = effectiveMicPitch {
                                ZStack(alignment: .topLeading) {
                                    Text(mic.noteName)
                                        .font(isAntique ?
                                            .system(size: 42, weight: .bold, design: .monospaced) :
                                            .system(size: 42, weight: .bold, design: .rounded))
                                        .foregroundColor(pitchColor(cents: mic.fineCents, isAntique: isAntique))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    VStack(alignment: .leading, spacing: 2) {
                                        let sign = mic.fineCents >= 0 ? "+" : ""
                                        Text("\(sign)\(Int(round(mic.fineCents)))¢")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(pitchColor(cents: mic.fineCents, isAntique: isAntique))

                                        Text(String(format: "%.1f Hz", mic.hz))
                                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding([.top, .leading], 8)
                                }
                            } else {
                                Text("---")
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.35))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }

                // Octave Up / Down Modifier Row: Acts directly on Tanpura Sa Root Pitch (Rock-solid, zero jitter)
                let tanpuraCanShiftDown = (audio.scaleOffsetCents - 1200) >= -300.0
                let tanpuraCanShiftUp = (audio.scaleOffsetCents + 1200) <= 1600.0

                HStack(spacing: 12) {
                    Text("Tanpura Octave:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        guard tanpuraCanShiftDown else { return }
                        audio.scaleOffsetCents -= 1200
                        audio.commitPitchChange()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("Octave Down")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!tanpuraCanShiftDown)
                    .opacity(tanpuraCanShiftDown ? 1.0 : 0.4)

                    Button(action: {
                        guard tanpuraCanShiftUp else { return }
                        audio.scaleOffsetCents += 1200
                        audio.commitPitchChange()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("Octave Up")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!tanpuraCanShiftUp)
                    .opacity(tanpuraCanShiftUp ? 1.0 : 0.4)
                }
                .frame(height: 28)

                Divider()

                // Analog Cents Needle Gauge
                TunerNeedleGaugeView(
                    cents: tuner.smoothedCents,
                    isSignalDetected: tuner.isSignalDetected,
                    isAntique: isAntique
                )

                // Capture to Tanpura Button
                HStack(spacing: 12) {
                    Button(action: {
                        guard let mic = effectiveMicPitch else { return }
                        audio.scaleOffsetCents = mic.scaleOffset
                        audio.fineTuneCents = round(mic.fineCents)
                        audio.commitPitchChange()

                        withAnimation {
                            showCapturedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showCapturedFeedback = false
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showCapturedFeedback ? "checkmark.circle.fill" : "arrow.down.left.circle.fill")
                            Text(showCapturedFeedback ? "Pitch Applied to Tanpura!" : "Capture to Tanpura / Master Pitch")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(showCapturedFeedback ? .green : (isAntique ? .orange : .accentColor))
                    .disabled(effectiveMicPitch == nil)
                }
            }
        }
        .padding(18)
        .frame(width: 380)
        .nativeCard(isAntique: isAntique, cornerRadius: 20)
        .onAppear {
            audio.isTunerMuted = true
            tuner.start()
        }
        .onDisappear {
            tuner.stop()
            audio.isTunerMuted = false
        }
    }
}
