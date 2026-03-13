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
- **Row 1** — File & Project (New, Open, Save, Build, NRT, FPS, InfoLabel, Debug Log)
- **Row 2** — View & Graph (Previews, Perf, VRAM, Viewer, Stress Test, Minimap, Wire Style, Layout, Help)

Implementation: `gn_editor.gd::_setup_toolbar()` builds both rows. Each
control stores its state via `_save_setting()` / `_load_setting()` for
persistence across sessions.


## Keyboard Shortcuts

> Full shortcut table is in `help/editor.md`.

Shortcuts are handled in `gn_editor.gd::_unhandled_key_input()`.  Node-level
shortcuts (B=bypass, L=lock, H=help, V=viewer) are forwarded from the
GraphEdit's key handler.  The Tab key is handled by `gn_graph_editor.gd`
to open the operator palette.


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
| `addons/gonodes/core/gn_patch_exporter.gd`| Build/copy logic              |
