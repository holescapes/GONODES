# Timeline, Animation & Cue System

GONODES provides a layered timeline and cue system built on the principle that
**time is just data**.  Rather than a monolithic timeline editor, the system is
composed of operators that produce, transform, and consume time — the same way
everything else works in the dataflow graph.

The four layers, each usable independently:

| Layer | Component | Purpose |
|-------|-----------|---------|
| **1 — Engine Transport** | `GNCookEngine` enhancements | Frame range, speed, seek, step, loop |
| **2 — TimelineCHOP** | Operator | Independent local time sources |
| **3 — CueDAT + CueCHOP** | Operators | Show control / cue sequencing |
| **4 — Editor Timeline UI** | Editor toolbar | Visual scrubbing, transport controls |

---

## Layer 1: Engine Transport

The cook engine (`GNCookEngine`) has been enhanced with transport controls
that every existing operator benefits from automatically — all operators
already read `elapsed_time`, `current_frame`, and `current_delta`.

### New Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `playback_speed` | `float` | `1.0` | Global speed multiplier (0.5 = half, 2.0 = double) |
| `loop_mode` | `LoopMode` enum | `NONE` | `NONE`, `LOOP`, or `PING_PONG` |
| `time_range` | `Vector2i` | `(0, 0)` | Playback bounds as (start_frame, end_frame). `(0,0)` = unbounded |
| `transport_fps` | `float` | `60.0` | FPS used for frame↔time conversion |

### New Methods

| Method | Description |
|--------|-------------|
| `seek_time(t: float)` | Jump to a specific time in seconds. Invalidates all nodes. |
| `seek_frame(f: int)` | Jump to a specific frame number. |
| `step_forward()` | Advance exactly one frame, then pause. |
| `step_backward()` | Go back one frame (re-cook at previous frame). |

### New Signals

| Signal | Description |
|--------|-------------|
| `transport_looped()` | Emitted when time wraps at loop boundary |
| `transport_ended()` | Emitted when playback reaches end of time_range (NONE mode) |
| `transport_seeked(time: float)` | Emitted after a seek operation |

### Expression Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `fps()` | `float` | Effective FPS (NRT target or real-time 1/dt) |
| `speed()` | `float` | Current playback speed multiplier |
| `tstart()` | `float` | Timeline start time in seconds |
| `tend()` | `float` | Timeline end time in seconds |
| `frames()` | `int` | Total frames in timeline range at current FPS |

> These functions are methods on `GNCookEngine` — available in any parameter expression via the `base_instance` mechanism.  The timeline range is synced from the editor's scrubber (`timeline_start`, `timeline_end`).

---

## Layer 2: TimelineCHOP

An operator that generates a **local time signal** independent of the global
engine clock.  Multiple TimelineCHOPs can coexist at different speeds, ranges,
and loop modes — enabling complex multi-timeline setups.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | float | `0.0` | Local start time (seconds) |
| `end` | float | `10.0` | Local end time (seconds) |
| `speed` | float | `1.0` | Local speed multiplier |
| `loop` | enum | `Loop` | None / Loop / Ping-Pong |
| `play` | bool | `true` | Enable local playback |
| `sync_to_engine` | bool | `true` | When true, derives time from engine `elapsed_time`. When false, advances independently. |
| `trigger` | pulse | — | Reset local time to start |

### Output Channels

| Channel | Description |
|---------|-------------|
| `time` | Current local time in seconds |
| `frame` | Current local frame number |
| `fraction` | 0.0–1.0 normalized progress within start↔end |
| `playing` | 1.0 if playing, 0.0 if paused |
| `speed` | Effective speed value |
| `looped` | 1.0 pulse on each loop boundary, 0.0 otherwise |

### Usage — Binding Other Operators to a Timeline

Any parameter on any operator can reference a TimelineCHOP via expressions:

```
# KeyframeCHOP driven by a local timeline instead of global time:
chop("timeline1", "time")

# A TOP's opacity driven by timeline progress:
chop("timeline1", "fraction")

# Conditional logic based on timeline state:
1.0 if chop("timeline1", "playing") > 0.5 else 0.5
```

### Multi-Timeline Example

A VJ show with three simultaneous timelines:

- **`timeline_main`** — 4-minute song structure (`sync_to_engine=true`)
- **`timeline_intro`** — 10-second intro sequence (`loop=None`, `sync_to_engine=false`)
- **`timeline_vfx`** — 2-beat repeating effect (`loop=Loop`, speed driven by BeatCHOP)

---

## Layer 3: CueDAT + CueCHOP (Show Control)

### CueDAT — Cue List Manager

A DAT that stores show cues as a table with these columns:

| Column | Type | Description |
|--------|------|-------------|
| `index` | int | Cue number (auto-assigned) |
| `name` | string | Human-readable cue label |
| `time` | float | Start time in seconds (`-1` = wait for manual trigger) |
| `duration` | float | Duration in seconds (`0` = indefinite / manual advance) |
| `transition` | string | `cut` or `fade:seconds` (e.g., `fade:1.5`) |
| `data` | JSON | Dict of `"node_id/param_name": value` overrides |

**Parameters:** `num_cues` controls how many cue entries to show. Each cue has
per-row parameters for name, time, duration, transition, and data.

**Alternative:** Wire an upstream DAT (e.g., loaded from CSV/JSON) into the
CueDAT's input to override the built-in parameter cues.

#### Example Cue Table

```
index | name     | time  | duration | transition | data
0     | blackout | 0.0   | 2.0      | cut        | {}
1     | intro    | 2.0   | 8.0      | fade:1.5   | {"switch1/mix": 0.0}
2     | verse1   | 10.0  | 16.0     | fade:2.0   | {"switch1/mix": 1.0}
3     | drop     | 26.0  | 8.0      | cut        | {"gain1/volume": 1.0}
4     | outro    | 34.0  | 6.0      | fade:3.0   | {"switch1/mix": 0.0}
```

