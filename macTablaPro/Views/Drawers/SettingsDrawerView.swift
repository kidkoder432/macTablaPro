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
    @State private var settingsTab: SettingsTab = .global

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
                                TextField("Enter MKSM ID", text: $audio.studentID)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("First Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter First Name", text: $audio.firstName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Last Name", text: $audio.lastName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Email", text: $audio.email)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Batch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter Batch", text: $audio.batch)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 520)
        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 20)
        .padding(.trailing, 24)
        .padding(.top, 24)
    }
}
