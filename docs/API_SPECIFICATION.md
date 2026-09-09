# Comprehensive Domain Constraints & API Specification (Single Source of Truth)

## Executive Overview

This document compiles the **complete, forensic catalogue of all constraints, ranges, mathematical formulas, and domain invariants** across the entire [`macTablaPro`](file:///Users/findp/Documents/macTablaPro) engine.

It serves as the definitive specification for both **frontend implementations** (macOS, iOS, Web, Android, Windows) and the **core backend audio/DSP engine**.

---

## 1. Master Tuning & Global Sa Reference

| Parameter                      | Domain Constraint / Valid Range                                                                      | Default Value     | Units                        | Core Formula / Mapping                                                    |
| :----------------------------- | :--------------------------------------------------------------------------------------------------- | :---------------- | :--------------------------- | :------------------------------------------------------------------------ |
| **Sa Base Gamut**        | `A2` (MIDI 45) to `E4` (MIDI 64) [20 semitones]                                                  | `C#3` (MIDI 49) | Note / MIDI                  | Reference note for Indian classical*Sa* (Tonic)                         |
| **`scaleOffsetCents`** | `-300.0 ... +1600.0` in 100¢ steps                                                                | `+100.0` (C#3)  | Cents (relative to C3 = 0¢) | $\text{scaleOffsetCents} = (\text{MIDI} - 48) \times 100$               |
| **`fineTuneCents`**    | `-100.0 ... +100.0` in 1¢ increments                                                              | `0.0`           | Cents                        | Fine microtonal pitch adjustment                                          |
| **Total Transposition**  | `-400.0 ... +1700.0`                                                                               | `+100.0`        | Cents                        | $\text{Total Pitch} = \text{scaleOffsetCents} + \text{fineTuneCents}$   |
| **Sample Set Split**     | $\le 400.0¢ \rightarrow$ **C# Sample Set**$> 400.0¢ \rightarrow$ **G# Sample Set** | —                | —                           | Selects base acoustic sample recordings to prevent resampling artifacting |

### Pitch Name to Cents Mapping Table

```
A2 (-300¢)  A#2 (-200¢)  B2 (-100¢)  C3 (0¢)     C#3 (+100¢)  D3 (+200¢)  D#3 (+300¢)  E3 (+400¢)
F3 (+500¢)  F#3 (+600¢)  G3 (+700¢)  G#3 (+800¢) A3 (+900¢)   A#3 (+1000¢) B3 (+1100¢) C4 (+1200¢)
C#4 (+1300¢) D4 (+1400¢) D#4 (+1500¢) E4 (+1600¢)
```

---

## 2. Tabla Subsystem Constraints

| Parameter                    | Domain Constraint / Valid Range                                                          | Default Value  | Description                                                                                         |
| :--------------------------- | :--------------------------------------------------------------------------------------- | :------------- | :-------------------------------------------------------------------------------------------------- |
| **Global Tempo Range** | `10.0 ... 700.0`                                                                       | `100.0`      | BPM (Beats Per Minute)                                                                              |
| **Allowed BPM Range**  | Bounded dynamically per Taal & Variation:$\min(\text{tiers}) \dots \max(\text{tiers})$ | Taal dependent | Query via`tabla.allowedBPMRange()`                                                                |
| **Logarithmic Slider** | Range`0.0 ... 1.0` with base $B = 10.0$                                              | —             | $s = \frac{\ln(1 + 9r)}{\ln 10}$ where $r = \frac{\text{BPM} - \min}{\max - \min}$              |
| **Sur Tabla Mode**     | `true` (Dayan harmonic ring) or `false` (Tip dry slap)                               | `false`      | If`taal.forceSur == true` (e.g. Chautaal, Dhamar), Sur mode is **strictly forced** `true` |

### Tempo Tier Definitions & Audio/UI Invariants

|  Tier Index  | Tier Name               | BPM Range           | Audio & Scheduling Invariants                                                                                         | Visual / UI Invariants                                                                                                            |
| :----------: | :---------------------- | :------------------ | :-------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| **0** | **Ati-Vilambit**  | `10.0 ... 25.0`   | Dedicated quarter-matra metronomic pulses scheduled ahead at intervals of`0.25` matras (`0.0, 0.25, 0.50, 0.75`). | Display shows active quarter-subdivision dots (`·`, `· ·`, `· · ·`, `· · · ·`).                                 |
| **1** | **Vilambit**      | `25.0 ... 80.0`   | Standard slow beat resolution.                                                                                        | Full matra & bol display.                                                                                                         |
| **55** | **Vilambit Fine** | `55.0 ... 80.0`   | Specialized speed variation for 55–80 BPM.                                                                           | Full matra & bol display.                                                                                                         |
| **2** | **Madhya**        | `81.0 ... 150.0`  | Medium laya. Most common practice tier.                                                                               | Full matra & bol display.                                                                                                         |
| **3** | **Drut**          | `151.0 ... 300.0` | Fast laya.                                                                                                            | Full matra & bol display.                                                                                                         |
| **4** | **Ati-Drut**      | `301.0 ... 700.0` | Ultra-fast laya.                                                                                                      | **UI Throttling**: Visual events are filtered **strictly to Taali/Khaali boundaries** to eliminate LED/text strobing. |

### Taal Notation Rules

- **Sam (Beat 1)**: Always rendered as `"X"`.
- **Taali (Clap)**: Rendered as index `"2"`, `"3"`, `"4"`, etc.
- **Khaali (Wave)**: Rendered as `"O"`.
- **Intermediate Matras**: Rendered as `""` (empty string).

---

## 3. Tanpura Subsystem Constraints (Tanpura 1 & 2)

| Parameter                    | Domain Constraint / Range                                 | Default Value  | Description                                                             |
| :--------------------------- | :-------------------------------------------------------- | :------------- | :---------------------------------------------------------------------- |
| **First String Pitch** | `0.0 ... 1700.0` cents                                  | `700.0` (Pa) | Tuning of the 1st string                                                |
| **Shared Tempo**       | `20.0 ... 150.0` BPM                                    | `60.0` BPM   | Synchronized tempo across both Tanpuras                                 |
| **Sequence Formula**   | Fixed 5-step loop:`[FirstString, Sa, Sa, Kharaj, Rest]` | —             | Sample pitch:`[FirstString¢, 1200¢, 1200¢, 0¢, Rest]`             |
| **Staggered Entrance** | Tanpura 1:$t=0.0\text{s}$Tanpura 2: $t=+0.75\text{s}$ | —             | Prevents Tanpura 1 & 2 plucks from clashing synchronously on cold start |

### First String Pitch Catalog

| Octave Band                     | Swar Name                 | Offset from Sa (Cents) |
| :------------------------------ | :------------------------ | :--------------------: |
| **Lower Octave (Mandra)** | Kharaj                    |        `0¢`        |
|                                 | Re Komal                  |       `100¢`       |
|                                 | Re                        |       `200¢`       |
|                                 | Ga Komal                  |       `300¢`       |
|                                 | Ga Shuddha                |       `400¢`       |
|                                 | Ma                        |       `500¢`       |
|                                 | Ma Teevra                 |       `600¢`       |
|                                 | **Pa (Standard)**   |  **`700¢`**  |
|                                 | Dha Komal                 |       `800¢`       |
|                                 | Dha                       |       `900¢`       |
|                                 | Ni Komal                  |       `1000¢`       |
|                                 | Ni                        |       `1100¢`       |
| **Higher Octave (Taar)**  | **Sa (Taar  Sa)** |  **`1200¢`**  |
|                                 | Re Higher Komal           |       `1300¢`       |
|                                 | Re Higher                 |       `1400¢`       |
|                                 | Ga Higher Komal           |       `1500¢`       |
|                                 | Ga Higher                 |       `1600¢`       |
|                                 | Ma Higher                 |       `1700¢`       |

---

## 4. Swar Mandal Subsystem Constraints

| Parameter                       | Domain Constraint / Range                                 | Default Value   | Description                                        |
| :------------------------------ | :-------------------------------------------------------- | :-------------- | :------------------------------------------------- |
| **String Count**          | `15 ... 36` strings                                     | `20`          | Total virtual strings on the harp                  |
| **Strum Tempo**           | `300.0 ... 800.0` BPM                                   | `450.0` BPM   | Plucking speed of the glissando pass               |
| **Acoustic Decay Factor** | Fixed constant:`0.96` (4% slowdown/string)              | `0.96`        | $\text{BPM}_i = \text{tempoBPM} \times (0.96)^i$ |
| **Auto-Loop Durations**   | `30s, 60s, 120s, 300s, 600s, 900s, 1200s, 1800s, 3600s` | `60s` (1 Min) | Interval between consecutive auto-strums           |
| **Preset Stagger Time**   | $t = +2.5\text{s}$                                      | —              | Enters 2.5s after Tanpuras when loading presets    |

### 36 Swar Tuning Gamut (-1200¢ to +2300¢)

- **Lower Octave (-1200¢ to -100¢)**: `Sa Lower (-1200¢)`, `Re Komal Lower (-1100¢)`, `Re Lower (-1000¢)`, `Ga Komal Lower (-900¢)`, `Ga Lower (-800¢)`, `Ma Lower (-700¢)`, `Ma Teevra Lower (-600¢)`, `Pa Lower (-500¢)`, `Dha Komal Lower (-400¢)`, `Dha Lower (-300¢)`, `Ni Komal Lower (-200¢)`, `Ni Lower (-100¢)`.
- **Middle Octave (0¢ to 1100¢)**: `Kharaj (0¢)`, `Re Komal (100¢)`, `Re (200¢)`, `Ga Komal (300¢)`, `Ga (400¢)`, `Ma (500¢)`, `Ma Teevra (600¢)`, `Pa (700¢)`, `Dha Komal (800¢)`, `Dha (900¢)`, `Ni Komal (1000¢)`, `Ni (1100¢)`.
- **Higher Octave (+1200¢ to +2300¢)**: `Sa (1200¢)`, `Re Komal Higher (1300¢)`, `Re Higher (1400¢)`, `Ga Komal Higher (1500¢)`, `Ga Higher (1600¢)`, `Ma Higher (1700¢)`, `Ma Teevra Higher (1800¢)`, `Pa Higher (1900¢)`, `Dha Komal Higher (2000¢)`, `Dha Higher (2100¢)`, `Ni Komal Higher (2200¢)`, `Ni Higher (2300¢)`.
- **Mute**: `"Off"`.

---

## 5. Mixer & Channel Strip Hierarchy

| Channel Node          | Gain Range      |  Default Gain  | Mute State | Description                                 |
| :-------------------- | :-------------- | :------------: | :--------: | :------------------------------------------ |
| **Master Bus**  | `0.0 ... 1.0` | `1.0` (100%) | `false` | Master output gain before physical hardware |
| **Tanpura 1**   | `0.0 ... 1.0` | `0.3` (30%) | `false` | Left Tanpura bus gain                       |
| **Tanpura 2**   | `0.0 ... 1.0` | `0.3` (30%) | `false` | Right Tanpura bus gain                      |
| **Tabla**       | `0.0 ... 1.0` | `1.0` (100%) | `false` | Tabla bus gain                              |
| **Swar Mandal** | `0.0 ... 1.0` | `0.25` (25%) | `false` | Swar Mandal bus gain                        |

---

## 6. Acoustic Tuner & DSP Detection Subsystem

| Parameter                       | Domain Constraint / Value                                   | Description                                                 |
| :------------------------------ | :---------------------------------------------------------- | :---------------------------------------------------------- |
| **Supported Gamut**       | `A2` (MIDI 45 / 110.0 Hz) to `E4` (MIDI 64 / 329.63 Hz) | Acoustic detection pitch range                              |
| **Analysis Cadence**      | `8.0` updates/sec (every 125ms)                           | Balances real-time responsiveness with zero display flutter |
| **Analysis Window Size**  | `2048` frames                                             | PCM buffer length for autocorrelation pitch detection       |
| **Noise Gate Floor**      | `-48.0` dBFS                                              | Audio frames below this RMS level are treated as silence    |
| **Cents Deviation Gauge** | Strictly bounded to`[-50.0 ... +50.0]` cents              | Analog needle rotation angle                                |
| **In-Tune Tolerance**     | $|\text{cents}| \le 3.0¢$                                | Triggers vibrant green needle indicator                     |

---

## 7. Timing, Latency & Presentation Constraints

| Subsystem                            | Constraint / Value                            | Purpose                                                        |
| :----------------------------------- | :-------------------------------------------- | :------------------------------------------------------------- |
| **Lookahead Audio Scheduler**  | `100ms` (`0.100s`) ahead-of-time window   | Pre-schedules audio buffers to guarantee zero underruns        |
| **Scheduler Dispatch Cadence** | `25ms` (`DispatchSourceTimer`)            | Replenishes future lookahead audio queue                       |
| **Initial Start Delay**        | `25ms` (`0.025s`)                         | Lead-time before beat 1 to prevent attack clipping             |
| **Visual Latency Offset**      | Strictly bounded to`[-300.0 ... +300.0]` ms | Compensates for Bluetooth/AirPlay audio hardware delays        |
| **Presentation Loop**          | `120Hz` (~8.33ms interval)                  | Consumes`SPSCRingBuffer` events at exact speaker output time |
| **Tap Tempo Buffer**           | `4 ... 5` samples, `2.0s` timeout         | Computes dynamic BPM from user tapping intervals               |

---

## 8. Presets & Persistence Scope Constraints

| Scope Key                    | Associated Parameters Loaded                                                 |
| :--------------------------- | :--------------------------------------------------------------------------- |
| **`loadTanpura`**    | Tanpura 1 & 2 On/Off state, First String Pitch, Shared Tanpura BPM           |
| **`loadTabla`**      | Tabla On/Off state, Taal Name, Style/Variation Name, Tempo BPM, Sur Mode     |
| **`loadSwarMandal`** | Swar Mandal On/Off state, String Notes Array, Strum Tempo BPM, Loop Interval |
| **`loadPitch`**      | `scaleOffsetCents` (Sa Note), `fineTuneCents`                            |
| **`loadMixer`**      | Master Volume, Tanpura 1 Gain, Tanpura 2 Gain, Tabla Gain, Swar Mandal Gain  |
