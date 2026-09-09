# macTablaPro Core Engine: Official API Reference & State Machine Protocol

> **Specification Version**: `1.0.0-draft`
> **Target Architecture**: Universal Cross-Platform Audio Engine (Swift / C++ / WASM / JSON-RPC)
> **Source Base**: [`macTablaPro`](file:///Users/findp/Documents/macTablaPro)

---

## 1. Architectural Architecture & State Flow

The engine decouples **Inbound Control Commands** (from any UI client) from **Outbound Visual Presentation Buffers** (driven by the audio clock).

```mermaid
flowchart TD
    subgraph Client["Frontend Client (SwiftUI / React / Android / Web)"]
        UI_Action["User Interaction (Click / Slider / Tap)"]
        UI_Render["VSync Display Consumer (60Hz / 120Hz)"]
        UI_Sankalp["Riyaaz Timer & Practice Log UI"]
    end

    subgraph API_Gateway["Universal API & Dispatcher Layer"]
        Inbound_Router["Inbound Command Router (/v1/*)"]
        State_Store["Centralized State Store (Atomic Snapshot)"]
        Event_Hub["Telemetry & Presentation Ring Buffer"]
        Sankalp_Tracker["Sankalp Practice Time Engine"]
    end

    subgraph Audio_Core["Real-Time DSP & Scheduling Core"]
        Lookahead["Lookahead Audio Scheduler (t + 100ms)"]
        DSP_Graph["Audio Graph / VoicePool / Resamplers"]
        Hardware_Out["Physical Audio Hardware (Speakers / DAC)"]
    end

    UI_Action -->|Dispatch API Call / RPC| Inbound_Router
    Inbound_Router -->|Validate & Mutate| State_Store
    State_Store -->|Notify Worker| Lookahead
    State_Store -->|Notify State Change| Sankalp_Tracker
    Lookahead -->|Schedule PCM Buffers| DSP_Graph
    DSP_Graph -->|Sample-Accurate Sound| Hardware_Out
    Lookahead -->|Enqueue Timestamped VisualBeatEvent| Event_Hub
    Event_Hub -->|mach_absolute_time >= targetHostTime| UI_Render
    Sankalp_Tracker -->|Session Duration Stream| UI_Sankalp
```

---

## 2. Initialization API & Engine Lifecycle (`/v1/init`)

The engine provides a modular initialization API allowing apps to initialize **all or any subset of instruments** (e.g. Tanpura + Tabla + Sankalp for an Alankaar practice tool, or Tanpura only for a drone app).

### `POST /v1/init/configure`

Configures and pre-allocates audio hardware, voice pools, and datasets.

* **Request Schema**:

```jsonc
{
  "modules": [
    "tanpura",      // Allocates Tanpura 1 & 2 voice pools (16 voices each)
    "tabla",        // Allocates Tabla voice pool (32 voices) & parses Taal CSVs
    "swarMandal",   // Allocates Swar Mandal voice pool (48 voices)
    "tuner",        // Prepares microphone capture session & autocorrelation DSP
    "sankalp",      // Initializes riyaaz practice timer & local session storage
    "presets"       // Loads iTablaPro-compatible presets catalog
  ],
  "audioHardware": {
    "preferredSampleRate": 44100.0, // 44100.0 | 48000.0 | 96000.0
    "bufferFrameSize": 512,         // 128 | 256 | 512 | 1024
    "outputDeviceUID": null         // null for system default output
  },
  "assetSource": {
    "mode": "bundled",              // "bundled" | "directory" | "inMemory"
    "customPath": null              // Path to assets if mode == "directory"
  },
  "autoRestoreSession": true        // If true, restores last active session settings from disk
}
```

* **Response Schema**:

```jsonc
{
  "status": "ready",                // "uninitialized" | "loading" | "ready" | "error"
  "activeModules": ["tanpura", "tabla", "sankalp"],
  "loadedAssetsCount": 90,
  "memoryAllocatedMB": 48.2,
  "hardwareInfo": {
    "sampleRate": 44100.0,
    "bufferSize": 512,
    "hardwareOutputLatencyMs": 14.2
  }
}
```

### `GET /v1/init/status`

Queries engine readiness during asynchronous asset loading.

* **Response**:

```jsonc
{
  "state": "loading",
  "progress": 0.85,                 // 0.0 ... 1.0
  "currentStep": "Compiling Taal Timelines..."
}
```

### `POST /v1/init/shutdown`

Gracefully cuts active playback, cancels scheduler timers, flushes practice logs, and frees audio voice buffers from RAM.

---

## 3. Global Type Definitions & Data Models

### Pitch & Note Primitives

```jsonc
// PitchNote (Enum representing Western Sa pitch references)
"A2" | "A#2" | "B2" | "C3" | "C#3" | "D3" | "D#3" | "E3" | "F3" | "F#3" | "G3" | "G#3" | "A3" | "A#3" | "B3" | "C4" | "C#4" | "D4" | "D#4" | "E4"

// TanpuraFirstString (1st string pitch options)
"Pa" | "Ma" | "Ni" | "Sa" | "Kharaj" | "Re Komal" | "Re" | "Ga Komal" | "Ga Shuddha" | "Ma Teevra" | "Dha Komal" | "Dha" | "Ni Komal" | "Re Higher Komal" | "Re Higher" | "Ga Higher Komal" | "Ga Higher" | "Ma Higher"
```

### Visual Presentation Event (Telemetry Buffer Frame)

```typescript
interface VisualBeatEvent {
  matra: number | null;          // 1 ... totalMatras (null for pure sub-ticks)
  subStep: number | null;        // 0, 1, 2, 3 (quarter-matra subdivisions)
  bolName: string | null;        // "Dha", "Ge", "Dhin", "Na", "TiTa", etc.
  taalSymbol: string | null;     // "X" (Sam), "2", "3", "O" (Khaali), "" (empty)
  targetHostTime: number;        // mach_absolute_time / CPU clock when sound exits DAC
}
```

---

## 4. Master Engine & Mixer (`/v1/engine`)

### `POST /v1/engine/transport/toggle`

Toggles global playback. If any instrument is playing, stops all audio; if stopped, resumes previous playing snapshot.

* **Response**:

```jsonc
{
  "status": "success",
  "isPlaying": true,
  "activeInstruments": ["tanpura_1", "tanpura_2", "tabla_main"]
}
```

### `POST /v1/engine/transport/stop-all`

Immediately stops all sequence clocks and cuts scheduled audio.

* **Response**: `{ "status": "success", "isPlaying": false }`

### `POST /v1/engine/mixer/master-volume`

Sets the master output gain before physical audio hardware.

* **Request**: `{ "volume": 0.85 }` // Bounded in [0.0 ... 1.0]

### `POST /v1/engine/mixer/master-mute`

Mutes master output without pausing sequence timers.

* **Request**: `{ "isMuted": true }`

### `POST /v1/engine/mixer/channel`

Sets gain and mute state for an individual instrument channel strip.

* **Request**:

```jsonc
{
  "instrumentId": "tabla_main", // "tanpura_1" | "tanpura_2" | "tabla_main" | "swar_mandal"
  "volume": 0.90,               // Optional [0.0 ... 1.0]
  "isMuted": false              // Optional boolean
}
```

---

## 5. Master Pitch & Tuning (`/v1/pitch`)

### `POST /v1/pitch/set`

Sets global Sa pitch reference and microtonal fine-tuning offset.

* **Request**:

```jsonc
{
  "saNote": "C#3",             // Optional: "A2" ... "E4"
  "scaleOffsetCents": 100.0,   // Optional: -300.0 ... +1600.0 in 100c steps
  "fineTuneCents": 5.0,        // Optional: -100.0 ... +100.0 in 1c steps
  "commitResample": true       // If true, dispatches background sample resampler
}
```

* **Response**:

```jsonc
{
  "status": "success",
  "pitchName": "C#3",
  "scaleOffsetCents": 100.0,
  "fineTuneCents": 5.0,
  "totalPitchCents": 105.0,
  "sampleSet": "C#" // "C#" (<= 400c) or "G#" (> 400c)
}
```

### `POST /v1/pitch/step`

Steps the global Sa pitch up or down by 1 semitone (100 cents).

* **Request**: `{ "direction": "up" }` // "up" | "down"

---

## 6. Tabla Accompaniment (`/v1/tabla`)

### `POST /v1/tabla/toggle`

Starts or stops the Tabla accompaniment sequencer and visual presentation clock.

* **Response**: `{ "status": "success", "isPlaying": true }`

### `POST /v1/tabla/set-taal`

Switches the active rhythm cycle.

* **Request**: `{ "taalName": "Teentaal" }`
* **Behavior**: Automatically defaults variation to `"Pro Default"` (or `"1 beat Basic"` for Metronome), recalculates `allowedBPMRange`, and clamps active tempo if out of range.

### `POST /v1/tabla/set-variation`

Switches the rhythmic style variation for the current Taal.

* **Request**: `{ "variationName": "Pro Default" }`

### `POST /v1/tabla/set-tempo`

Sets the tempo in Beats Per Minute (BPM).

* **Request**: `{ "tempoBPM": 140.0 }` // Clamped to allowed range
* **Response**:

```jsonc
{
  "status": "success",
  "tempoBPM": 140.0,
  "tempoTier": 2,             // 0: Ati-Vilambit, 1: Vilambit, 55: Vilambit Fine, 2: Madhya, 3: Drut, 4: Ati-Drut
  "tempoCategory": "Madhya",
  "allowedRange": [81.0, 150.0]
}
```

### `POST /v1/tabla/step-tempo`

Performs relative tempo adjustments with auto-clamping.

* **Request**: `{ "delta": 5.0, "multiplier": 2.0 }`

### `POST /v1/tabla/tap-tempo`

Feeds a tap event into the monotonic tap tempo engine.

* **Response**: `{ "status": "success", "calculatedBPM": 132.0, "sampleCount": 4 }`

### `POST /v1/tabla/set-sur-mode`

Toggles Dayan harmonic ring mode (Sur) vs dry tip slap mode (Tip).

* **Request**: `{ "useSurTabla": true }`

### `GET /v1/tabla/catalog`

Returns the complete parsed Taal catalog, style variations, matra counts, and allowed speed tiers.

---

## 7. Tanpura Accompaniment (`/v1/tanpura`)

### `POST /v1/tanpura/{id}/toggle`

Starts or stops Tanpura 1 (`id = 1`) or Tanpura 2 (`id = 2`).

* **Response**: `{ "status": "success", "id": "tanpura_1", "isPlaying": true }`

### `POST /v1/tanpura/{id}/set-pitch`

Sets the 1st string pitch offset for the specified Tanpura.

* **Request**: `{ "firstString": "Pa", "customCents": 700.0 }`

### `POST /v1/tanpura/set-tempo`

Sets the shared tempo across both Tanpura 1 and 2.

* **Request**: `{ "tempoBPM": 60.0 }` // Bounded in [20.0 ... 150.0]

---

## 8. Swar Mandal (`/v1/swarmandal`)

### `POST /v1/swarmandal/auto-loop/toggle`

Starts or stops continuous background auto-looping.

* **Response**: `{ "status": "success", "isAutoLooping": true }`

### `POST /v1/swarmandal/auto-loop/interval`

Sets the interval between auto-strum passes.

* **Request**: `{ "seconds": 60 }` // 30, 60, 120, 300, 600, 900, 1200, 1800, 3600

### `POST /v1/swarmandal/strum`

Immediately triggers a single glissando pass across all tuned strings.

### `POST /v1/swarmandal/pluck`

Immediately plucks a single string.

* **Request**: `{ "stringIndex": 4 }`

### `POST /v1/swarmandal/configure`

Configures harp string count, strumming tempo, and individual string tunings.

* **Request**:

```jsonc
{
  "stringCount": 20,       // 15 ... 36
  "tempoBPM": 450.0,       // 300.0 ... 800.0 BPM
  "stringNotes": ["Sa", "Re Komal", "Ga", "Ma Teevra", "Pa", "Dha Komal", "Ni", "Sa Higher"]
}
```

---

## 9. Visual Presentation Engine (`/v1/presentation`)

The Presentation Engine decouples the high-priority lookahead audio scheduler from the UI display refresh rate (VSync 60Hz/120Hz).

### `GET /v1/presentation/events`

Streaming endpoint (WebSocket / SSE / Swift `SPSCRingBuffer`) emitting timestamped telemetry frames:

```jsonc
// 1. Matra / Bol Stroke Event
{
  "type": "tabla.beat",
  "matra": 1,
  "subStep": 0,
  "bolName": "Dha",
  "taalSymbol": "X",
  "targetHostTime": 128479218471
}

// 2. Quarter-Matra Metronome Pulse (Ati-Vilambit Tier 0)
{
  "type": "tabla.beat",
  "matra": 1,
  "subStep": 2, // 0.50 beat subdivision
  "bolName": null,
  "taalSymbol": null,
  "targetHostTime": 128480718471
}
```

### `POST /v1/presentation/latency`

Sets the hardware audio compensation offset in milliseconds.

* **Request**: `{ "offsetMs": 45.0 }` // Bounded in [-300.0 ... +300.0] ms
* **Behavior**: Shifts the visual consumption timestamp so UI LEDs light up at the exact instant sound exits Bluetooth, AirPlay, or USB DAC hardware.

### `POST /v1/presentation/auto-detect-latency`

Queries CoreAudio / ALSA / WASAPI driver frame buffers to auto-calibrate latency offset.

---

## 10. Sankalp Practice Tracker Engine (`/v1/sankalp`)

The Sankalp engine automatically measures riyaaz practice duration whenever accompaniment audio is playing, maintains session history, and provides export/Google Forms sync.

### `GET /v1/sankalp/state`

Returns active session and daily practice metrics.

* **Response**:

```jsonc
{
  "isTracking": true,
  "sessionDurationSeconds": 2540,
  "sessionMinutes": 42,
  "dailyTotalMinutes": 85,
  "lastUpdated": "2026-09-07T23:15:00Z"
}
```

### `POST /v1/sankalp/session/reset`

Resets the active practice session counter to zero.

### `POST /v1/sankalp/log`

Records and persists a completed practice session.

* **Request**:

```jsonc
{
  "studentName": "Prajwal",
  "teacherName": "Mahesh Kale",
  "durationMinutes": 45,
  "raag": "Yaman",
  "taal": "Teentaal",
  "focusArea": "Drut Taans & Layakari",
  "notes": "Focused on clarity at 180 BPM",
  "submitToGoogleForm": true
}
```

* **Response**: `{ "status": "success", "logId": "sankalp_20260907_01", "formSyncStatus": "submitted" }`

### `GET /v1/sankalp/history`

Returns historical practice session records from local storage.

---

## 11. Presets & Persistence (`/v1/presets`)

### `GET /v1/presets`

Returns all saved accompaniment presets.

### `POST /v1/presets/apply`

Applies a preset with modular scoping flags.

* **Request**:

```jsonc
{
  "presetName": "Bhairav Riyaaz",
  "scope": {
    "loadTanpura": true,
    "loadTabla": true,
    "loadPitch": true,
    "loadSwarMandal": true,
    "loadMixer": true
  }
}
```

* **Staggered Entrance Timing**:
  - $t = 0.0\text{s}$: Pitch updated; Tanpura 1 and Tabla start.
  - $t = +0.75\text{s}$: Tanpura 2 enters.
  - $t = +2.5\text{s}$: Swar Mandal enters and starts auto-loop from step 0.

### `POST /v1/presets/save`

Captures live workstation state and writes to disk.

---

## 12. Acoustic Tuner (`/v1/tuner`)

### `POST /v1/tuner/start` & `POST /v1/tuner/stop`

Controls microphone capture session. Master audio is automatically muted during tuning to eliminate acoustic feedback.

### `GET /v1/tuner/stream`

Emits real-time pitch detection frames at `8.0` updates/second:

```jsonc
{
  "isSignalDetected": true,
  "rawFrequencyHz": 138.59,
  "detectedNote": "C#3",
  "midiNoteNumber": 49,
  "centsOffset": -1.4,      // Bounded in [-50.0 ... +50.0]
  "isInTune": true,          // true if abs(centsOffset) <= 3.0
  "rmsLevelDBFS": -24.2
}
```

### `POST /v1/tuner/capture-pitch`

Transfers the currently detected acoustic note and cent offset directly into Master Pitch.
