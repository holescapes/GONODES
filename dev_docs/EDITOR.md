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
automatically falls back to **Compatibility** (OpenGL 3.3) via the
`rendering/rendering_device/fallback_to_opengl3 = true` project setting
(enforced in `gonodes_plugin.gd`). Per-platform renderer can also be
overridden via export presets or the `--rendering-method` CLI flag.

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

### CPU Fallback Paths (✅ Implemented)

CPU fallback implementations for POP and VOL are implemented. Each POP/VOL
operator has a `_cook_cpu()` code path invoked automatically when compute
shaders are unavailable, enabling basic particle and volume workflows on
Compatibility/WebGL2 at reduced performance. See Section 34 (Mobile/Web
Export) in GONODES_CONTEXT.md for details.


## Toolbar Layout

> Full toolbar reference with controls and descriptions is in `help/editor.md`.

The bottom toolbar is split into **three rows** (two button rows plus a timeline scrubber):
- **Row 1** — File & Project (New, Open, Save, Build, NRT, FPS, InfoLabel, Debug Log, **Debug**)
- **Timeline** — Time label + scrubber slider
- **Row 2** — View & Graph (Previews, Perf, VRAM, Viewer, Stress Test, Minimap, Wire Style, Layout, Help)

Each row is wrapped in a `ScrollContainer` with `SCROLL_MODE_SHOW_NEVER`
horizontal scrolling and vertical scrolling disabled.  When the window is
narrower than the row's content, items remain accessible via
**Shift + mouse-wheel** scrolling — no buttons are clipped or pushed
off-screen.  The scrollbar itself is hidden so row height stays fixed and
the 98 px InfoBar budget is not exceeded.

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

### Parameter Row Layout

Each parameter row (`gn_param_row.gd`) in Expression mode shows:

- **Expression LineEdit** — stretch ratio 2.0, takes 2/3 of the row width.
- **Resolved value label** — stretch ratio 1.0, `SIZE_EXPAND_FILL` with
  `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS` to prevent long values
  from blowing out the panel width.

### Expression Autocomplete — Implementation

Autocomplete suggestions appear while typing expression functions
(`chop(`, `top(`, `sop(`, etc.) in both the **inline LineEdit** and
the **popup CodeEdit** editor.

#### Inline LineEdit (`gn_param_row.gd`)

The inline field uses a manually managed `PopupMenu`.

| Component | Detail |
|-----------|--------|
| `_autocomplete_popup` | `PopupMenu` created lazily on first trigger |
| `_autocomplete_target` | The `LineEdit` that opened the popup |
| `_ac_trigger_re` | Static `RegEx` matching `chop("`, `top("`, etc. before the caret |
| `_ac_second_arg_re` | Static `RegEx` matching `chop("id", "` to detect the channel-name context |

**Trigger detection** — `_check_inline_autocomplete(edit)` runs on:

- `text_changed` signal — fires as the user types.
- Arrow keys / Home / End — detected via `_on_expr_gui_input()`, then
  `_check_inline_autocomplete.call_deferred(edit)` so the caret position
  updates first.
- Mouse click in the LineEdit — same deferred path via `gui_input`.

> **Note:** Godot's `LineEdit` does **not** emit `caret_changed`.  All
> caret-movement detection goes through `gui_input` with `call_deferred`.

**Suggestion gathering:**

- **Node ID suggestions** — `_gather_node_ids(filter_family)` walks the
  network and collects node IDs, optionally filtered to a single family
  via `_fn_to_family(fn)` (e.g., `chop(` → `GNFamily.Type.CHOP`).
- **Channel name suggestions** — `_gather_chop_channels(node_id)` reads
  `node.output_ports` on the referenced CHOP node and collects port
  names.  Triggers when the caret is inside the second string argument
  (e.g., `chop("lfo1", "|"`).

**Popup display** — `_show_inline_autocomplete(edit, items, partial)`
positions the `PopupMenu` below the caret, applies a family-colored icon
to each item, and filters items by the partial string already typed.
Selecting an item inserts the text at the caret position.

#### Popup CodeEdit (`gn_expression_editor.gd`)

The popup editor uses Godot's built-in `CodeEdit` completion API.

**Problem:** `CodeEdit` suppresses `code_completion_requested` inside
string color regions added via `add_color_region("\"", "\"")`.  This
means typing `chop("` in the popup editor triggers no completion by
default.

