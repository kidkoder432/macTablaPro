# Module 7: What is "Atomic" & Why Audio Power Draw Jumps to 30

---

## 1. What Does "Atomic" Mean?

The word **atomic** comes from the Greek *atomos* $\rightarrow$ **"indivisible"** (cannot be split into smaller pieces).

In computer hardware, when a CPU writes data to RAM, it happens in tiny chunks (assembly instructions, cache lines, memory registers).

### The Non-Atomic Nightmare: A "Torn Read"

Imagine a struct holding a Pitch:
```swift
struct MasterPitch {
    var scaleOffsetCents: Double = 100.0   // 8 bytes in RAM
    var fineTuneCents: Double = 25.0       // 8 bytes in RAM
}
```

Now imagine two threads running at the same time on two CPU cores:

```
[Main Thread / Cook #1]: User drags slider from (100, 25) to (700, 0)
Step 1: Writes scaleOffsetCents = 700.0
   └── (Right at this microsecond, CPU switches to Thread 2!) ───┐
                                                                 ▼
[Audio Thread / Cook #2]: Reads MasterPitch to play a note!
   Reads: scaleOffset = 700.0
   Reads: fineTune    = 25.0 (Old value not updated yet!)
   💥 Result: Notes play with an out-of-tune pitch that never existed in your UI!
```

Even worse: if a string or array is being updated while another thread reads it, the reading thread reads an invalid memory pointer $\rightarrow$ **App Crash (`EXC_BAD_ACCESS`)**.

---

### What Makes Something "Atomic"?

An **Atomic Operation** guarantees that the CPU does the read or write **as a single, indivisible transaction**.

```
[Main Thread]: Atomic Write (scaleOffset: 700, fineTune: 0)
      │
      ▼ (Locked transaction in CPU memory controller)
[Audio Thread]: Waits 5 nanoseconds, then reads (700, 0) completely.
```

No thread can EVER see data halfway updated.

---

## 2. Why Did We Use Atomic Wrappers in the Code?

When we moved the **Audio Scheduler** to a background queue, the Audio Scheduler and the UI now run on **two different CPU cores simultaneously**:

- **UI Thread (`@MainActor`)**: Writes new BPM, Pitch, and Taal when you click buttons.
- **Audio Scheduler Thread**: Reads BPM, Pitch, and Taal 100 times a second to schedule notes.

By putting an atomic lock around those variables (`atomicBPM`, `atomicPitch`, `atomicTablaState`), both threads can read and write freely without crashing and without corrupting each other's data.

---

## 3. Power Draw: Why Energy Impact Jumps from 4 to 30

You noticed:
- **Tanpura only**: Energy impact $\approx 4$
- **All instruments playing**: Energy impact $\approx 30$

Will thread safety alone save battery? **No.** Thread safety stops crashes, but power draw is caused by **CPU work cycles**.

Here is why your energy impact jumps to 30 when playing all instruments:

### Cause #1: Dynamic Audio Resampling During Note Playback (The Biggest Culprit!)
Look at what happens every time a Tabla or Swar Mandal note plays:
```swift
// AudioVoice.swift
try? buffer = OfflineAudioResampler.resample(
    sourceBuffer: buffer,
    centsOffset: targetPitchCents - sample.resampledPitch
)
```
On **every single stroke**:
1. It allocates a new `AVAudioConverter` object.
2. It allocates a brand new `AVAudioPCMBuffer` in RAM.
3. It runs a heavy mathematical digital signal processing (DSP) interpolation filter across thousands of audio float samples.
4. It throws the buffer away after 1 second.

At 240 BPM with Tabla + Swar Mandal + 2 Tanpuras, your CPU is running **hundreds of resampling allocations per second**.

### Cause #2: 4 Separate Timer Loops Waking Up the CPU
Right now, you have **4 independent `LookaheadAudioScheduler` objects** (Tanpura 1, Tanpura 2, Tabla, Swar Mandal), plus the UI display timer.
Each timer fires every 25ms.
When 5 independent timers fire at slightly different times, the CPU cores are **prevented from entering deep low-power sleep states (C-states)**.

---

## 4. How We Can Cut Power Draw by 70%

1. **Pre-resample buffers when Master Pitch changes** (Offline Pitch Cache) instead of resampling inside the playback callback. During playback, playing a sound should simply be: `scheduleBuffer(cachedBuffer)` — **zero CPU math, zero RAM allocation**.
2. **Consolidate timers into 1 Master Engine Clock** so CPU cores sleep between beats.
