# GONODES Editor — Internals

> **Audience:** Contributors and plugin developers.  
> **User-facing version:** `addons/gonodes/help/editor.md` (accessible via in-editor Help window)

This document covers editor architecture and implementation details beyond
what the user-facing help covers.  For keyboard shortcuts, toolbar layout,
and general usage, see the in-editor Help window (F1 → Editor Guide).


## Launching

Run the project in the Godot editor or launch the exported editor binary.
The main scene is `scenes/gn_editor.tscn`.


## Rendering Backend

The editor always launches with **Forward+** (Vulkan / D3D12) for the best
preview quality.  If the GPU or driver doesn't support Vulkan, Godot
automatically falls back to **Compatibility** (OpenGL 3.3) thanks to the
`fallback_to_opengl3 = true` project setting.

| Platform | Primary      | Fallback          |
|----------|-------------|-------------------|
| Windows  | D3D12       | OpenGL 3.3        |
| macOS    | MoltenVK    | OpenGL 3.3        |
| Linux    | Vulkan      | OpenGL 3.3        |

There is no manual renderer selection in the editor — it is fully automatic.
Power users can force a specific renderer from the command line:

```
godot --rendering-method mobile
godot --rendering-method gl_compatibility
```


## Compute Shader Detection & Graceful Degradation

POP operators (GPU particles via SSBO) and VOL operators (3D texture volumes)
require `RenderingDevice` compute shaders, which are only available on the
**Forward+** and **Mobile** renderers.  The **Compatibility** renderer
(OpenGL 3.3 / WebGL2) has no compute support.

GONODES detects this automatically at startup and gracefully skips
incompatible nodes instead of crashing.

### How it works

1. **`GNGpuContext.is_compute_available()`** — static one-shot probe.  Creates
   a throwaway `RenderingDevice`, caches the result (`true`/`false`), frees it.
   Called once on the first cook frame.

2. **`GNNode.requires_compute()`** — virtual method, returns `false` by default.
   Overridden to return `true` in:
   - `GNPopBase` (all POP operators)
   - `GNVolBase` (all VOL operators)
   - `ComputeShaderTOP`
   - `CompositorEffectTOP`

3. **Cook engine skip logic** (`gn_cook_engine.gd`) — before `execute_cook()`
   for each node, the engine checks `node.requires_compute()`.  If compute is
   unavailable:
   - The node is **skipped** (not cooked).
   - A yellow **⚠** warning badge appears on the node (editor mode only):
     `"Requires compute shaders (Forward+ or Mobile renderer)"`
   - `cook_error` signal fires on frame 0 with a human-readable message.
   - Downstream nodes receive `null` input — same behavior as a disconnected
     port, so the rest of the graph continues cooking normally.
   - A one-time console warning is logged at startup listing the active renderer.

4. **Zero overhead in player builds** — `editor_mode` is `false` in exported
   builds, so the warning badge and textport logging are never invoked.  The
   compute check itself is O(1) after the first frame.

### Renderer compatibility matrix

| Renderer | API | Compute Shaders | POP / VOL / ComputeShaderTOP |
|---|---|---|---|
| **Forward+** | Vulkan / D3D12 | ✅ Yes | ✅ Full support |
| **Mobile** | Vulkan / Metal | ✅ Yes | ✅ Full support |
| **Compatibility** | OpenGL 3.3 / WebGL2 | ❌ No | ⚠ Skipped with warning |

### What users see

- **Forward+ or Mobile:** Everything works.  No warnings, no badges.
- **Compatibility fallback:** POP, VOL, ComputeShaderTOP, and
  CompositorEffectTOP nodes show a yellow ⚠ badge.  All other families
  (TOP, CHOP, SOP, DAT, MAT, COMP, IMG, UI, OUT) work normally.  The
  textport log shows a one-time warning at startup.

### Future: CPU fallback paths

CPU fallback implementations for POP and VOL are on the roadmap (post-Phase 7)
but not yet implemented.  When they are, each POP/VOL operator would gain a
`_cook_cpu()` code path invoked automatically when compute is unavailable,
enabling basic particle and volume workflows on Compatibility/WebGL2 at
reduced performance.


## Toolbar Layout

> Full toolbar reference with controls and descriptions is in `help/editor.md`.

