# GONODES Editor

The GONODES Editor is a full Godot 4.6 application that provides a visual
node-based programming environment inspired by TouchDesigner.


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


## Toolbar Layout

The bottom toolbar is split into **two rows** for readability:

### Row 1 — File & Project

| Control     | Description                                |
|-------------|--------------------------------------------|
| New         | New empty patch (Ctrl+N)                   |
| Open        | Open a `.gnpatch` file (Ctrl+O)            |
| Save        | Save current patch (Ctrl+S)                |
| Save As     | Save as new file (Ctrl+Shift+S)            |
| Build       | Open the Quick Build dialog                |
| NRT         | Toggle Non-Realtime mode                   |
| FPS spin    | NRT target frame rate (1–240)              |
| InfoLabel   | Status / frame info (right-aligned)        |
| Debug Log   | Toggle the debug log panel                 |

### Row 2 — View & Graph

| Control     | Description                                |
|-------------|--------------------------------------------|
| Previews    | Show/hide inline node texture previews     |
| Perf        | Show/hide per-node cook-time overlay       |
| VRAM        | Show GPU memory usage in the info bar      |
| + Viewer    | Open a floating viewer for the selected TOP|
| Stress Test | Generate a 55+ node stress-test network    |
| Minimap     | Toggle GraphEdit minimap (M)               |
| Wire Style  | Cycle wire rendering style (W)             |
| Layout      | Auto-layout all nodes (Ctrl+L)             |


## Keyboard Shortcuts

| Key              | Action                                     |
|------------------|--------------------------------------------|
| Ctrl+N           | New patch                                  |
| Ctrl+O           | Open patch                                 |
| Ctrl+S           | Save patch                                 |
| Ctrl+Shift+S     | Save patch as…                             |
| Ctrl+L           | Auto-layout nodes                          |
| M                | Toggle minimap                             |
| W                | Cycle wire style                           |
| Backspace        | Navigate out of sub-network                |
| Tab              | Open operator palette                      |
| Right-click      | Context menu (on node or canvas)           |


## Expression Value Preview

When a parameter is in **Expression mode** (the "E" badge), a green
`→ value` label appears to the right of the expression text field,
showing the current resolved value in real time.

- Updates every cook frame
- Shows `→ err` in red if the expression has an error
- Hover the label for the full untruncated value
- Works for both scalar parameters and per-component expressions
  (Vector2, Vector3, Color, etc.)

This makes it easy to verify what your expression evaluates to without
needing to wire up a debug viewer.

**Expression text is preserved** when you toggle a parameter from
Expression → Constant → Expression.  Switching to Constant only changes
the mode — the expression string stays intact and is restored (and
recompiled) when you switch back.  Only an explicit **Reset** clears
the expression.


## Script Operators — Force Active

All four Script operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG)
have a **Force Active** toggle.  When enabled, the script becomes a
structural sink — the cook engine keeps its upstream chain alive even
without a downstream WindowTOP or file-save node.

This is essential for **headless / side-effect scripts** that:

- Send OSC, HTTP, or MIDI messages
- Write files or control external hardware
- Run in the Player without any display windows

| Parameter        | Default | Description                                          |
|------------------|---------|------------------------------------------------------|
| Time Dependent   | Off     | Re-cook every frame                                  |
| Cook Once        | Off     | Pulse: cook once then auto-reset                     |
| Force Active     | Off     | Keep chain alive without a downstream sink            |

Combine `Force Active` + `Time Dependent` for a script that fires every
frame regardless of what else is in the patch.


## Quick Build (Export Dialog)

Press **Build** in the toolbar to open the export dialog.  It contains:

| Setting            | Description                                      |
|--------------------|--------------------------------------------------|
| Output Directory   | Folder where the build is written                |

The dialog defaults the output directory to `<patch_name>_build/` next to
the `.gnpatch` file.

**What Build does:**

1. Locates the pre-built `GONODESPlayer` binary (searches `templates/<platform>/`,
   the exe directory, project root, `player/`, and `build/` subfolders)
2. Copies it + its `.pck` to the output folder
3. Copies the `.gnpatch` file
4. Copies the project assets folder (if one exists)
5. Writes `config.json` with the patch filename
6. Reports success or failure in the progress label

### Building Templates

Player binaries are built ahead of time using the build scripts and stored
in `templates/<platform>/`.  Re-run whenever you upgrade Godot or make a
GONODES release.

```powershell
# Windows (PowerShell)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe" -Platforms "all"
```
```bash
# Linux / macOS (Bash)
./scripts/build_templates.sh --godot /path/to/godot --platforms all
```

See [BUILD.md](BUILD.md) for the full Build System documentation, including
release-build optimizations, CI setup, and troubleshooting.

### Why there's no renderer / VSync / FPS limit in the Build dialog

All runtime settings are handled automatically:

- **Renderer**: Forward+ with automatic fallback to Compatibility (OpenGL 3.3).
  Baked into the Player's `.pck` via `fallback_to_opengl3 = true`.
- **VSync / FPS**: Controlled per-window by each WindowTOP in the patch.
  Each WindowTOP has its own `vsync` and frame-rate parameters.


## Cook Model

GONODES uses a **demand-driven flat-pass** cook architecture — a hybrid of
push and pull that avoids unnecessary work while keeping execution simple.

Each frame, the cook engine:

1. Marks time-dependent nodes dirty
2. Propagates dirty flags downstream in one pass
3. Computes the **active chain** — only nodes feeding a live sink (viewer,
   WindowTOP, `is_sink` operator) via BFS upstream from sinks
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


## File Structure

| File                                     | Purpose                         |
|------------------------------------------|---------------------------------|
| `scenes/gn_editor.gd`                   | Main editor logic               |
| `scenes/gn_editor.tscn`                 | Editor scene layout             |
| `addons/gonodes/ui/gn_graph_editor.gd`  | Graph canvas (GraphEdit)        |
| `addons/gonodes/ui/gn_param_inspector.gd`| Right-panel parameter inspector|
| `addons/gonodes/ui/gn_export_dialog.gd` | Quick Build dialog              |
| `addons/gonodes/core/gn_patch_exporter.gd`| Build/copy logic              |