**Fix:** `_maybe_request_completion()` is called from both
`text_changed` and `caret_changed`.  It checks `_detect_function_context()`
and, when inside a recognized expression function call, calls
`_code_edit.request_code_completion(true)` to force the completion
panel open.

### Inspector Status Label

`_status_label` in `gn_param_inspector.gd` uses `autowrap_mode =
AUTOWRAP_WORD_SMART` so that long status strings (e.g., cook error
messages) wrap within the panel instead of clipping or forcing a
horizontal scrollbar.  The status is refreshed immediately on node
selection via `_on_node_cooked`.


## Node Preview & Viewer System

### GNDataRenderer Architecture

Viewer/preview rendering is separated from data classes via `GNDataRenderer`
(`addons/gonodes/ui/renderers/gn_data_renderer.gd`) — an abstract base with
three virtuals:
- `render_for_viewer(data: GNData, viewer) -> void`
- `render_for_preview(data: GNData, host: Control) -> void`
- `handle_viewer_input(data: GNData, event: InputEvent, viewer) -> bool`

One renderer instance per data-carrying family, registered via
`renderer_script` key in `[family.*]` config sections. `GNFamily._renderer_registry`
maps family IDs to instances, populated during config loading by
`GNExtensionRegistry`.

**Design principle:** `GNData` subclasses stay editor-agnostic (zero UI
imports). Renderers live in the UI layer (`addons/gonodes/ui/renderers/`)
and know about SubViewport, controls, GNViewerRenderHelpers, etc. This
means the cook engine can run headless without pulling in viewer code.

Concrete renderers (10 total):
- `GNTextureRenderer` — TOP: `viewer.set_texture()`
- `GNImageRenderer` — IMG: `Image` → `ImageTexture` upload → `viewer.set_texture()`
- `GNChannelRenderer` — CHOP: `GNWaveformView` → `viewer.set_control()`
- `GNTableRenderer` — DAT: `Tree` spreadsheet → `viewer.set_control()`
- `GNGeoRenderer` — SOP: 3D viewport + orbit camera + mesh
- `GNParticleRenderer` — POP: 3D viewport + orbit camera + MultiMesh
- `GNVolumeRenderer` — VOL: 2×2 slice composite, scroll-to-slice
- `GNMaterialRenderer` — MAT: 3D viewport + preview sphere
- `GNCompRenderer` — COMP: text fallback (scene node info)
- `GNUIRenderer` — UI: Control duplicated into SubViewport

3D renderers (GNGeoRenderer, GNParticleRenderer, GNMaterialRenderer) own
static scene nodes (`_viewer_camera`, `_viewer_light`, `_viewer_mesh_instance`)
that are reparented into the viewer's shared 3D SubViewport on each render.

### Shared Rendering via GNViewerRenderHelpers

Common data-to-image rendering logic is available in `GNViewerRenderHelpers`
(`addons/gonodes/core/gn_viewer_render_helpers.gd`) — a static utility class.
Renderers use these helpers for default visualization. Custom operators can
bypass the helpers entirely.
Available helpers:
- SOP/POP/MAT SubViewport creation (camera, light, gizmo, environment)
- Orbit camera positioning
- Volume slice extraction (XY/XZ/YZ) and MIP projection
- CHOP waveform to CPU Image rendering
- DAT table to CPU Image rendering

Any improvement to a visualization mode (e.g. better SOP lighting,
new waveform styles, colored volume mapping) benefits both the interactive
viewer and the SnapshotTOP node automatically.

### Output-Type Dispatch (Base Class)

Both the **on-node inline preview** and the **docked viewer panel** display
content based on the **actual output data type**, not the operator family.
This means cross-family nodes automatically get the correct preview:

- A VOL operator that outputs `GNTextureData` (e.g. RaymarchVOL) shows a
  texture thumbnail, not volume stats.
- A POP operator that outputs `GNGeoData` (e.g. InstancePOP) shows vertex
  counts, not particle counts.
- An IMG operator with a CHOP on port 1 gets `GNChannelRenderer` for that
  port automatically.

The logic lives in `GNNode.create_preview_control()` and
`GNNode.update_preview_control()` — family base classes do **not** override
these unless they have non-data state to display (COMP: `_scene_node`,
UI: `_control_node`, OUT: sink status).

### Two-Tier Viewer Dispatch

The docked viewer panel is a **minimal host** — a dumb surface that provides
a TextureRect (with pan/zoom), a Control container, an info label, and a
lazy 3D SubViewport.

