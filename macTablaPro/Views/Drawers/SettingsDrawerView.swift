import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case global = "Global"
    case sankalp = "Sankalp Info"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .global: return "gearshape"
        case .sankalp: return "person.text.rectangle"
        }
    }
}

// MARK: - Settings Drawer View (Liquid Glass Floating Panel)
struct SettingsDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @ObservedObject private var presentation = VisualPresentationEngine.shared
    @State private var settingsTab: SettingsTab = .global
    @State private var latencyInputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        audio.isInspectorPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            // Horizontal Tab Selector
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            settingsTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(settingsTab == tab ?
                                    (audio.isAntiqueThemeEnabled ? Color.orange : Color.accentColor) :
                                    Color.clear)
                        )
                        .foregroundColor(settingsTab == tab ?
                            (audio.isAntiqueThemeEnabled ? .black : .white) :
                            .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if settingsTab == .global {
                        // Antique Electronic Box Theme Toggle
                        Toggle("Antique Box Theme", isOn: $audio.isAntiqueThemeEnabled)
                            .toggleStyle(.switch)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Divider()

                        // Shared Tanpura Tempo Controller
                        VStack(spacing: 12) {
                            HStack {
                                Text("Shared Tanpura Tempo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(Int(audio.sharedTanpuraBPM)) BPM")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { audio.sharedTanpuraBPM },
                                    set: { audio.sharedTanpuraBPM = round($0) }
                                ),
                                in: 20...180
                            )
                            .tint(audio.isAntiqueThemeEnabled ? .orange : .accentColor)
                        }

                        Divider()

                        // Audio-Visual Sync (Display Latency Compensation)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("Audio-Visual Sync")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text(presentation.isCustomLatency ? "Custom" : "Auto (CoreAudio)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(presentation.isCustomLatency ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                    )
                                    .foregroundColor(presentation.isCustomLatency ? Color.orange : Color.green)

                                Spacer()
                                
                                HStack(spacing: 2) {
                                    TextField("", text: Binding(
                                        get: { "\(Int(round(presentation.visualLatencyOffsetMs)))" },
                                        set: { text in
                                            if let val = Double(text) {
                                                presentation.setCustomLatency(val)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .frame(width: 44)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(audio.isAntiqueThemeEnabled ? Color.black.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(audio.isAntiqueThemeEnabled ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    
                                    Text("ms")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Slider(
                                value: Binding(
                                    get: { presentation.visualLatencyOffsetMs },
                                    set: { presentation.setCustomLatency($0) }
                                ),
                                in: 0...400.0
                            )
                            .tint(audio.isAntiqueThemeEnabled ? .orange : .accentColor)

                            HStack {
                                Button(action: {
                                    let detected = presentation.autoDetectLatency()
                                    print("Auto-detected CoreAudio latency: \(detected) ms")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform.badge.magnifyingglass")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Auto-Detect")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(audio.isAntiqueThemeEnabled ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.15))
                                    )
                                    .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : Color.accentColor)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button("Reset (0ms)") {
                                    presentation.setCustomLatency(0.0)
                                }
                                .font(.caption2)
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }

                            Text("Delays visual beat numbers to match Bluetooth & speaker output latency.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sankalp Form Info")
                                .font(.headline)
                                .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : .primary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("MKSM ID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter MKSM ID", text: $audio.sankalp.studentID)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("First Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter First Name", text: $audio.sankalp.firstName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Last Name", text: $audio.sankalp.lastName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Email", text: $audio.sankalp.email)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Batch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Batch", text: $audio.sankalp.batch)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 290)
        .frame(maxHeight: 560)
        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 20)
        .padding(.trailing, 24)
        .padding(.top, 24)
    }
}