The bottom toolbar is split into **two rows**:
- **Row 1** — File & Project (New, Open, Save, Build, NRT, FPS, InfoLabel, Debug Log, **Debug**)
- **Row 2** — View & Graph (Previews, Perf, VRAM, Viewer, Stress Test, Minimap, Wire Style, Layout, Help)

The **Debug** toggle (CheckButton) activates the debug panel and graph overlay.
When enabled, four sub-toggles appear beside it: **#Order**, **Dim**,
**Dirty**, **Sinks**, **Flow** — each controlling one overlay layer independently.

Implementation: `gn_editor.gd::_setup_toolbar()` builds both rows. Each
control stores its state via `_save_setting()` / `_load_setting()` for
persistence across sessions.


## Keyboard Shortcuts

> Full shortcut table is in `help/editor.md`.

Shortcuts are handled in `gn_editor.gd::_unhandled_key_input()`.  Node-level
shortcuts (B=bypass, L=lock, H=help, V=viewer) are forwarded from the
GraphEdit's key handler.  The Tab key is handled by `gn_graph_editor.gd`
to open the operator palette.  **F2** toggles the Debug panel and overlay
(equivalent to clicking the Debug toolbar button).


## Expression Value Preview — Implementation

When a parameter is in **Expression mode** (the "E" badge), a green
`→ value` label appears in the inspector.

**Implementation detail:** The preview is updated in
`gn_param_inspector.gd::_update_expression_previews()` which is called
each cook frame.  The label reads `GNParameter.resolved_value` — this
is the last evaluated result cached by the cook engine.  Error state
(`→ err` in red) comes from `GNParameter.expression_error`.

Expression text is preserved across CONSTANT ↔ EXPRESSION mode toggles.
The `GNParameter` stores `_expression_string` separately from `_value`.
Only an explicit `reset_to_defaults()` clears the expression.


## Node Preview & Viewer System

### Output-Type Dispatch (Base Class)

Both the **on-node inline preview** and the **docked viewer panel** display
content based on the **actual output data type**, not the operator family.
This means cross-family nodes automatically get the correct preview:

- A VOL operator that outputs `GNTextureData` (e.g. RaymarchVOL) shows a
  texture thumbnail, not volume stats.
- A POP operator that outputs `GNGeoData` (e.g. InstancePOP) shows vertex
  counts, not particle counts.

The logic lives in `GNNode.create_preview_control()` and
`GNNode.update_preview_control()` — family base classes do **not** override
these unless they have non-data state to display (COMP: `_scene_node`,
UI: `_control_node`, OUT: sink status).

### Multi-Output Nodes

Nodes with multiple outputs (e.g. GenericScriptNode, MultiBufferRenderTOP)
preview **output port 0** (`cached_output`). To inspect other outputs, wire
them into a **Null node** of the appropriate family and select that Null
node in the viewer.

Every family has a Null pass-through node: NullTOP, NullCHOP, NullSOP,
NullDAT, NullIMG, NullPOP, NullVOL, NullMAT, NullCOMP.


## Script Operators — Force Active (Implementation)

All four Script operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG)
have a **Force Active** toggle.  When enabled, the node's `is_sink`
property returns `true`, which causes the cook engine to include it in
the active chain BFS even without a downstream WindowOUT or file-save node.

**Implementation in `GNCookEngine`:** During `_compute_active_set()`, BFS
starts from nodes where `is_sink == true`. Script ops with Force Active
report `is_sink = true` via their parameter callback. The cook engine
doesn't special-case scripts — it's the generic `is_sink` mechanism.


## Quick Build — Implementation Details

> User-facing Quick Build guide is in `help/building.md`.

The Build button opens `GNExportDialog` which delegates to
`GNPatchExporter` (`addons/gonodes/core/gn_patch_exporter.gd`).

**Binary search order:** The exporter looks for `GONODESPlayer` in:
1. `templates/<platform>/` (primary — built by build scripts)
2. Exe directory
3. Project root
4. `player/` subfolder
5. `build/` subfolder

**config.json generation:** The exporter writes a minimal JSON with the
patch filename. All runtime settings (renderer, VSync, FPS) are baked
into the patch and Player binary — no config overrides needed.

### Why there's no renderer / VSync / FPS limit in the Build dialog