**Rendering dispatch:**
1. `GNNode.render_for_viewer(viewer, port_index)` — reads `get_output_data(port_index)`,
   looks up `GNFamily.get_renderer(data.get_family())`, and calls
   `renderer.render_for_viewer(data, viewer)`.
2. Individual operators (e.g. GNSDFBase, CameraComp) can override
   `render_for_viewer` directly for custom display — the override
   takes precedence over the renderer dispatch.
3. `GNViewerPanel.update_from_node()` calls `node.render_for_viewer(self, port)`.

**Input dispatch:**
1. Viewer calls `node.handle_viewer_input(event, local_pos, self, port)`.
2. If the operator override consumes it (returns `true`) — done, re-render.
3. If it returns `false`, the base implementation dispatches to
   `renderer.handle_viewer_input(data, event, viewer)` for default
   data-type interaction (orbit drag/zoom on 3D, scroll-to-slice on VOL).
4. If the renderer also returns `false`, the viewer's built-in pan/zoom runs.

Operator overrides get `viewer` and `port_index` as parameters — no need
to cache a `WeakRef` from `render_for_viewer`.

### Per-Viewer Mutable State

Orbit camera state (`orbit_yaw`, `orbit_pitch`, `orbit_distance`,
`orbit_dragging`), wireframe toggle, and volume slice state (`vol_slice_pos`,
`vol_show_mip`) are **instance variables on `GNViewerPanel`** — not static
on family bases. Each viewer panel instance is independent. `set_target()`
resets all state when switching nodes.

### Texture Overlay

`viewer.set_texture_overlay(control)` attaches a transparent Control that
draws in texture pixel space.  The overlay tracks pan/zoom automatically.
Pass `null` to remove. All input still routes through
`handle_viewer_input()` — the overlay has `MOUSE_FILTER_IGNORE`.
Helper: `viewer.local_pos_to_uv(local_pos)` converts mouse position
to 0–1 texture UV coordinates; `viewer.uv_to_local_pos(uv)` does
the reverse.  Used by projection mapping TOPs for interactive handles.

### Multi-Output Nodes

Nodes with multiple outputs (e.g. GDScriptSCRIPT Generic template, MultiBufferRenderTOP)
preview **output port 0** (`cached_output`). To inspect other outputs, wire
them into a **Null node** of the appropriate family and select that Null
node in the viewer.

Every family has a Null pass-through node: NullTOP, NullCHOP, NullSOP,
NullDAT, NullIMG, NullPOP, NullVOL, NullMAT, NullCOMP.


## Script Operators — Force Active (Implementation)

The consolidated GDScriptSCRIPT operator (with CHOP/SOP/DAT/IMG/Generic templates)
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
> with TouchDesigner/Houdini/VVVV, see `GONODES_VS_THE_REST.md`.

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

**Clipboard & multi-select:**  All three Tree tabs use `SELECT_MULTI` for
Ctrl+click / Shift+click row selection.  A toolbar above the tabs provides:
- **Copy Selected** — copies selected rows as tab-separated values (TSV)
  with column headers. Also bound to **Ctrl+C** when the panel is visible.
- **Copy All** — copies every row from the current tab.  For Active Chains,
  tree hierarchy is preserved with indentation on the first column.

Output is ready for pasting into spreadsheets, text editors, or chat.

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
  `op()`, `top()`, `sop()`, `dat()`, `mat()`, `vol()`, `img()`, `output()` calls.
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

**Only active nodes flash.**  Inactive nodes stay `dirty = true` internally
(so they cook immediately when activated), but they are excluded from the
overlay to avoid a permanent orange border on every disconnected node.

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
  `PanelContainer` with `VBoxContainer` → toolbar (`HBoxContainer` with
  "Copy Selected" + "Copy All" buttons) + `TabContainer` + `Tree` widgets.
  All trees use `SELECT_MULTI`.  Each Tree row stores the `node_id` as
  metadata for click-to-navigate.  Emits `node_selected(node_id)` on
  double-click, which the editor routes to `gn_graph_editor.scroll_to_node()`.
  Ctrl+C captured via `_unhandled_key_input()` copies selected rows as TSV.
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


## Wire Interactions — Implementation

Wire selection, deletion, and inline insertion are handled in
`gn_graph_editor.gd`.  All wire operations support full undo/redo.

