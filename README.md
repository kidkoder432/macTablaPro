# macTablaPro 🥁

> **A native, zero-latency classical Indian music accompaniment workstation for macOS.**  
> Crafted with SwiftUI, CoreAudio DSP, and modern macOS design.

---

## Overview

**macTablaPro** brings the complete Indian classical accompaniment experience to the Mac desktop. Designed for vocalists, instrumentalists, music teachers, and students doing daily *riyaaz* (practice), it integrates authentic **Tabla accompaniment**, **Dual Tanpuras**, a **Swar Mandal (harp/zither)**, microtonal **Master Pitch & Studio Mixer**, and an integrated **Sankalp Practice Tracker** into a responsive zero-scroll workstation.

---

## ✨ Features at a Glance

### 🥁 Tabla Accompaniment Engine
- **Rich Taal Library**: Authentic presets covering Teental, Keherwa, Dadra, Rupak, Jhaptal, Ektaal, Deepchandi, Roopak, and more.
- **Variations & Shuffle Styles**: Easily switch between classical thekas, variations, and stylistic shuffle feels.
- **Live Visual Display**: High-contrast LED display showing active Matras (beats), bols (syllables), and quarter-matra metronome subdivision indicators.
- **Real-Time Tempo & Pitch**: Smooth tempo slider, tap tempo tracker, multiplier controls, and micro-timing compensation.

### 🪕 Dual Tanpura
- **Independent Pitch Tuning**: Select from Pa, Ma, Ni, or Sa tuning presets for both Tanpura 1 and Tanpura 2.
- **Fine-Pitch Detuning**: Adjust cents offset on either Tanpura to achieve lush, acoustic acoustic beating and richness.
- **Synchronized or Independent BPM**: Link both Tanpuras to a shared tempo or adjust individual pluck speeds.

### 🎼 Swar Mandal (Raag Harp / Zither)
- **Interactive Strumming**: Strum across virtual strings with continuous hover/mouse-down interaction or trigger automatic loops.
- **Customizable Scales**: Tune individual strings to match any Indian classical raag (scale).
- **Tempo Control**: Smooth continuous strumming speed control (300–800 BPM).

### 🎛️ Master Pitch & Channel Strip Mixer
- **Global Sa Reference**: Transpose all instruments simultaneously across Western notes (C through B) with fine-tuning in cent increments (±50 cents).
- **Channel-Strip Mixing**: Dedicated sub-mixers for Tabla, Tanpura 1, Tanpura 2, and Swar Mandal with gain sliders and instant mute buttons.
- **Master Transport**: One-click global start/stop and master volume control with zero audio clipping.

### ⏱️ Sankalp Practice Tracker
- **Integrated Riyaaz Timer**: Automatically measures active practice time while accompaniment is playing.
- **Streak & Habit Tracking**: Keep track of daily practice goals, milestones, and consistency.
- **Optional Form Integration**: Connect practice logs to Google Forms for study tracking or sharing with your guru/teacher.

### 💾 Presets & iTablaPro Compatibility
- Save and recall custom instrument configurations, tempos, pitches, and taal settings.
- Import and export presets compatible with standard **iTablaPro** configurations.

### 🎨 macOS-Native Visual Themes
- **Modern Liquid Glass**: Clean, translucent macOS look with blur backgrounds.
- **Vintage / Antique Mode**: Warm parchment aesthetic with classical typography and styling.

---

## 📥 Installation Guide

### Option 1: Standard Installation (No Terminal Required)

This method is recommended for musicians, vocalists, and non-technical users:

1. Go to the **[Releases](https://github.com/kidkoder432/macTablaPro/releases)** page on GitHub.
2. Download the latest `macTablaPro-v0.9.0-beta.zip` archive.
3. Double-click the downloaded `.zip` file to extract `macTablaPro.app`.
4. Drag `macTablaPro.app` into your **Applications** folder (`/Applications`).
5. Double-click `macTablaPro.app` to open.

#### If macOS displays "App is damaged" or "Unidentified Developer":
Because `macTablaPro` is distributed directly as an open-source build without an Apple Developer subscription notarization, macOS Gatekeeper may ask for one-time confirmation:

1. Open **System Settings** (click the  Apple menu in the top left > **System Settings**).
2. Click **Privacy & Security** in the left sidebar.
3. Scroll down to the **Security** section.
4. You will see a message:  
   > *"macTablaPro was blocked from use because it is not from an identified developer"*
5. Click **Open Anyway**.
6. On the confirmation popup, click **Open** and enter your Mac password or use Touch ID.

*(You only need to do this once! After the first launch, macTablaPro will open instantly just like any native Mac app.)*

---

### Option 2: Power-User Terminal Shortcut

If you prefer using Terminal, you can remove the macOS quarantine flag in one command:

```bash
xattr -cr /Applications/macTablaPro.app
```

---

## 🛠️ Building from Source

If you want to contribute or build `macTablaPro` locally:

### Prerequisites
- **macOS 13.0 (Ventura)** or later
- **Xcode 15.0+** with Swift 6.0 support
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

### Build in Xcode
1. Clone the repository:
   ```bash
   git clone https://github.com/kidkoder432/macTablaPro.git
   cd macTablaPro
   ```
2. Open `macTablaPro.xcodeproj` in Xcode:
   ```bash
   open macTablaPro.xcodeproj
   ```
3. Select the `macTablaPro` scheme and press `Cmd + R` to build and run.

### Build via Command Line
Run the automated release packaging script:
```bash
./export_app.sh
```
This builds an ad-hoc signed Release bundle and packages `macTablaPro.zip` to your Desktop.

---

## 🤖 Development Philosophy & AI Attribution

Transparency and honesty are core principles of this project.

- **Musical & Architectural Direction**: The entire conceptual design, Indian classical music domain specifications (Taal structures, bol sequences, microtonal Sa frequencies, Tanpura string models, Swar Mandal scales), UI/UX workflows, and audio timing requirements were defined, guided, and curated through human domain expertise.
- **Code Implementation**: The vast majority of the Swift and SwiftUI codebase, DSP voice-pool infrastructure, and boilerplate code was written collaboratively with AI coding assistants (Google Antigravity & Gemini) under direct and iterative human prompt engineering, testing, and review.

We believe that being honest about the role of AI in modern software creation fosters trust, encourages open experimentation, and highlights how domain knowledge and AI pairing can bring niche, high-craft creative tools to life.

---

## 🗺️ Roadmap to v1.0

- [ ] Hardware-synced visual presentation queue (`CVDisplayLink` frame locking).
- [ ] Expanded Taal and Bol variation library.
- [ ] MIDI clock synchronization and external audio interface routing.
- [ ] Universal preset sharing.

---

## 💬 Feedback & Community

Encountered a bug or have an idea for a feature or new Taal?  
- **Issues**: Open a bug report on [GitHub Issues](https://github.com/kidkoder432/macTablaPro/issues).
- **Discussions**: Share presets or musical feedback on [GitHub Discussions](https://github.com/kidkoder432/macTablaPro/discussions).

---

*Made with dedication for Indian Classical Music practitioners everywhere.*
