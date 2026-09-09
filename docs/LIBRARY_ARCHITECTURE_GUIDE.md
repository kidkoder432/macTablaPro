# How to Build a Library from macTablaPro: Step-by-Step Engineering Guide

> **Target Audience**: Developers transitioning from monolithic app code to modular library packages.  
> **Goal**: Demystify what a library is in practice, how Swift Packages work, and the exact step-by-step extraction process.

---

## 1. What *is* a Library in Plain English?

Right now, [`macTablaPro`](file:///Users/findp/Documents/macTablaPro) is a single **monolithic app target**:
- The UI (SwiftUI views, cards, sliders, themes) and the Backend (AVAudioEngine, voice pools, scheduling loops, CSV parsers) all live in the same folder and compile into one `.app` bundle.

### What Making it a Library Means:
A library is simply a **folder of pure Swift/C code with no UI views** that has been given a public interface (`public func`, `public struct`). 

```
┌────────────────────────────────────────────────────────┐
│                   macTablaPro.app                      │
│   (SwiftUI Views: Sliders, Cards, Themes, LEDs)        │
└──────────────────────────┬─────────────────────────────┘
                           │ imports
                           ▼
┌────────────────────────────────────────────────────────┐
│             ClassicalAudioKit (Library)                │
│   • Audio Graph & Voice Pools                          │
│   • Lookahead Timing Scheduler                         │
│   • Taal, Bol & Scale CSV Parsers                      │
│   • Sample Resamplers & Tuner DSP                      │
│   • 13 MB Audio WAV Manifest                           │
└────────────────────────────────────────────────────────┘
```

Once the backend is a library:
1. Your **macOS app** imports it: `import ClassicalAudioKit`
2. A future **iOS / iPadOS app** imports the exact same library.
3. A future **Web / Android / Windows app** can compile the exact same core logic into a C library (`.xcframework` / WASM).

---

## 2. The Structure of a Swift Package Library

In the Swift ecosystem, libraries are built using **Swift Package Manager (SPM)**. A package is just a directory with a standard layout:

```
ClassicalAudioKit/                      <-- Standalone Package Directory
├── Package.swift                       <-- Manifest defining the library
├── Sources/
│   └── ClassicalAudioKit/              <-- All Core Engine Code
│       ├── Public/                     <-- Clean Public API (What callers see)
│       │   ├── ClassicalMusicEngine.swift
│       │   ├── InstrumentControllers.swift
│       │   ├── AccompanimentEvents.swift
│       │   └── DomainModels.swift      <-- PitchNote, TaalSummary, etc.
│       │
│       ├── Internal/                   <-- Private Engine Plumbing
│       │   ├── AudioGraph/             <-- VoicePool, AudioVoice, Mixers
│       │   ├── Scheduling/             <-- LookaheadAudioScheduler, RingBuffer
│       │   ├── Database/               <-- CSV Parsers, TimelineCompilers
│       │   └── DSP/                    <-- Resamplers, Tuner Autocorrelation
│       │
│       └── Resources/                  <-- Bundled Data (Included in library)
│           ├── Audio/                  <-- 90 WAV sample files (~13MB)
│           └── CSV/                    <-- Taal.csv, TaalBols.csv (~500KB)
│
└── Tests/
    └── ClassicalAudioKitTests/         <-- Automated unit tests
        ├── TaalCatalogTests.swift
        └── TimingSchedulerTests.swift
```

---

## 3. The `Package.swift` Manifest File

This single file tells Xcode and the Swift compiler how to build the library and package its audio assets:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClassicalAudioKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // The library product that other apps will import
        .library(
            name: "ClassicalAudioKit",
            targets: ["ClassicalAudioKit"]
        ),
    ],
    targets: [
        .target(
            name: "ClassicalAudioKit",
            resources: [
                .process("Resources/Audio"),
                .process("Resources/CSV")
            ]
        ),
        .testTarget(
            name: "ClassicalAudioKitTests",
            dependencies: ["ClassicalAudioKit"]
        ),
    ]
)
```

---

## 4. The 4-Step Migration Blueprint

You don't have to rewrite your app from scratch. We extract the library in 4 safe, incremental steps:

### Step 1: Separate UI Files from Engine Files
We classify every file in your project into **Library Files** vs. **App Files**:

| Destination | Files from `macTablaPro` |
| :--- | :--- |
| **Move to Library** | [`AudioClock.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/AudioClock.swift), [`AudioVoice.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/AudioVoice.swift), [`LookaheadAudioScheduler.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/LookaheadAudioScheduler.swift), [`OfflineAudioResampler.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/OfflineAudioResampler.swift), [`PitchedSample.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/PitchedSample.swift), [`SPSCRingBuffer.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/SPSCRingBuffer.swift), [`TablaData.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/TablaData.swift), [`Tabla.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/Tabla.swift), [`Tanpura.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/Tanpura.swift), [`SwarMandal.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/SwarMandal.swift), [`TunerService.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/TunerService.swift), [`ITablaProPreset.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/ITablaProPreset.swift), all WAV audio assets & CSV files. |
| **Keep in App** | [`ContentView.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/ContentView.swift), all Views in `macTablaPro/Views/` (`Cards`, `Components`, `Drawers`, `Styles`), [`VisualPresentationEngine.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/VisualPresentationEngine.swift), [`SankalpPracticeManager.swift`](file:///Users/findp/Documents/macTablaPro/macTablaPro/SankalpPracticeManager.swift). |

---

### Step 2: Establish the `public` Access Boundary
In Swift, files inside a package default to `internal` (invisible to outside callers). 
We add `public` only to the classes, methods, and structs that consumers should touch:

```swift
// Public Entry Point
public final class ClassicalMusicEngine: Sendable {
    public let tabla: TablaController
    public let tanpura1: TanpuraController
    public let tanpura2: TanpuraController
    public let swarMandal: SwarMandalController
    
    public init() throws { ... }
    public func playAll() async { ... }
    public func stopAll() async { ... }
}
```

Internal mechanics (like `VoicePool`, `SPSCRingBuffer`, `PitchedSample`, `OfflineAudioResampler`) remain `internal` or `private`. This hides complexity from the caller!

---

### Step 3: Connect UI to the Library via Events (No Hard Links)
The library never imports `SwiftUI`. Instead, the library emits timestamped events (`VisualBeatEvent`), and the app's `VisualPresentationEngine` consumes them at display frame intervals (VSync):

```swift
// In your App:
import SwiftUI
import ClassicalAudioKit

@MainActor
class AppViewModel: ObservableObject {
    let engine = try! ClassicalMusicEngine()
    
    func onPlayClicked() {
        Task {
            await engine.tabla.play()
        }
    }
}
```

---

### Step 4: Add Package to Your Xcode Project
In Xcode:
1. Open your `macTablaPro.xcodeproj`.
2. Go to **File > Add Package Dependencies... > Add Local...**
3. Select the `ClassicalAudioKit` folder.
4. Add `ClassicalAudioKit` to the **Frameworks, Libraries, and Embedded Content** section.
5. In `ContentView.swift`, add `import ClassicalAudioKit`.

---

## 5. Summary: Why This Makes Life Easier for You

1. **Clean Mental Model**: You don't have to worry about audio DSP bugs when tweaking UI colors or animations.
2. **Instant Reusability**: When you want to build an iOS app next week, you don't copy-paste 20 audio files. You just click "Add Package `ClassicalAudioKit`" and immediately have full Indian classical accompaniment.
3. **Easy Collaboration**: You can send just the library folder to your mentor or another developer to review, test, or integrate into their own projects.