### State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_selected_wires` | `Array[Dictionary]` | Currently selected wires (each dict has `from_node`, `from_port`, `to_node`, `to_port`) |
| `_wire_insert_pending` | `Dictionary` | Wire targeted for double-click insert (cleared after palette closes) |
| `_box_select_origin` | `Vector2` | Mouse-down position for box-select rectangle tracking |
| `_WIRE_HIT_DISTANCE` | `float` (10.0) | Max pixel distance for `get_closest_connection_at_point()` hit test |
| `_DISCONNECT_PORT_THRESHOLD` | `float` (6.0) | Proximity guard — disconnect requests are rejected unless the mouse is within this distance of the input port |

### Wire Click Selection

Single left-click on a wire (detected in `_gui_input`) calls
`get_closest_connection_at_point(mouse_pos, _WIRE_HIT_DISTANCE)`.  If a
wire is found:

- Without Shift: clears all selected wires, selects the clicked wire.
- With Shift: toggles the clicked wire in/out of `_selected_wires`.
- `accept_event()` is called to prevent GraphEdit's built-in
  `right_disconnects` from interpreting the click as a disconnect.

### Wire Box Selection

`_update_wire_box_selection()` tracks `_box_select_origin` on mouse-down
over empty canvas space.  On mouse-up, it builds the actual drag rectangle
and calls `get_connections_intersecting_with_rect(rect)`.  Tiny rectangles
(< 4px in either dimension) are ignored to avoid accidental selection from
simple clicks.

`_box_select_origin` is cleared when a connection drag starts
(`_on_connection_drag_started`) to prevent a stale origin from triggering
a spurious box-select that would highlight nearby wires.

### Wire Deletion

The **Delete** key is handled in `_gui_input` (fires before GraphEdit's
built-in handler consumes the event).  If `_selected_wires` is non-empty,
`_delete_selected_wires()` removes them with undo support.  Wire deletion
is also available via the context menu item `_CtxID.DELETE_WIRES`.

### Wire Highlight Rendering

`_draw_selected_wires()` renders gold highlights over selected wires.
It uses `get_connection_line(from_pos, to_pos)` to obtain the actual
bezier/straight/right-angle `PackedVector2Array`, then draws with
`draw_polyline()`.  This ensures the highlight exactly follows the current
wire style rather than drawing a straight line override.

### Double-Click Wire Insert

Double-clicking a wire calls `_begin_wire_insert(wire)`, which:

1. Stores the wire in `_wire_insert_pending`.
2. Opens the operator palette filtered to operators whose input port 0
   accepts the upstream node's output family.
3. When the user selects an operator, `_try_wire_insert_splice()`:
   - Disconnects the original wire.
   - Connects upstream → new node (port 0) → downstream.
   - Calls explicit `disconnect_node()` / `connect_node()` on GraphEdit
     to keep visual state in sync.
   - All operations are recorded in a single undo action.

### Cascade Push Animation

When a node is inserted on a wire, `_make_room_for_insert()` checks if
there's enough horizontal gap for the new node.  If not, it calls
`_cascade_push()` which recursively pushes downstream (or upstream) nodes
apart:

- Each pushed node tweens to its new position (0.25s ease-out cubic).
- Nodes that would collide with already-pushed nodes are recursively
  cascaded.
- An infinite-recursion guard (`targets.has(nid)` early return) prevents
  cycles in feedback-connected graphs.
- The function returns a `Dictionary` mapping `node_id → original_position`
  for undo.

### Undo for Position Animation

`_ur_animate_positions(positions_dict)` is recorded in the undo action
alongside the wire splice.  On undo, it tweens all affected nodes back to
their original positions rather than snapping them, giving smooth visual
feedback.

### Disconnect Proximity Guard

`right_disconnects = true` is set on the GraphEdit so users can disconnect
wires by dragging from an input port.  However, clicking mid-wire would
also trigger a disconnect.  To prevent this, `_on_disconnection_request()`
checks whether the mouse is within `_DISCONNECT_PORT_THRESHOLD` (6px) of
the input port.  Disconnects originating from mid-wire clicks are rejected.

### Right-Click Wire Context Menu

Right-clicking on a wire auto-selects it (if not already selected) and
shows context menu items including `_CtxID.DELETE_WIRES` and
`_CtxID.INSERT_NODE_ON_WIRE`.


## Shake-to-Disconnect — Implementation

Houdini-style gesture: rapidly shaking a node left-right while dragging
disconnects all its wires.  Implemented in `gn_graph_editor.gd`.