- **Renderer**: Forward+ with automatic fallback to Compatibility (OpenGL 3.3).
  Baked into the Player's `.pck` via `fallback_to_opengl3 = true`.
- **VSync / FPS**: Controlled per-window by each WindowOUT in the patch.
  Each WindowOUT has its own `vsync` and frame-rate parameters.


## Cook Model — Deep Dive

> User-facing overview is in `help/cook_engine.md`. For cross-system comparison
> with TouchDesigner/Houdini, see `TD_HOUDINI_COMPARISON.md`.

GONODES uses a **demand-driven flat-pass** cook architecture — a hybrid of
push and pull that avoids unnecessary work while keeping execution simple.

Each frame, the cook engine:

1. Marks time-dependent nodes dirty
2. Propagates dirty flags downstream in one pass
3. Computes the **active chain** — only nodes feeding a live sink (viewer,
   WindowOUT, `is_sink` operator) via BFS upstream from sinks
4. Cooks dirty + active nodes in topological order (single linear pass)
5. Skips everything else — inactive subgraphs and clean nodes are untouched

This achieves the same lazy evaluation as pull-based systems (Houdini,
TouchDesigner) without recursive descent — no deep call stacks, predictable
timing, and correct GPU render ordering in a single frame.

| Scenario | Cooked? |
|----------|--------|
| Node feeding a viewer | Yes (if dirty) |
| Disconnected subgraph | No (not in active chain) |
| Clean node (no inputs changed) | No (dirty = false) |
| Non-time-dependent, no param change | No (not marked dirty) |
| Bypassed node | Pass-through only (no `_cook()`) |


## Debug Window & Graph Overlay

The debug system gives real-time visibility into the cook engine's internal
state directly from the editor.  It consists of two components: a **docked
panel** below the graph canvas and a **graph overlay** drawn on top of the
nodes.

### Activating Debug Mode

- **Toolbar:** Click the **Debug** toggle (Row 1) or press **F2**.
- **Per-layer toggles:** When Debug is on, five sub-toggles appear:
  `#Order` · `Dim` · `Dirty` · `Sinks` · `Flow`.  Each controls one overlay layer
  independently — think of them as map layers you can turn on or off.
- **State persistence:** Debug toggle and individual layer states are saved
  to `user://gonodes_settings.cfg` and restored on next launch.

### Debug Panel (3 Tabs)

The panel (`GNDebugPanel`) docks below the graph canvas and updates every
6 frames (throttled to avoid UI overhead).  Only the currently visible tab
is refreshed.

#### Tab 1 — Cook Chain

| Column | Description |
|--------|-------------|
| **#** | Topological order index (cook execution order) |
| **Node** | Node ID — double-click to select and scroll the graph to it |
| **Family** | Operator family, color-coded (TOP, CHOP, SOP, etc.) |
| **Status** | `✓ cooked`, `— cached`, `✗ error`, or `inactive` |
| **Cook (ms)** | Per-node cook time. Green < 1 ms, yellow < 5 ms, red ≥ 5 ms |
| **Active** | Whether the node is in the current active chain |

Inactive nodes are dimmed in the table.  Click the "Sort by Time" option
to surface the most expensive nodes.

**Use case — Performance profiling:** Open the Cook Chain tab to see which
nodes are taking the longest.  Sort by cook time to find bottlenecks.  If a
node shows "cached" it was clean this frame and did zero work.  Nodes marked
"inactive" are in disconnected subgraphs — they consume no cook time at all.

#### Tab 2 — Active Chains

A tree rooted at each **sink** node (WindowOUT, viewers, Force Active
nodes).  Expanding a sink reveals all its upstream dependencies as a
hierarchical tree:

```
▼ window1 (WindowOUT)  0.12 ms
  ▼ comp1 (CompositeTOP)  2.31 ms
    ▼ noise1 (NoiseTOP)  ⟳  0.45 ms
    ▼ text1 (TextTOP)  cached
```

- `⟳` marks time-dependent nodes (they re-cook every frame).
- Each row shows family color and cook time.
- Cached nodes (not dirty, zero cook time) show "cached" instead of 0.00 ms.

