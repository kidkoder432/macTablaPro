# Module 4: Why UI Cannot "Look Ahead" (And How the V-Sync Consumer Works)

You asked a great question: *“Would it be possible to do a lookahead scheduler for the UI too?”*

Here is the fundamental difference between how **Audio Hardware** and **Display Hardware (GPUs)** work.

---

## 1. Why Audio Can Look Ahead, but UI Cannot

### The Audio Hardware:
CoreAudio's driver has an internal hardware FIFO buffer. You can hand it a sound sample and tell it:
> *"CoreAudio, hold this sound in your buffer and play it when `mach_absolute_time() == 1,000,000`."*

CoreAudio stores it and plays it at that exact nanosecond.

### The Display Hardware (GPU / SwiftUI):
The GPU and SwiftUI do **not** have a timestamped future buffer for text/numbers.
When you write:
```swift
self.currentBolName = "Dha"
```
SwiftUI immediately invalidates the view and draws `"Dha"` on the **very next screen refresh (VSync)**. 

You cannot tell SwiftUI: *"Store 'Dha' and draw it 50ms from now."* If you change the variable, it draws immediately.

---

## 2. So How Do We Achieve Perfect Audio-Visual Sync?

The Audio Scheduler is **already doing the lookahead for both systems**!

Look at the pipeline:

```
[Time = 0.00s]  Audio Scheduler wakes up on Background Thread
                 │
                 ├─► 1. Hands audio sample to CoreAudio: 
                 │      "Play this sound at Time = 0.05s"
                 │
                 └─► 2. Pushes event into SPSC Ring Buffer:
                        VisualEvent(bol: "Dha", matra: 1, hostTime: 0.05s)
```

Now, who watches the Ring Buffer? **A Display Loop (VSync Timer / CADisplayLink)**:

```
[Time = 0.00s to 0.049s]
  Display loop checks Ring Buffer at every 60Hz/120Hz frame:
  "Is current time >= 0.05s?" -> NO. Leave it alone. Screen shows previous bol.

[Time = 0.050s]
  1. CoreAudio plays sound through the speakers!
  2. Display loop checks Ring Buffer:
     "Is current time >= 0.05s?" -> YES!
     Display loop pops the event and sets: self.currentBolName = "Dha".
     SwiftUI paints "Dha" on screen.
```

**Result**: Sound exits speakers and "Dha" appears on screen at the exact same physical instant.

---

## 3. The 4 Engineering Tasks to Fix macTablaPro

To solve all 4 of your annoyances:

| Annoyance | Root Cause | Engineering Fix |
| :--- | :--- | :--- |
| **1. Display not time-accurate** | UI updated at schedule time instead of render time. | Scheduler pushes `VisualBeatEvent` to SPSC Ring Buffer; `DisplayLink` consumes at `targetHostTime`. |
| **2. Switching Taals causes pops** | Scheduler reading old step index against new Taal array without synchronization. | Atomic timeline swap on Matra boundary + clean voice stop without DC offset jump. |
| **3. UI clicks chop audio attack** | Audio scheduler running on `@MainActor`, blocked by UI clicks/drags. | Move `LookaheadAudioScheduler` to high-priority background queue / dedicated thread. |
| **4. Spaghetti code** | Threading, audio synthesis, and UI state tangled in `Tabla.swift`. | Decouple into 3 clean layers: Engine / Scheduler / Presentation. |