### State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_shake_last_dir` | `int` | Last horizontal direction detected (-1 or 1) |
| `_shake_reversals` | `int` | Count of direction reversals in the current window |
| `_shake_timer` | `float` | Countdown timer for the detection window |
| `_shake_triggered` | `bool` | Guard: true once shake fires to prevent re-triggering |

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `_SHAKE_REVERSAL_THRESHOLD` | 3 | Minimum direction reversals to trigger |
| `_SHAKE_TIME_WINDOW` | 0.5s | Reversals must occur within this window |
| `_SHAKE_MIN_SPEED` | 200.0 px/s | Minimum speed on dominant axis to count |

### Detection

In `_process()`, while `_node_drag_active`:
1. Track velocity on the **dominant movement axis** (whichever of X/Y has
   the larger cumulative displacement during the drag).
2. If speed ≥ `_SHAKE_MIN_SPEED` on the dominant axis and direction
   reversed, increment `_shake_reversals` and reset `_shake_timer`.
3. When `_shake_reversals` ≥ `_SHAKE_REVERSAL_THRESHOLD` within the time
   window → trigger.

### Disconnect Logic (`_perform_shake_disconnect`)

1. Collect all input and output connections for all selected nodes.
2. For each node in the middle of a chain (upstream → node → downstream),
   create **bypass reconnections** — wire upstream directly to downstream.
3. Remove all original wires via `disconnect_node()`.
4. Add bypass wires via `connect_node()`.
5. Emit `_show_toast("Shake disconnect: removed N wires")`.
6. Full undo/redo: disconnect, reconnect, and toast are recorded in a
   single `UndoRedo` action.


## Expression Reference Line Overlay — Implementation

When a node's parameter expression references another node (e.g.,
`chop("lfo1", "out") * 5.0`), a **dashed line** is drawn from the
source node to the consumer node.  These lines visualise implicit
expression dependencies that have no wire representation.

### Scanning and Data Structures

`_scan_expr_references()` runs whenever expression strings change. It
uses two regexes: one extracts the full call text (e.g., `chop("lfo1",
"out")`), and one extracts the referenced node ID.  Results are stored
in:

- `_expression_edges`: `Array` of `[source_id, consumer_id]` pairs used
  for drawing and topo-sort inclusion.
- `_expr_ref_details`: `Dictionary` mapping `"source_id→consumer_id"` to
  an `Array[String]` of full call texts (for tooltip display).

### Line Drawing

Dashed lines are drawn in `_draw()`.  Each line runs from the
**visible midpoint** of the source node to the visible midpoint of the
consumer node, clipped to the viewport rect using `_clip_line_to_rect_exit`.
Lines not intersecting the visible area are culled.

### Directional Arrow

A filled triangle arrow is drawn at the midpoint of the visible segment,
pointing from source to consumer.  The arrow is **12 px in screen space**
— its size is divided by the current zoom factor so it appears constant
regardless of zoom level.

### Hover Tooltip

Hovering over a dashed line for **2 seconds** shows a tooltip displaying
the expression call details (e.g., `chop("lfo1", "out")`).

| Component | Detail |
|-----------|--------|
| `_expr_ref_tooltip` | `PanelContainer` with a `RichTextLabel` child |
| `z_index` | 100 (renders above all nodes and wires) |
| `autowrap_mode` | `AUTOWRAP_OFF` — tooltip grows to fit content |
| `custom_minimum_size` | `Vector2(180, 0)` — minimum width |
| Hit-test distance | `_EXPR_REF_HIT_DIST_SQ` — squared pixel distance from mouse to nearest point on the **visible** line segment |

Timer logic is split into two methods:

- **`_update_expr_ref_hover()`** — called from `_gui_input` on mouse
  motion.  Performs hit-test against clipped line segments.  Resets
  the timer if the hovered edge changes.
- **`_tick_expr_ref_hover(delta)`** — called from `_process()`.
  Accumulates time on the current hovered edge.  After
  `_EXPR_REF_HOVER_DELAY` (2.0 s), shows the tooltip with the call
  details from `_expr_ref_details`.

### Helper

`_point_to_segment_dist_sq(p, a, b)` — static utility returning the
squared distance from a point to a line segment.  Used by the hover
hit-test.


## Edge-Scroll During Node Drag — Implementation

When dragging a node near any edge of the graph canvas, the canvas
auto-scrolls in that direction.  Selected nodes' `position_offset`
is shifted by `scroll_delta / zoom` so they track the scroll — the
node stays under the cursor, not behind.