### CueCHOP — Cue Sequencer

Reads a cue table (from CueDAT or any DAT) and outputs the current cue state
as CHOP channels.  Supports both automatic (timeline-driven) and manual
(trigger-driven) cue advancement.

#### Inputs

| Port | Type | Description |
|------|------|-------------|
| 0 | DAT | Cue table (from CueDAT) |
| 1 | CHOP (optional) | Trigger input — rising edge advances cue |

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | enum | `Timeline` | `Timeline` = auto by time, `Manual` = trigger only |
| `timeline` | string | `""` | Node ID of TimelineCHOP for auto mode (empty = engine time) |
| `go_next` | pulse | — | Advance to next cue |
| `go_prev` | pulse | — | Go back one cue |
| `go_to` | int | `-1` | Jump to cue index (-1 = disabled) |
| `go_to_name` | string | `""` | Jump to cue by name |
| `apply_data` | bool | `true` | Apply cue data{} overrides on cue change |

#### Output Channels

| Channel | Description |
|---------|-------------|
| `active_cue` | Current cue index |
| `cue_progress` | 0.0–1.0 progress within current cue's duration |
| `transition` | 0.0–1.0 transition blend amount |
| `next_cue` | Index of upcoming cue |
| `cue_elapsed` | Seconds since current cue started |
| `cue_remaining` | Seconds until current cue ends |

#### The `data` Column — Parameter Overrides

When a cue activates, the CueCHOP parses the JSON `data` field and applies
each key-value pair as a parameter override via `set_par()`. Key format:
`"node_id/param_name"`.

This means a single cue change can:
- Switch scenes: `"switch1/mix": 1.0`
- Change colors: `"color_top1/color": [1, 0, 0, 1]`
- Swap video files: `"hap_in1/file": "res://media/drop.mov"`
- Adjust any parameter on any operator

All through the existing parameter + expression infrastructure — no new
mechanism needed.

#### Mode Comparison

| Mode | Use Case | How It Works |
|------|----------|-------------|
| **Timeline** | Linear show, pre-timed | Reads time from TimelineCHOP (or engine). Fires cues when their `time` is reached. |
| **Manual** | Live VJ, installation | Cues advance only on `go_next` pulse — from keyboard, MIDI, OSC, or UI button. |

---

## Layer 4: Editor Timeline UI

The editor toolbar has been enhanced with transport controls:

### Transport Bar (Row 1)

| Control | Description |
|---------|-------------|
| **Play/Pause** | Toggle cooking on/off (Space) |
| **Reset** | Jump to frame 0, destroy runtime state (Escape) |
| **⏪ Step Back** | Step backward one frame |
| **⏩ Step Forward** | Step forward one frame |
| **Speed** | SpinBox: 0.0x–10.0x playback speed |
| **Loop** | Cycle button: Off → Loop → Ping-Pong |
| **NRT** | Non-Realtime mode toggle + FPS spinner |

### Timeline Scrubber (Row below toolbar)

A horizontal slider showing current time position:
- **Time label**: `M:SS.s / F####` format
- **Scrubber**: Click or drag to seek to any time
- **Auto-updates**: Tracks `elapsed_time` during playback

---

## Composition Example

A realistic VJ show graph combining all layers:

```
[BeatCHOP] ───→ [TimelineCHOP "vfx_loop"]
     │                │
     │                ▼
     │          [KeyframeCHOP] ──→ [expressions on TOPs]
     │
[MidiInCHOP] ──→ [CueCHOP] ←── [CueDAT "show_cues"]
  (go_next)          │
                     │ outputs: active_cue, transition
                     ▼
             [SwitchTOP] ←── [SceneA, SceneB, SceneC]
                  │
                  ▼
             [CompositeTOP] ──→ [OutputTOP]
                  ▲
             [TimelineCHOP "main"] ──→ (drives fade curves)
```

- **MIDI controller** fires `go_next` → CueCHOP advances → parameter overrides apply
- **TimelineCHOP "main"** provides the linear show clock (engine-synced)
- **TimelineCHOP "vfx_loop"** runs a 2-beat repeating pattern (BeatCHOP-synced)
- **CueDAT** table is editable live — add/remove/reorder cues during the show

---

## Existing Time-Based Operators

These operators complement the timeline system:

| Operator | Family | Role in Timeline |
|----------|--------|-----------------|
| `KeyframeCHOP` | CHOP | Ramp curve animation sampled at a time source |
| `SequenceCHOP` | CHOP | Sequence inputs end-to-end with crossfade |
| `ClipCHOP` | CHOP | Transport playback of recorded CHOP data |
| `TriggerCHOP` | CHOP | One-shot envelope on threshold crossing |
| `BeatCHOP` | CHOP | Audio onset detection for beat-synced timelines |
| `WarpCHOP` | CHOP | Time-warp / retime |
| `LFOCHOP` | CHOP | Periodic signal (sine, square, etc.) |
| `AnimationCOMP` | COMP | AnimationPlayer-based transform keyframes |

---

## File Reference

| File | Description |
|------|-------------|
| `addons/gonodes/core/gn_cook_engine.gd` | Engine transport: speed, range, seek, step, loop |
| `addons/gonodes/operators/chop/timeline_chop.gd` | TimelineCHOP operator |
| `addons/gonodes/operators/chop/cue_chop.gd` | CueCHOP operator |
| `addons/gonodes/operators/dat/cue_dat.gd` | CueDAT operator |
| `scenes/gn_editor.gd` | Editor timeline UI (transport bar, scrubber) |
| `addons/gonodes/core/gn_extension_registry.gd` | Operator registration |
