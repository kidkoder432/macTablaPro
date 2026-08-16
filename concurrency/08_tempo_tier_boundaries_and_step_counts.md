# Module 8: Why Tempo Changes Cut Taals in Half or Double Them

---

## 1. The Mystery

You noticed:
- When you **slow down** across a speed boundary, the Taal is **cut in half** (e.g. loops back to 1 at matra 8 instead of 16).
- When you **speed up** across a speed boundary, the Taal counts to 32 (or plays the first half and plays **blanks for the second half**).

Why does this happen? Is the ring buffer overflowing? **No.**

It is a mathematical mismatch between **`stepsCount` in the Scheduler** and **`subdivisionsPerBeat` (`subs`) in `Tabla.swift`**.

---

## 2. How Tempo Tiers Work in `Tabla.swift`

To play complex rapid bols (like *DhaGeNaTi* or *KDa* flams) at slow speeds without glitching, `Tabla.swift` divides each beat (Matra) into subdivisions:

| Tempo Tier | BPM Range | Subdivisions / Beat (`subs`) | Total Steps for 16-Matra Taal (`16 * subs`) |
| :--- | :--- | :--- | :--- |
| **Vilambit (Tier 1)** | 25 – 80 BPM | **16** | **256 steps** |
| **Madhya (Tier 2)** | 81 – 150 BPM | **8** | **128 steps** |
| **Drut (Tier 3)** | 151 – 300 BPM | **4** | **64 steps** |

---

## 3. The Root Cause Bug

Look at how `LookaheadAudioScheduler` runs its loop:
```swift
// LookaheadAudioScheduler.swift
stepIndex = (stepIndex + 1) % stepsCount
```

When you hit Play at **100 BPM (Madhya)**:
- `stepsCount` was set to **128** (`16 * 8`).
- The scheduler loop loops from `0 ... 127`.

### Scenario A: You drag the slider from 100 BPM $\rightarrow$ 160 BPM (Drut)
1. In `Tabla.swift`, the speed is now 160 BPM $\rightarrow$ Tier 3 (Drut).
2. For Drut, `subs = 4`.
3. In `executeSequenceTick`:
   `calculatedMatra = (stepIndex / subs) + 1 = (stepIndex / 4) + 1`
4. BUT the scheduler is still looping up to `stepsCount = 128`!
5. When `stepIndex` reaches 64: `calculatedMatra = (64 / 4) + 1 = 17`!
   - Step `0 ... 63` $\rightarrow$ plays Matras 1 to 16.
   - Step `64 ... 127` $\rightarrow$ attempts to play Matras 17 to 32 (which don't exist in Teentaal, resulting in blanks!).
   💥 **Result: The Taal finishes in the first half and plays blanks in the second half!**

### Scenario B: You drag the slider from 100 BPM $\rightarrow$ 60 BPM (Vilambit)
1. In `Tabla.swift`, speed is now 60 BPM $\rightarrow$ Tier 1 (Vilambit).
2. For Vilambit, `subs = 16`.
3. In `executeSequenceTick`:
   `calculatedMatra = (stepIndex / subs) + 1 = (stepIndex / 16) + 1`
4. When `stepIndex` reaches 127 (the scheduler's old ceiling), `calculatedMatra` only reached:
   `(127 / 16) + 1 = 8`!
5. The scheduler modulo-wraps `stepIndex` back to 0!
   💥 **Result: The Taal loops back to Sam at Matra 8, cutting the 16-beat Taal in half!**

---

## 4. The Architectural Solution

There are two ways to solve this:

### Approach 1: Dynamic Tier-Change Detection in `Tabla.tempoBPM`
When `tempoBPM` crosses a Tier boundary (e.g. crossing 80 BPM or 150 BPM while playing), immediately call `updateTimelinePosition()` so the scheduler's `stepsCount` is reset to the new tier's total steps, and `startingPulse` is recalculated at the exact current fractional beat.

### Approach 2: Continuous Beat Position in Scheduler (The Purest Architecture)
Instead of scheduling in discrete integer step indexes (`stepIndex = 0...N`), the scheduler tracks continuous **`beatPosition: Double`** (from `0.0` to `totalMatras`). On each tick, the instrument returns the beat duration fraction (e.g. `0.25` or `0.0625`), and `beatPosition = (beatPosition + fraction) % totalMatras`.

This completely decouples the scheduler from subdivision counts!