Implemented in `_handle_edge_scroll()` in `gn_graph_editor.gd`.
Only active when `_node_drag_active` is true.


## Toast Notifications — Implementation

Toast notifications appear at the **center** of the graph canvas for
transient feedback.  Implemented as a `Label` child of the graph editor
with `PRESET_CENTER`, `grow_vertical = BOTH`, and `alignment = CENTER`.
Toasts auto-fade via a `Tween` (opacity 1.0 → 0.0 over ~2s).

Used by: shake-to-disconnect, paste operations, error feedback.

### Centralized Logger Integration

`GNLogger.toast_sink` is a `Callable` set by the graph editor on
`_ready()`.  When any subsystem calls `GNLogger.warn()` or
`GNLogger.error()`, the logger automatically forwards the message to
`toast_sink` (if set), surfacing warnings and errors as transient toasts
without requiring each callsite to know about the UI.


## Parameter Undo/Redo — Implementation

All parameter value changes in the inspector support undo/redo. Each
parameter widget (GNFloatField, GNIntField, CheckBox, OptionButton,
ColorPickerButton, etc.) records the old and new value through the
centralized `UndoRedo` instance. Mode changes (Constant ↔ Expression)
are also undoable.

Implementation: `gn_param_inspector.gd` wraps each control's value-changed
callback with `undo_redo.create_action()` / `add_do_method()` /
`add_undo_method()` / `commit_action()`.


## Clipboard Export & Import (Context Menu)

Four context menu items in the graph editor for sharing, importing, and debugging:

### Copy as JSON

Serializes selected nodes + their internal connections as pretty-printed JSON
to the system clipboard.  Uses `GNNode.to_dict()` for each selected node and
filters `GNNetwork.connections` to only include wires between selected nodes.

### Paste from JSON

Imports nodes from JSON text on the OS clipboard into the current network.
Accepts JSON produced by "Copy as JSON" or snippets from `.gnpatch` files.
Handles both connection key formats (`"from"/"to"` from Copy-as-JSON and
`"from_node"/"to_node"` from internal clipboard) by normalizing on paste.

Pasted nodes are centered at the mouse cursor, given deduplicated IDs
(appends `_copy` / counter), and fully undoable via Ctrl+Z.  The menu item
is grayed out when the clipboard is empty or does not start with `{`.

### Copy Debug Info

Single-node diagnostic dump.  Requires exactly one node selected.  Includes:
- `node_type`, `family`, `id`
- All parameters (name, mode, value, expression if active)
- `output_summary` (from `GNData.get_data_summary()`)
- Input and output connections
- `time_dependent`, `is_sink`, `cook_valid`, `cook_time_ms`
- `dirty` flag and any `node_warning` / `node_error` strings

### Copy Network JSON

Serializes the entire `GNNetwork.to_dict()` (all nodes, connections,
metadata, annotations) as pretty-printed JSON to clipboard.

### Implementation

All four are defined in `gn_graph_editor.gd`:
- `_CtxID.COPY_AS_JSON`, `_CtxID.PASTE_FROM_JSON`, `_CtxID.COPY_DEBUG_INFO`,
  `_CtxID.COPY_NETWORK_JSON` enum values in `_show_context_menu()`
- `_copy_selected_as_json()`, `_paste_from_json()`,
  `_copy_debug_info_to_clipboard()`, `_copy_network_json_to_clipboard()` methods
- Uses `DisplayServer.clipboard_set()` / `DisplayServer.clipboard_get()` for
  OS clipboard access


## Custom Assets — Editor Workflow

The custom asset system extends the graph editor with asset creation,
locked editing, export/import, and drag-and-drop.

### Promotion Dialog

Right-click a SubNetwork → "Promote to Custom Asset…" opens
`GNAssetPromotionDialog`. The dialog shows identity fields (name, family,
description, author, version) and a read-only summary of the SubNetwork's
spare parameters — these become the asset's public interface. No parameter
selection is needed; all spare params are promoted automatically. Zero spare
params is valid (parameterless asset).

**Implementation:** `gn_asset_promotion_dialog.gd`

### Read-Only Asset Viewing

When diving into a `GNCustomOperator` (double-click), the inner network
opens in **read-only mode**. The `GNGraphEditor.read_only` property gates
all edit operations:

| Guarded Operation | Method |
|---|---|
| Connect wires | `_on_connection_request()` |
| Disconnect wires | `_on_disconnection_request()` |
| Delete nodes | `_on_delete_nodes_request()` |
| Paste clipboard | `paste_clipboard()` |
| Add node from palette | `_on_palette_node_selected()` |
| Group into subnet | `group_selected_into_subnet()` |

