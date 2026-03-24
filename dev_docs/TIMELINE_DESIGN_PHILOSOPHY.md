# GONODES Timeline & Cue System — Design Philosophy

> **Status:** Design reference. TimelineCHOP, CueCHOP, CueDAT, SequenceCHOP, and KeyframeCHOP are all implemented.

---

Here's how the Timeline/Cue system fits into GONODES's architecture — layered from engine primitives up to show-control UI.

---

## Design Philosophy

GONODES is a **real-time, dataflow-first** system. The core principle: **time is just data**. Rather than bolting on a monolithic timeline editor, the system should be built from composable operators that produce, transform, and consume time — the same way everything else works in the graph.

Three layers, each usable independently:

---

## Layer 1: Engine Transport (cook engine improvements)

Right now `GNCookEngine` has `elapsed_time` that counts up forever, plus play/pause/reset. That's insufficient for show work. Minimal additions:

```
GNCookEngine (enhanced)
├── time_range: Vector2i        # playback bounds (start_frame, end_frame)  
├── playback_speed: float       # global multiplier (0.5× slow-mo, 2× fast)
├── loop_mode: enum             # NONE, LOOP, PING_PONG
├── loop_range: Vector2i        # optional sub-range for looping
├── step_forward()              # advance exactly 1 frame, then pause
├── step_backward()             # rewind 1 frame (re-cook at frame-1)
├── seek_frame(f: int)          # jump to frame, invalidate all, re-cook
├── seek_time(t: float)         # jump to time
```

**Why at engine level?** Every operator already reads `elapsed_time`, `current_frame`, `current_delta`. Making the engine aware of a frame range means scrubbing, looping, and stepping "just work" for all existing operators — KeyframeCHOP, SequenceCHOP, ClipCHOP, LFO, etc. — with zero changes to them.

**Expression additions:**
```
frames       → total frames in time_range
fps          → current FPS (realtime or NRT)
tstart       → time_range start in seconds
tend         → time_range end in seconds  
speed        → playback_speed
```

---

## Layer 2: TimelineCHOP (operator-level time source)

A CHOP that **generates a local time signal** independent of global engine time. This is the key building block — it decouples "show time" from "engine time."

```
TimelineCHOP
├── Parameters:
│   ├── start: float            # local start time (seconds)
│   ├── end: float              # local end time
│   ├── speed: float            # local speed multiplier  
│   ├── loop: enum              # NONE / LOOP / PING_PONG
│   ├── play: bool              # local play/pause
│   ├── trigger: pulse          # restart from start
│   ├── sync_to_engine: bool    # true = follow engine time, false = free-running
│
├── Outputs (GNChannelData):
│   ├── "time"       → current local time in seconds
│   ├── "frame"      → current local frame number
│   ├── "fraction"   → 0.0–1.0 normalized progress
│   ├── "playing"    → 1.0 or 0.0
│   ├── "speed"      → effective speed
│   ├── "looped"     → pulse on each loop boundary
```

**Usage pattern — any operator can bind to a timeline via expressions:**

```
# KeyframeCHOP that follows "timeline1" instead of global time:
Parameter "start" expression:  chop("timeline1", "time")

# A TOP's opacity driven by timeline progress:  
Parameter "opacity" expression:  chop("timeline1", "fraction")
```

**Multiple independent timelines coexist.** A VJ might have:
- `timeline_main` — 4-minute song structure  
- `timeline_intro` — 10-second intro sequence (loop=NONE)  
- `timeline_vfx` — 2-beat repeating effect (loop=LOOP, synced to BeatCHOP)

---

## Layer 3: CueDAT + CueCHOP (show control)

This is where performance/installation sequencing lives.

### CueDAT (table-based cue list)

A DAT that holds the show's cue sheet as a table:

```
┌───────┬──────────┬────────┬──────────┬────────────┬─────────────────────────────────┐
│ index │ name     │ time   │ duration │ transition │ data                            │
├───────┼──────────┼────────┼──────────┼────────────┼─────────────────────────────────┤
│ 0     │ blackout │ 0.0    │ 2.0      │ cut        │ {}                              │
│ 1     │ intro    │ 2.0    │ 8.0      │ fade:1.5   │ {"scene_switch1/mix": 0.0}      │
│ 2     │ verse1   │ 10.0   │ 16.0     │ fade:2.0   │ {"scene_switch1/mix": 1.0, ...} │
│ 3     │ drop     │ 26.0   │ 8.0      │ cut        │ {"intensity/gain": 1.0}         │
│ 4     │ outro    │ 34.0   │ 6.0      │ fade:3.0   │ {"scene_switch1/mix": 0.0}      │
└───────┴──────────┴────────┴──────────┴────────────┴─────────────────────────────────┘
```

- **`time`**: absolute start time or `-1` for "wait for trigger"  
- **`duration`**: how long this cue runs (0 = indefinite / manual advance)  
- **`transition`**: `cut`, `fade:seconds`, or a ramp curve name  
- **`data`**: JSON dict of `"node_id/param_name": value` overrides  
- Can be **edited inline** (DAT table editor), **loaded from JSON/CSV**, or **built by another DAT chain**

### CueCHOP (cue sequencer engine)