**Use case — Understanding data flow:** When you have complex patches with
multiple sinks, this tab shows exactly which nodes feed each output.  If
a WindowOUT is showing stale data, check whether the expected upstream chain
is present.  Missing a node?  It's probably not connected or bypassed.

#### Tab 3 — Parameter References

| Column | Description |
|--------|-------------|
| **Source Node** | The node that owns the parameter with an expression |
| **Parameter** | The parameter name |
| **Expression** | The expression text |
| **References** | Node IDs referenced (e.g., `→ lfo1, noise1`) |
| **Eval (μs)** | Expression evaluation time in microseconds |

Scans all expression-mode parameters and extracts:
- **Read references:** `par()`, `chop()`, `chopf()`, `chopi()`, `chops()`,
  `op()`, `top()`, `sop()`, `dat()`, `mat()` calls.
- **Write references:** `set_par()` calls that modify parameters on other
  nodes.

**Use case — Debugging expressions:** If a parameter isn't updating as
expected, open this tab to verify which nodes it references.  Check the
evaluation time — if it's unusually high, the expression may be doing
expensive work every frame.  Double-click any row to select and scroll to
the source node.

### Graph Overlay (5 Layers)

The overlay (`GNDebugOverlay`) draws directly on the graph canvas, on top
of the nodes and wires.

#### Layer 1 — Cook Order Badges (`#Order`)

A small black pill with `#N` at the top-left of each node showing its
topological cook order.  `#1` cooks first, `#N` cooks last.

**Use case:** Verify that nodes cook in the order you expect.  If a
downstream node has a lower number than its input, there's a graph topology
problem.

#### Layer 2 — Active Chain Dimming (`Dim`)

Nodes **not** in the active chain are drawn at 40% opacity.  Active nodes
remain fully opaque.

**Use case:** Instantly see which parts of your graph are actually being
cooked.  Greyed-out nodes are disconnected from any sink and doing nothing.
Useful for identifying orphaned subgraphs or confirming that bypass is
working correctly.

#### Layer 3 — Dirty Propagation Flash (`Dirty`)

Nodes that were marked dirty this frame get an **orange border flash** that
fades out over ~0.3 seconds.  You see the "dirty wave" ripple downstream
from whatever triggered it — a parameter change, a time-dependent node
ticking, or an expression reevaluation.

**Use case:** The #1 debugging question in any node graph is "why is this
node cooking?"  Dirty propagation directly answers that.  When you change a
parameter on one node and see orange borders ripple through half the graph,
you understand the blast radius.  If a node is cooking every frame but you
don't expect it to, watch for what's marking it dirty — likely a
time-dependent upstream node.

#### Layer 4 — Sink Labels (`Sinks`)

Each sink node gets a **colored halo ring** (cycling through cyan, orange,
green, magenta, yellow).  Every upstream node in that sink's chain gets a
small **colored dot** matching its sink.

**Use case:** When you have multiple output paths (e.g., two WindowOUTs
driving different displays), this layer shows which nodes belong to which
output.  Nodes feeding multiple sinks get multiple colored dots.

#### Layer 5 — Data Flow Annotations (`Flow`)

Small labels at the midpoint of each wire showing the **data dimensions**
flowing through that connection.  Labels are color-coded by family.

| Data Type | Label Format | Example |
|-----------|-------------|---------|
| TOP (texture) | `W×H` | `512×512` |
| IMG (cpu image) | `W×H` | `256×256` |
| CHOP (channels) | `Nch` or `Nch×L` | `3ch×128` |
| SOP (geometry) | `Nv` | `2400v` |
| DAT (table) | `R×C` | `10×5` |

Single-sample CHOP channels (length=1) show just `3ch` without the sample
count.

**Use case:** Instantly see what data is flowing through every wire without
clicking individual nodes.  Spot resolution mismatches (a 1024×1024 texture
feeding into a 256×256 composite), find surprisingly large CHOP channels, or
verify that a SOP is producing the expected vertex count.

### Implementation Details

- **Panel:** `GNDebugPanel` (`addons/gonodes/ui/gn_debug_panel.gd`) — 3-tab
  `PanelContainer` with `TabContainer` + `Tree` widgets.  Each Tree row
  stores the `node_id` as metadata for click-to-navigate.  Emits
  `node_selected(node_id)` on double-click, which the editor routes to
  `gn_graph_editor.scroll_to_node()`.