A breadcrumb banner with 🔒 icon indicates locked state. The "Edit Asset
Definition" button unlocks editing after confirmation.

**Implementation:** `gn_graph_editor.gd` (`read_only` property),
`gn_editor.gd` (`_on_dive_into_requested()`, `_update_breadcrumb()`)

### Edit Asset Definition

Clicking "Edit Asset Definition" in the read-only banner calls
`begin_asset_edit()` on the GNCustomOperator and clears `read_only`.
On save, a confirmation dialog shows the instance count:

- **"Save to All N instances"** — writes changes back to the `.gnasset`
  file; all instances update on next cook.
- **"Save As New Asset…"** — saves as a new `.gnasset` with a different
  name, preserving the original.
- **"Cancel"** — discards changes.

**Implementation:** `gn_editor.gd` (`_on_edit_asset_requested()`,
`_on_asset_edit_save()`, `_do_asset_save()`)

### Make Editable (One-Way Escape Hatch)

Right-click a GNCustomOperator → "Make Editable" converts it into a plain
SubNetworkNode. The asset link is severed — the inner network becomes a
standalone copy. This is irreversible.

**Implementation:** `gn_graph_editor.gd` (`_CtxID.MAKE_EDITABLE`),
`gn_editor.gd` (`_on_make_editable_requested()`)

### Dirty Asset Interception on Graph Save

If any GNCustomOperator instance has unsaved edits when saving the graph,
a dialog intercepts the save:

- **"Save Assets & Graph"** — saves all dirty assets first, then the graph.
- **"Discard Changes & Save Graph"** — reverts dirty assets, saves graph.
- **"Cancel"** — aborts save.

**Implementation:** `gn_editor.gd` (`_find_dirty_assets()`,
`_save_to_path()`, `_do_save_to_path()`)

### Promote to Parent (Spare Param)

Right-click a parameter on a node inside a SubNetwork → "Promote to Parent
(Spare Param)" creates a spare parameter on the parent SubNetworkNode that
mirrors the current param. The inner param is auto-wired via an expression
`par("../", "spare_name")` to read from the parent spare.

This is the primary mechanism for building a custom asset's public interface.

**Implementation:** `gn_param_row.gd` (`_promote_to_parent()`,
`_is_inside_subnet()`, `_find_parent_subnet()`)

### SubNetwork Export/Import

Two new context menu items:

- **Export Sub-Network…** — saves the inner network + metadata as a
  `.gnpatch` file via FileDialog. Metadata includes `source_type`,
  `source_label`, `family`.
- **Import .gnpatch…** — loads a `.gnpatch` file and creates a
  SubNetworkNode with the loaded inner network.

**Implementation:** `gn_graph_editor.gd` (`_CtxID.EXPORT_SUBNET_PATCH`,
`_CtxID.IMPORT_SUBNET_PATCH`), `gn_editor.gd`
(`_on_export_subnet_requested()`, `_on_import_patch_requested()`)

### Drag-and-Drop from OS

`.gnpatch` and `.gnasset` files can be dragged from the OS file manager
directly onto the graph canvas:

| File Type | Action |
|-----------|--------|
| `.gnpatch` | Creates SubNetworkNode, loads inner network from file |
| `.gnasset` | Registers asset if unknown, creates GNCustomOperator instance |

**Implementation:** `gn_graph_editor.gd` (`_can_drop_data()`,
`_drop_data()`, `_drop_gnpatch()`, `_drop_gnasset()`)

### Palette Reorganization

Custom assets are organized in a dedicated "Custom" top-level palette section:

```
Custom → Family → Extension Display Name / "User" → Asset Name
```

- Extension read-only assets show a tooltip and have "Edit Asset" / "Re-promote"
  disabled in the context menu.
- Empty groups are automatically hidden.
- Custom asset items are colored gold (0.9, 0.85, 0.6).

**Implementation:** `gn_node_palette.gd` (`_populate_tree()`,
`_add_operator_item()`), `gn_extension_registry.gd`
(`get_custom_asset_registry()`, `_scan_extension_assets()`)


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
their own help patches too (see §28.10 in the context file).


## File Structure