```
CueCHOP
├── Inputs:
│   ├── 0: CueDAT reference (or wired DAT input)
│   ├── 1: trigger CHOP (optional — manual cue advance)
│
├── Parameters:
│   ├── cue_source: enum       # TIMELINE (auto by time) / MANUAL (trigger only)   
│   ├── timeline: string       # reference to a TimelineCHOP for auto mode
│   ├── go_next: pulse         # advance to next cue
│   ├── go_prev: pulse         # go back one cue
│   ├── go_to: int             # jump to cue index
│   ├── go_to_name: string     # jump to cue by name
│
├── Outputs (GNChannelData):
│   ├── "active_cue"       → current cue index
│   ├── "cue_progress"     → 0.0–1.0 within current cue's duration
│   ├── "transition"       → 0.0–1.0 transition blend amount
│   ├── "next_cue"         → index of upcoming cue
│   ├── "cue_elapsed"      → seconds since current cue started
│   ├── "cue_remaining"    → seconds until current cue ends
│
├── Side effect (on cue change):
│   └── Applies data{} overrides via cook_engine.set_par() calls
```

**Two modes that cover different use cases:**

| Mode | Use Case | How it works |
|------|----------|-------------|
| **TIMELINE** | Linear show, pre-timed | CueCHOP reads `chop("timeline1", "time")`, fires cues when their `time` is reached |
| **MANUAL** | Live VJ, installation | Cues advance only on `go_next` pulse — from keyboard, MIDI, OSC, or UI button |

**The `data` column is the power feature.** When a cue activates, CueCHOP iterates its key-value pairs and calls `cook_engine.set_par("node_id", "param_name", value)`. This means a cue can:
- Switch scenes (`scene_switch1/mix → 1.0`)
- Change colors (`color_top1/color → [1,0,0,1]`)
- Swap video files (`hap_in1/file → "res://media/drop.mov"`)
- Adjust any parameter on any operator

All through the existing parameter + expression infrastructure. No new mechanism needed.

---

## Layer 4: Editor Timeline UI

A visual timeline strip below the node graph:

```
┌─────────────────────────────────────────────────────────────────────┐
│ [▶ Pause] [⏮ Reset] [⏪] [⏩] [Step ▶|]  Frame: 1847  Time: 30.8s │
├─────┬───────┬─────────────────┬────────────┬──────────┬────────────┤
│▼    │ intro │     verse1      │   drop     │  outro   │            │
│ 0s  │  2s   │      10s        │    26s     │   34s    │        40s │
├─────┴───────┴─────────────────┴────────────┴──────────┴────────────┤
│ ■■■■■■■■■■■■■■■■■■■■■■■███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                          ▲ scrubber                                 │
│           [══════════════] loop range bracket                       │
└─────────────────────────────────────────────────────────────────────┘
```

- **Cue lane**: colored blocks from CueDAT, labeled with cue names  
- **Scrubber**: click-drag to seek (calls `cook_engine.seek_time()`)  
- **Loop bracket**: drag to set local loop range  
- **Transport bar**: play/pause, reset, step forward/back, speed slider  
- **Right-click cue block**: edit cue properties, insert/delete cue  

This is pure UI reading from CueDAT data — the operators remain the source of truth.

---

## How It All Composes

Here's a realistic VJ show graph:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  [BeatCHOP] ──→ [TimelineCHOP "vfx_loop"]                  │
│       │              │                                      │
│       │              ▼                                      │
│       │         [KeyframeCHOP] ──→ [expressions on TOPs]    │
│       │                                                     │
│  [MidiInCHOP] ──→ [CueCHOP] ←── [CueDAT "show_cues"]      │
│    (go_next)         │                                      │
│                      │ outputs: active_cue, transition      │
│                      ▼                                      │
│              [SwitchTOP] ←── [SceneA, SceneB, SceneC]       │
│                   │                                         │
│                   ▼                                         │
│              [CompositeTOP] ──→ [OutputTOP]                 │
│                   ▲                                         │
│              [TimelineCHOP "main"] ──→ (drives fade curves) │
└─────────────────────────────────────────────────────────────┘
```

- **MIDI controller** fires `go_next` → CueCHOP advances → parameter overrides apply instantly  
- **TimelineCHOP "main"** provides the linear show clock (follows engine time)  
- **TimelineCHOP "vfx_loop"** runs a 2-beat repeating pattern (synced to BeatCHOP tempo)  
- **CueDAT** table is editable live — add/remove/reorder cues during the show  

---

## Implementation Priority

| Phase | What | Effort | Impact |
|-------|------|--------|--------|
| **1** | Engine transport: frame range, speed, seek, step | Small | Unlocks scrubbing & step-debug for everyone |
| **2** | TimelineCHOP | Medium | Independent time sources, multi-timeline setups |
| **3** | CueDAT + CueCHOP | Medium | Full show control / cue sequencing |
| **4** | Editor timeline UI | Large | Visual scrubbing, cue editing, loop brackets |

Phase 1 is the foundation — it improves every existing workflow. Phases 2–3 are pure operators — they slot into the existing DAG with no framework changes. Phase 4 is UI polish.

Want me to start implementing Phase 1 (engine transport enhancements)?