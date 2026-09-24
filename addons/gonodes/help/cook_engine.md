# Cook Engine

The GONODES cook engine is responsible for evaluating the node graph each frame,
processing only what needs to update and in the correct order.

---

## How Cooking Works

### 1. Dirty Propagation

When a parameter changes, an input updates, or time advances (for time-dependent
operators), the affected node is marked **dirty**. After a node successfully cooks,
the engine marks only its immediate downstream successors dirty — propagation stops
when a node does not cook, and cascades one hop at a time as the cook loop proceeds.

### 2. Active Chain Resolution

Not all nodes cook every frame. The engine traces backward from **output sinks**
(WindowOUT, etc.) to find all nodes that feed them. Only
these "active" nodes are candidates for cooking. Disconnected nodes and branches
that don't reach a sink are skipped entirely.

This means you can have debugging or experimental nodes in your patch that don't
impact performance unless they're connected to an output.

Some operators are **input-selective** — they only use a subset of their inputs
depending on their current state. For example, a **SwitchTOP** with `index=1`
only reads input 1, so the engine won't cook the chains feeding inputs 0, 2,
and 3. This pruning happens automatically for all Switch-type operators,
CubeMapTOP, MathCHOP (unary mode), and others.

#### Switch Transition Behavior (1-Frame Hold)

When an expression or CHOP drives a Switch node's `index` parameter and the
value changes, the newly-selected input chain may not have been cooked yet —
it was pruned as inactive at the start of the frame. In this case, the Switch
outputs its **previous frame's result** (a freeze-frame hold) for exactly
**one frame** while the engine reorganizes the active chain. On the next frame,
the new chain is live and the Switch outputs fresh data.

**Why this happens:** The engine decides which chains to cook *before* cooking
begins (step 2 above), using the last-known value of each routing parameter.
When a value changes mid-cook, the newly-needed chain wasn't scheduled. Rather
than re-cooking the entire frame (which could double frame time and risk
infinite loops), the engine holds the previous output for one frame and
rebuilds the active set for the next frame.

**Is this noticeable?** At 60 fps this is a 16 ms hold — imperceptible to the
human eye and inaudible in audio. TouchDesigner uses the same approach for the
same reason: active chain pruning is critical for realtime performance, and the
1-frame hold is the minimal cost of that optimization. Without pruning, every
Switch would cook *all* of its input chains every frame, wasting significant
GPU/CPU time on branches that aren't even visible.

**When it matters:**

- **Live performance / interactive use:** You will never notice it.
- **Frame-perfect recording:** Use **NRT mode** (Non-Realtime). NRT guarantees
  every frame is fully evaluated regardless of wall-clock time, so the hold
  frame still renders correctly — downstream sees a valid image, not a gap.
- **Manual parameter changes** (clicking the inspector, using the Take system):
  These changes happen *before* the cook starts, so there is **no lag** — the
  active set is rebuilt immediately. The 1-frame hold only applies to
  expression/CHOP-driven routing changes that resolve during the cook.

#### Using a Switch as a Programmatic Gate

Switch nodes can deactivate entire upstream chains — the cook engine skips
all nodes feeding an unselected input. This makes Switch the primary tool for
programmatic branching.

There are two distinct behaviors depending on the **Null on Missing** parameter:

**`Null on Missing` = OFF (default) — performance gate with freeze-frame:**

The Switch holds the previous frame when the selected input has no data.
Upstream chains are still pruned (the cook engine skips them), so you save
CPU/GPU cost. But downstream nodes continue to receive the last valid output —
a freeze-frame, not null.

```
[NullTOP (no input)] ─ port 0 ─→ SwitchTOP ─→ downstream
[Your real chain]    ─ port 1 ─→↗
                         index = chop("control", "control:active")
```

- `index=0` → upstream pruned, Switch outputs freeze-frame (last texture)
- `index=1` → real chain cooks, Switch outputs live data
- Switching between ports → smooth 1-frame hold, no flash

