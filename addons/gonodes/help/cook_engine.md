# Cook Engine

The GONODES cook engine is responsible for evaluating the node graph each frame,
processing only what needs to update and in the correct order.

---

## How Cooking Works

### 1. Dirty Propagation

When a parameter changes, an input updates, or time advances (for time-dependent
operators), the affected node is marked **dirty**. Dirtiness propagates downstream
through all connected nodes — if a node's input changes, it too becomes dirty.

### 2. Active Chain Resolution

Not all nodes cook every frame. The engine traces backward from **output sinks**
(WindowOUT, RenderTOP, etc.) to find all nodes that feed them. Only
these "active" nodes are candidates for cooking. Disconnected nodes and branches
that don't reach a sink are skipped entirely.

This means you can have debugging or experimental nodes in your patch that don't
impact performance unless they're connected to an output.

Some operators are **input-selective** — they only use a subset of their inputs
depending on their current state. For example, a **SwitchTOP** with `index=1`
only reads input 1, so the engine won't cook the chains feeding inputs 0, 2,
and 3. This pruning happens automatically for all Switch-type operators,
CubeMapTOP, MathCHOP (unary mode), and others.

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
| **RenderTOP** | Renders a 3D scene to a viewport texture         |
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
