# Timeline & Cues

GONODES provides a multi-layer timeline system for show automation, cue-based
performance, and time-sequenced animation. You can run multiple independent
timelines simultaneously, each at different speeds and loop modes.

---

## Overview

The timeline system has three core operators:

| Operator | Family | Purpose |
|----------|--------|---------|
| **TimelineCHOP** | CHOP | Independent local timeline with transport controls |
| **CueDAT** | DAT | Defines a cue list with timing, transitions, and data overrides |
| **CueCHOP** | CHOP | Reads the cue list and outputs cue state as CHOP channels |

Plus **SequenceCHOP** for sequencing CHOP inputs end-to-end in time.

---

## TimelineCHOP

Creates an independent local timeline that can run at a different speed,
range, and loop mode from the global engine clock. Multiple TimelineCHOPs
can run simultaneously for different aspects of a show.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | Float | `0.0` | Local start time (seconds) |
| `end` | Float | `10.0` | Local end time (seconds) |
| `speed` | Float | `1.0` | Speed multiplier (negative = reverse) |
| `loop` | Enum | Loop | **None** / **Loop** / **Ping-Pong** |
| `play` | Bool | On | Enable/disable local playback |
| `sync_to_engine` | Bool | On | Track engine clock (off = free-running) |
| `trigger` | Pulse | — | Reset local time to start |

### Output Channels

| Channel | Description |
|---------|-------------|
| `time` | Local time in seconds |
| `frame` | Frame number (at 60 fps) |
| `fraction` | Normalized 0–1 progress through the range |
| `playing` | 1.0 when playing, 0.0 when paused |
| `speed` | Current speed multiplier |
| `looped` | 1.0 pulse on each loop boundary |

### Sync vs Free-Running Mode

- **Sync** (`sync_to_engine = true`): Derives local time from
  `elapsed_time × speed`, then applies loop clamping. Good for
  deterministic time-locked animation.
- **Free-running** (`sync_to_engine = false`): Advances by
  `delta × speed` each frame. Good for independent clocks that
  can be paused and resumed.

### Referencing from Expressions

```gdscript
# In any parameter expression:
chop("timeline1", "time")       # current time in seconds
chop("timeline1", "fraction")   # 0–1 normalized progress
```

---

## CueDAT

Defines a cue list — a table of named cues with timing, transitions, and
optional parameter overrides. Feeds into CueCHOP for sequencing.

### Output Table Columns

| Column | Description |
|--------|-------------|
| `index` | Cue number (0-based) |
| `name` | Cue name (e.g., "Intro", "Drop", "Outro") |
| `time` | Trigger time in seconds (-1 = wait for manual trigger) |
| `duration` | Hold duration (0 = indefinite until next cue) |
| `transition` | `"cut"` (instant) or `"fade:1.5"` (fade over 1.5 sec) |
| `data` | JSON overrides: `{"node_id/param_name": value}` |

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `num_cues` | Int | 1 | Number of cues (1–64) |
| `cue{i}_name` | String | `""` | Name for cue i |
| `cue{i}_time` | Float | -1 | Trigger time (-1 = manual only) |
| `cue{i}_duration` | Float | 0 | Hold duration (0 = indefinite) |
| `cue{i}_transition` | String | `"cut"` | Transition type |
| `cue{i}_data` | String | `""` | JSON parameter overrides |

### Data Overrides

When a cue has a `data` field, its JSON entries are applied as parameter
changes when the cue activates:

```json
{"noise1/scale": 2.5, "fade1/opacity": 0.0}
```

This lets you automate parameter changes from the cue list without
manual wiring.

---

## CueCHOP

Reads a cue table (from CueDAT or any DAT) and outputs the current cue
state as CHOP channels. Supports both timeline-driven and manual modes.

### Inputs

| Port | Type | Description |
|------|------|-------------|
| 0 | DAT | Cue table (from CueDAT) |
| 1 | CHOP (optional) | Trigger — rising edge advances cue |

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | Enum | Timeline | **Timeline** (auto by time) / **Manual** (trigger only) |
| `timeline` | String | `""` | TimelineCHOP node ID for auto mode |
| `go_next` | Pulse | — | Jump to next cue |
| `go_prev` | Pulse | — | Jump to previous cue |
| `go_to` | Int | -1 | Jump to cue by index (-1 = disabled) |
| `go_to_name` | String | `""` | Jump to cue by name |
| `apply_data` | Bool | On | Apply cue data{} overrides on change |

### Output Channels

| Channel | Description |
|---------|-------------|
| `active_cue` | Index of the currently active cue |
| `cue_progress` | 0–1 progress through the active cue's duration |
| `transition` | 0–1 transition blend value |
| `next_cue` | Index of the upcoming cue |
| `cue_elapsed` | Seconds since the active cue started |
| `cue_remaining` | Seconds until the active cue ends |

### Timeline vs Manual Mode

- **Timeline mode**: The CueCHOP reads time from a TimelineCHOP (or engine
  clock) and auto-advances cues when their trigger time is reached.
- **Manual mode**: Cues only advance via the `go_next` / `go_prev` pulses
  or a rising-edge trigger signal on input port 1.

---

## SequenceCHOP

Concatenates multiple CHOP inputs end-to-end in time. Each input plays for
a `duration` period, with optional crossfade between segments.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `duration` | Float | 2.0 | Seconds per segment |
| `crossfade` | Float | 0.0 | Blend time between segments |
| `loop` | Bool | On | Loop back to first segment |

---

## Typical Workflow

1. Add a **TimelineCHOP** — set end time to your show length
2. Add a **CueDAT** — define your cue list with names and timing
3. Add a **CueCHOP** — set `source = Timeline`, `timeline = "timeline1"`
4. Use `chop("cue1", "active_cue")` in expressions to react to cue changes
5. Enable `apply_data` on the CueCHOP to auto-apply parameter overrides

### Example: Simple 3-Cue Show

```
CueDAT "cues":
  Cue 0: "Intro"    time=0.0   duration=5.0  transition="fade:1.0"
  Cue 1: "Buildup"  time=5.0   duration=10.0 transition="fade:2.0"
  Cue 2: "Drop"     time=15.0  duration=0    transition="cut"
         data: {"noise1/scale": 5.0, "blur1/size": 0.0}

TimelineCHOP "timeline1": start=0, end=30, loop=None

CueCHOP "cue1": source=Timeline, timeline="timeline1"
```

---

## Engine Transport Controls

The toolbar transport bar provides global playback controls:

| Control | Shortcut | Description |
|---------|----------|-------------|
| Play / Pause | **Space** | Toggle global playback |
| Reset | **Escape** | Jump to frame 0 |
| Step Forward | — | Advance one frame |
| Step Backward | — | Rewind one frame |
| Speed spinner | — | 0–10× speed multiplier |
| Loop button | — | Cycle: None → Loop → Ping-Pong |
| NRT toggle | — | Non-realtime mode (fixed timestep) |

These affect the global `elapsed_time` that feeds all TimelineCHOPs
running in sync mode.