Use this when you want to **save performance** while keeping a clean visual
(e.g., freeze the last frame of a video effect while it's not needed). The
chain is off from the cook engine's perspective, but downstream still sees
something.

**`Null on Missing` = ON — true null gate:**

The Switch outputs null when the selected input has no data. Downstream nodes
receive nothing — the chain is truly dead.

```
[Chain A] ─ port 0 ─→ SwitchTOP (null_on_missing=true) ─→ downstream
[Chain B] ─ port 1 ─→↗
(port 2 is empty)
```

- `index=0` → Chain A → live data
- `index=1` → Chain B → live data
- `index=2` → empty port → **null** (downstream gets nothing)

This is a true gate: set the index past the last connected input, or wire a
disconnected Null node to a port and switch to it. Downstream receives null
and can react accordingly (e.g., WindowOUT hides the panel, CompositeTOP
skips the layer).

**Tradeoff:** With `Null on Missing` on, switching between two **valid** chains
also produces a 1-frame null while the new chain activates. For live visuals
this may cause a single-frame flash; for data processing (CHOP, DAT, SOP)
it's usually fine.

**Switch nodes are available in every family:** TOP, CHOP, SOP, DAT, COMP,
IMG, POP, VOL, MAT, UI, and SDF.

### 3. Topological Sort

Active dirty nodes are sorted in **topological order** so that upstream nodes
cook before downstream ones. This guarantees that when a node reads its inputs,
those inputs have already been updated for the current frame.

### 4. Cook Execution

Each node's `cook()` method is called with a **cook context** containing:

| Field   | Type   | Description                                |
|---------|--------|--------------------------------------------|
| `time`  | float  | Seconds since the cook engine started      |
| `frame` | int    | Current frame number                       |
| `dt`    | float  | Delta time for this frame (seconds)        |

The node reads its inputs, processes data, and writes to its outputs.

---

## Time & Frames

- **time** — Seconds elapsed since the cook engine started (resets on Reset)
- **frame** — Monotonically increasing frame counter (resets on Reset)
- **dt** — Delta time for the current frame
- **NRT mode** — Non-Realtime mode uses a fixed timestep for deterministic,
  frame-perfect output. Toggle it on the toolbar and set the target FPS.

---

## Output Sinks

Output sinks are the "endpoints" of your graph — they trigger the active chain:

| Sink          | Purpose                                          |
|---------------|--------------------------------------------------|
| **WindowOUT** | Displays a texture in a standalone OS window   |
| **WindowOUT** | Opens a separate OS window showing the texture   |

Any TOP that feeds into these sinks becomes part of the active chain.

---

## Performance

### Per-Node Cook Times

Enable the **Perf** toggle in the toolbar to display per-node cook time overlays
directly on the graph. This helps identify bottlenecks.

### VRAM Monitoring

Enable the **VRAM** toggle to see GPU memory usage in the info bar.

### Optimization Tips

- **Bypass** expensive nodes with **B** to isolate performance issues
- **Lock** nodes with **L** to prevent accidental parameter changes during profiling
- Reduce TOP resolutions (width/height) where full resolution isn't needed
- Use the **Active Chain** visualization to verify only necessary nodes are cooking
- NoiseTOP and shader-based TOPs run on the GPU — they're generally fast
- ScriptCHOP/DAT/SOP/IMG run on the CPU — heavy computation here affects framerate
- **Multi-output nodes** (BlobTrackIMG, MovieFileInTOP, etc.) automatically skip secondary-port work when that port has no demand. Demand is detected from wires, wireless Select operators, and expression references (`chop()`, `top()`, `dat()`, etc.). Only connect or reference ports you actually need

---

## Errors & Warnings

During each cook cycle, the engine clears `node_error` and `node_warning` on
every node, then re-sets them if a problem occurs. The editor displays these as
**ERR** (red) and **WRN** (yellow) badges on the node's title bar.

- **Errors** mean the node cannot produce valid output (runtime crash, shader
  compile failure, missing operator). Downstream nodes receive null.
- **Warnings** mean the node works but something is degraded (missing native
  library, CPU fallback active, device open failure, renderer limitation).

Badges disappear automatically when the problem is resolved. Hover over a badge
to see the full message. See [Troubleshooting](troubleshooting.md#node-errors--warnings)
for detailed tables of every error and warning trigger.

---

## Bypass & Lock

### Bypass (B key)

A bypassed node passes its first input through unchanged, skipping its own
processing. The node shows a ⏩ indicator and dims its appearance. Useful for:

- A/B testing the effect of a node
- Temporarily disabling expensive processing
- Debugging by removing a node from the chain without disconnecting

### Lock (L key)

A locked node becomes read-only. The inspector dims all parameters and disables
editing. The node shows a ?? indicator. Useful for:

- Preventing accidental changes during performance testing
- Freezing a node's state for comparison
- Protecting reference setups

---

## Non-Realtime (NRT) Mode

NRT mode replaces the variable-framerate real-time clock with a fixed timestep.
This is essential for:

- **Deterministic output** — same input always produces the same result
- **Frame-perfect recording** — every frame is rendered regardless of real clock
- **Slow-motion / fast-motion** — decouple simulation time from wall time

Toggle NRT on the toolbar and set the target FPS with the spinner.