| File                                     | Purpose                         |
|------------------------------------------|---------------------------------|
| `scenes/gn_editor.gd`                   | Main editor logic               |
| `scenes/gn_editor.tscn`                 | Editor scene layout             |
| `addons/gonodes/ui/gn_graph_editor.gd`  | Graph canvas (GraphEdit)        |
| `addons/gonodes/ui/gn_param_inspector.gd`| Right-panel parameter inspector|
| `addons/gonodes/ui/gn_numeric_field.gd`  | Shared base for numeric param widgets (GNNumericField) |
| `addons/gonodes/ui/gn_float_field.gd`    | Float param widget (GNFloatField extends GNNumericField) |
| `addons/gonodes/ui/gn_int_field.gd`      | Int param widget (GNIntField extends GNNumericField) |
| `addons/gonodes/ui/gn_export_dialog.gd` | Quick Build dialog              |
| `addons/gonodes/ui/gn_debug_panel.gd`   | Debug panel (cook chain, active chains, param refs) |
| `addons/gonodes/ui/gn_debug_overlay.gd` | Debug graph overlay (5 toggleable layers) |
| `addons/gonodes/core/gn_patch_exporter.gd`| Build/copy logic              |

---

## Known Limitations

### Multi-Monitor DPI Scaling

Godot uses `PROCESS_SYSTEM_DPI_AWARE` on Windows (reads only the primary
monitor's scale factor). It does **not** yet support per-monitor DPI
awareness (`PROCESS_PER_MONITOR_DPI_AWARE`). Moving the editor or a
WindowOUT window between monitors with different scaling percentages causes
layout scrambling in Godot's internal Control tree.

**GONODES does not manipulate DPI or `content_scale` in any way** — the
issue is entirely upstream. WindowOUT creates a plain `Window` with no DPI
overrides.

Upstream tracking:
- [godotengine/godot#56341](https://github.com/godotengine/godot/issues/56341) — root feature request (seamless multi-monitor DPI)
- [godotengine/godot#86943](https://github.com/godotengine/godot/pull/86943) — PR for `PER_MONITOR_DPI_AWARE`
- [godotengine/godot#84948](https://github.com/godotengine/godot/issues/84948) — dual-monitor resolution mismatch
- [godotengine/godot#111271](https://github.com/godotengine/godot/issues/111271) — Stretch mode + different DPI

User-facing docs: `help/troubleshooting.md` → "Multi-Monitor DPI / Scaling Issues".


## Node Search (Ctrl+F) — Implementation

Find-in-graph search overlay for locating nodes by ID or type in large
patches.  Implemented in `gn_graph_editor.gd`.

### UI

Floating `PanelContainer` at top-center of the graph canvas (`z_index 4096`).
Contains: 🔍 icon, `LineEdit` (placeholder "Search nodes…"), match count
`Label` ("3 of 12"), ✕ close button.

### Activation

- **Ctrl+F** (keyboard shortcut in `_unhandled_key_input`)
- **Right-click → "Search Nodes…"** (context menu `_CtxID.SEARCH_NODES`)

### Behaviour

1. As the user types, `_on_search_text_changed()` filters `_node_views`
   by substring match (case-insensitive) against `node.id` and
   `node.node_type`.
2. Non-matching nodes are dimmed to 25% opacity via `view.modulate`.
3. Matching node IDs are sorted alphabetically for stable navigation.
4. **Enter** → next match, **Shift+Enter** → previous match.
   Each navigation step selects the match node and centers the graph
   on it via `scroll_to_node()`.
5. **Escape** or ✕ button → close search bar, restore all node modulation.

### State Variables

| Variable | Type | Purpose |
|----------|------|--------|
| `_search_bar` | `PanelContainer` | The overlay panel |
| `_search_edit` | `LineEdit` | Text input |
| `_search_label` | `Label` | "N of M" counter |
| `_search_matches` | `Array[String]` | Node IDs matching query |
| `_search_index` | `int` | Current cursor into matches |
| `_search_dimmed` | `bool` | Whether modulation is active |


## File Parameter Dropdown — Lazy Refresh

The file dropdown (`_populate_file_dropdown` in `gn_param_row.gd`) shows
three tiers: Patch Local, Bundled, External.  The **Patch Local** section
requires `owner_node.project_dir` which is set by the cook engine during
the first cook cycle — after the inspector UI is built.

Fix: the `OptionButton.pressed` signal triggers `_populate_file_dropdown()`
on every open, ensuring `project_dir` is current.  This is a universal fix
for all families (TOP, IMG, CHOP, DAT, SOP, etc.) since the dropdown code
is in the shared `gn_param_row.gd`.