- **Overlay:** `GNDebugOverlay` (`addons/gonodes/ui/gn_debug_overlay.gd`) —
  `Control` node added as child of `GraphEdit`.  Uses `_draw()` for badges,
  dirty flash borders, data flow pills, and sink halos.  Active dimming
  modifies `GNNodeView.modulate` directly (reset to `Color.WHITE` when debug
  mode is disabled).
- **Cook engine integration:** `GNCookEngine.last_topo_order` caches the
  topological sort result each frame.  The overlay and panel read this
  property — they never modify engine state.
- **Dirty flash:** `_dirty_flash` dictionary maps `node_id → alpha` (1.0 →
  0.0).  Each frame, newly dirty nodes are set to 1.0, then all entries
  fade by `delta * 3.3`.  Orange border rect drawn with fading alpha.
- **Data flow labels:** Each wire is annotated by reading
  `from_node.get_output_data(port)` and formatting the result based on
  data type (resolution, channel count, vertex count, table dimensions).
- **Coordinate conversion:** `_graph_to_overlay()` converts graph-space
  coordinates (node `position_offset`) to overlay screen space, accounting
  for zoom and scroll offset.
- **Editor/engine separation:** Both debug files live in `ui/`.  They import
  nothing from `core/` at the module level — references to `GNCookEngine`
  and `GNNetwork` are set at runtime by `gn_editor.gd`.  Hard Rule 25.20
  is fully respected.


## Settings Persistence

Editor state is saved to `user://gonodes_settings.cfg` via
`_save_setting()` / `_load_setting()`.  Persisted values include:

- Toggle states (Previews, Perf, Log, NRT)
- NRT target FPS
- Split container offsets (panel sizes)
- Last opened patch path


## Help System — Architecture

Every operator has built-in help accessible via the **`?` button** or
right-click → **Help**.  The system has two layers:

### Per-Node Help Window (`gn_help_window.gd`)

Auto-generates docs from operator metadata:
- `node_description` → description text
- `input_ports` / `output_ports` → port table (name, family, description)
- `parameters` Dictionary → parameter table (type, default, range, tooltip)
- `.gnpatch` files from `addons/gonodes/help/<family>/` → "Open Example" buttons

Discovery is automatic — scans help directories at runtime, no manifest.

### Main Help Window (`gn_main_help_window.gd`)

Centralized reference hub (F1 or toolbar "📖 Help"):
- HSplitContainer: sidebar Tree (240px, searchable) + RichTextLabel content pane
- Markdown files rendered to BBCode via `GNMarkdownRenderer`
- Operator tree built dynamically from `GNExtensionRegistry.get_operator_registry_sectioned()`
- 7 guide .md files at `addons/gonodes/help/` root + per-operator `.gnpatch` files in family subfolders

### Example Patch Coverage

| Family | Patches | Coverage |
|--------|---------|----------|
| CHOP   | 61      | All CHOP types |
| TOP    | 58      | All TOP types  |
| SOP    | 39      | All SOP types  |
| DAT    | 28      | All DAT types  |
| COMP   | 17      | All COMP types |
| MAT    | 7       | All MAT types  |

### New Operator Requirement

Every new operator must include at least one help example patch
(Hard Rule 25.21 in `GONODES_CONTEXT.md`). Extensions should include
their own help patches too (see Â§28.10 in the context file).


## File Structure

| File                                     | Purpose                         |
|------------------------------------------|---------------------------------|
| `scenes/gn_editor.gd`                   | Main editor logic               |
| `scenes/gn_editor.tscn`                 | Editor scene layout             |
| `addons/gonodes/ui/gn_graph_editor.gd`  | Graph canvas (GraphEdit)        |
| `addons/gonodes/ui/gn_param_inspector.gd`| Right-panel parameter inspector|
| `addons/gonodes/ui/gn_export_dialog.gd` | Quick Build dialog              |
| `addons/gonodes/ui/gn_debug_panel.gd`   | Debug panel (cook chain, active chains, param refs) |
| `addons/gonodes/ui/gn_debug_overlay.gd` | Debug graph overlay (5 toggleable layers) |
| `addons/gonodes/core/gn_patch_exporter.gd`| Build/copy logic              |
