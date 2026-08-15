import SwiftUI

// MARK: - Root Workstation Window View
struct ContentView: View {
    @StateObject private var audio = AppAudioOrchestrator()

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            // MARK: - Main Workspace (Zero-Scroll 3-Column Layout with Split Glass Overlays)
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 1. LEFT COLUMN: Tanpura 1 & 2 Cards Stacked + Swar Mandal Underneath
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        if let tanpura1 = audio.tanpura1 {
                            TanpuraCardView(tanpura: tanpura1, title: "Tanpura 1")
                        }

                        if let tanpura2 = audio.tanpura2 {
                            TanpuraCardView(tanpura: tanpura2, title: "Tanpura 2")
                        }

                        if let swarMandal = audio.swarMandal {
                            SwarMandalCardView(swarMandal: swarMandal)
                        }
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 2. CENTER COLUMN: Master Pitch (Top) + Tabla Controls (Center)
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        MasterPitchCardView(audio: audio)
                        
                        if let tabla = audio.tabla {
                            TablaCardView(tabla: tabla)
                        }
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 3. RIGHT COLUMN: Master Mixer Hub (ALWAYS VISIBLE!) + Sankalp Card
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        MixerCardView(audio: audio)
                        SankalpCardView(audio: audio)
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)
                }
                .padding(.top, WorkstationLayout.topPadding)
                .padding(.bottom, WorkstationLayout.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // MARK: - Left Presets Drawer Overlay (Pre-rendered offscreen for 0ms instant open)
                HStack {
                    PresetsDrawerView(audio: audio)
                        .offset(x: audio.isPresetsPresented ? 0 : -350)
                        .opacity(audio.isPresetsPresented ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: audio.isPresetsPresented)
                    Spacer()
                }
                .allowsHitTesting(audio.isPresetsPresented)

                // MARK: - Liquid Glass Translucent Overlay (Floating Settings Panel)
                if audio.isInspectorPresented {
                    HStack {
                        Spacer()
                        SettingsDrawerView(audio: audio)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // MARK: - Launch Blurry Loading Overlay
                if audio.isAppLoading {
                    ZStack {
                        VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .progressViewStyle(.circular)
                            Text("Loading Workstation Audio & Assets...")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(28)
                        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 22)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(minWidth: WorkstationLayout.minWindowWidth, idealWidth: WorkstationLayout.minWindowWidth, minHeight: WorkstationLayout.minWindowHeight)
        .navigationTitle(Text(""))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    audio.isPresetsPresented.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.left")
                        Text("Presets")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(audio.isPresetsPresented ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Toggle Presets Drawer")
            }

            ToolbarItem(placement: .principal) {
                Text(audio.isAntiqueThemeEnabled ? "macTablaPro Vintage" : "macTablaPro")
                    .font(audio.isAntiqueThemeEnabled ? .custom("Snell Roundhand", size: 18).weight(.bold) : .headline)
                    .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : .secondary)
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: {
                        audio.isMasterMuted.toggle()
                    }) {
                        Image(systemName: audio.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(audio.isMasterMuted ? .red : (audio.isAntiqueThemeEnabled ? Color.orange : .primary))
                    }
                    .buttonStyle(.plain)
                    .help(audio.isMasterMuted ? "Unmute All Instruments" : "Quick Mute All Instruments")

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            audio.isInspectorPresented.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Settings")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(audio.isInspectorPresented ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Settings Drawer")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
