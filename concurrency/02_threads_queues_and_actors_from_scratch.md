# Module 2: Concurrency & Threading Fundamentals from Scratch

If you know nothing about threads, concurrency, or CPU execution, this is where we start. Every expert started here.

---

## 1. What is a CPU Core and what is a Thread?

Think of your Mac's CPU as a **restaurant kitchen**:

- **CPU Cores**: The actual physical **cooks** in the kitchen (e.g., an 8-core M-series chip has 8 cooks working simultaneously).
- **Process**: The entire **restaurant** (`macTablaPro.app`), containing memory, loaded audio files, and open windows.
- **Thread**: A **recipe list** being executed by one of the cooks. Each thread is a sequence of CPU instructions executed line by line.

```
+-------------------------------------------------------------------+
|                        macTablaPro Process                        |
|                                                                   |
|  [Thread 1: Main Thread]      [Thread 2: Audio Engine]   ...      |
|  Cook #1: Draws UI, handles    Cook #2: Sends audio to            |
|  mouse clicks, 60fps/120fps   speakers every 5.8ms                |
|                                                                   |
|                    Shared RAM (Data in Memory)                    |
|           - Tabla samples, current BPM, active Taal               |
+-------------------------------------------------------------------+
```

If you have multiple threads, multiple cooks can work in the same kitchen at the exact same time, reading and modifying the **same shared memory**.

---

## 2. Why is the Main Thread Special?

In macOS and iOS, **Thread 1 is the Main Thread (`@MainActor`)**:

- Operating systems dictate that **only the Main Thread is allowed to draw pixels on the screen or handle mouse/keyboard events**.
- If the Main Thread is busy doing heavy work (like parsing large files, resampling audio, or running infinite loops), the UI freezes. The Mac shows the "spinning rainbow beachball".

---

## 3. What is Concurrency vs Parallelism?

- **Parallelism**: Two cooks doing two different tasks at the exact same physical instant on two separate CPU cores.
  - *Example*: Core 1 calculates UI layout while Core 2 plays audio through the speakers.
- **Concurrency**: Managing multiple tasks that overlap in time. If you only have one cook, they might chop onions for 5ms, then stir the soup for 5ms, then check the oven for 5ms. It *looks* simultaneous to humans, but the CPU is rapidly switching between tasks (called **Context Switching**).

---

## 4. The Golden Problem: Shared Mutable State & Race Conditions

What happens if Cook #1 is editing the `activeTaal` array while Cook #2 is reading `activeTaal` to play the next beat?

```
Cook #1 (UI Thread):       Erasing "Teentaal" array to load "Jhaptal"...
Cook #2 (Audio Thread):    Reading index 15 of array...
                           💥 CRASH: Index out of bounds (Memory Race Condition)!
```

When two threads access the same memory at the same time and at least one is writing, you have a **Data Race**.

To solve this, computer science invented **Synchronization Tools**:

| Tool                                   | Real-World Analogy                                                                                                       | Risk in Real-Time Audio                                                                                                                                        |
| :------------------------------------- | :----------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Lock (`NSLock`, Mutex)**     | A bathroom key. Only one person can be inside. Everyone else waits in line outside.                                      | If Cook#1 (UI) takes the key and gets distracted, Cook #2 (Audio) is forced to wait. The audio runs out of data $\rightarrow$ **Audible Pop/Stutter!** |
| **Serial Queue / Swift Actor**   | A single order ticket rail. Orders are handled one at a time in exact FIFO order.                                        | Safe for normal apps, but`await` means yielding execution (not permitted on real-time audio threads).                                                        |
| **Lock-Free Ring Buffer (SPSC)** | A revolving sushi belt with a single chef putting plates on, and a single customer taking plates off. Nobody ever waits. | The**Gold Standard** for real-time audio $\leftrightarrow$ UI communication.                                                                           |

---

## 5. Why Does Lookahead Audio Scheduling Exist?

Why can't we just play the audio the exact microsecond a beat happens?

The computer speaker hardware needs a steady stream of numbers (44,100 or 48,000 numbers per second).
If the speaker hardware buffer runs empty for even **1 millisecond**, you hear a **glitch, pop, or crackle** (a **buffer underrun**).

Because the operating system might briefly delay a background thread (e.g. when opening a new app or moving a window), audio engines **look ahead**:

1. At time $t = 0.00\text{s}$, the audio scheduler computes what should play at $t = 0.05\text{s}$ (50ms in the future).
2. It sends that audio buffer to the hardware queue with the timestamp $t = 0.05\text{s}$.
3. When the hardware clock hits $t = 0.05\text{s}$, the sound plays out of the speaker with crystal-clear hardware accuracy, immune to any temporary CPU hiccups!

---

## 6. So What Went Wrong in macTablaPro?

Look at what the code currently does:

```
[Time = 0.00s]
1. Scheduler calculates beat for Time = 0.05s.
2. Scheduler sends audio to speakers with instruction: "Play at 0.05s".
3. BUT THEN Scheduler immediately says: "self.currentBol = 'Dha'" (Right now, at 0.00s!).
```

- At 60 BPM, 50ms is $1/20$th of a beat (hard to notice).
- But at **240 BPM**, a 16th-note sub-beat lasts only **62.5ms**!
- If the scheduler prepares 2 or 3 strokes in a single 100ms lookahead burst, `self.currentBol` gets changed 3 times in 1 millisecond on the UI. The first two bols flash and vanish before the screen even refreshes once!

---

## 7. The 3 Questions to Master Concurrency

To fix this cleanly and build a rock-solid system, we need to answer:

1. **Who is responsible for the lookahead clock?** (A background actor/thread, totally independent of the UI).
2. **How does the background thread tell the UI what to display?** (Passing a lightweight timestamped event message).
3. **When does the UI display it?** (When the clock matches the timestamp of the sound exiting the speakers).
