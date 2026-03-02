# GONODES Player

The GONODES Player is a minimal standalone runtime that loads and runs
`.gnpatch` files without the editor UI.  It boots the cook engine,
processes the node graph, and WindowTOP nodes open their own OS windows
for visual output.


## How It Works

```
GONODESPlayer.exe
  ├── config.json        ← settings (patch path, vsync, fps)
  ├── MyShow.gnpatch     ← the patch file
  └── MyShow/            ← project assets folder (optional)
```

1. On launch, the Player reads `config.json` from next to the executable.
2. Resolves the `.gnpatch` path (relative to the exe directory).
3. **Auto-opens all WindowTOPs** — the Player forces `open = true` on every
   WindowTOP in the network so all display windows appear immediately,
   regardless of how the patch was saved in the editor.
4. Boots `GNCookEngine` with the loaded network.
5. WindowTOP nodes open their own OS windows with their configured title,
   resolution, fullscreen mode, and monitor.
6. If no WindowTOP exists, a fallback info label is shown in the main window.


## config.json Format

```json
{
  "patch": "MyShow.gnpatch"
}
```

| Field       | Type   | Default | Description                          |
|-------------|--------|---------|--------------------------------------|
| `patch`     | string | `""`    | Path to the `.gnpatch` relative to exe|

All other runtime settings (renderer, VSync, window layout) are automatic.
The renderer falls back from Forward+ to Compatibility if needed.  VSync
and display parameters are controlled by each WindowTOP in the patch.


## Command-Line Arguments

| Argument                        | Description                         |
|---------------------------------|-------------------------------------|
| `--patch <path>`                | Override the patch path from config |
| `--rendering-method <method>`   | Force a specific renderer           |

`--patch` takes priority over `config.json`.  Path can be absolute or
relative to the exe directory.

The `--rendering-method` accepts `forward_plus`, `mobile`, or
`gl_compatibility`.  See Rendering section for when to use this.


## Hotkeys

| Key  | Action                                            |
|------|---------------------------------------------------|
| Esc  | Quit the Player                                   |
| F1   | Toggle debug info overlay (frame count, cook time)|
| F11  | Toggle fullscreen on the main window              |

The debug overlay is **hidden by default**.  Press F1 to show it.


## Rendering Backend

The Player uses the same automatic renderer selection as the editor:

- **Forward+** (Vulkan / D3D12) is tried first.
- If the GPU doesn't support Vulkan, Godot automatically falls back to
  **Compatibility** (OpenGL 3.3).

This is handled by the `fallback_to_opengl3 = true` setting baked into
the Player's `.pck` file.  No user action is required.

### Why there's no renderer in config.json

The automatic fallback covers all practical scenarios:

| Machine                | What happens                        |
|------------------------|-------------------------------------|
| Modern GPU (Vulkan)    | Forward+ is used automatically      |
| Older GPU (no Vulkan)  | Compatibility (OpenGL 3.3) is used  |
| Laptop with integrated | Compatibility is used automatically |

Forcing a specific renderer in config.json would risk crashes (e.g.
requesting Forward+ on a machine without Vulkan).

### Why there's no VSync/FPS in config.json

VSync and frame-rate limiting are **per-window** settings controlled by
each WindowTOP node in the patch.  A single patch can have multiple
WindowTOPs, each with independent VSync settings.  Putting a global
VSync toggle in config.json would conflict with per-window control.


### Power-user override

If you need to force a specific renderer (e.g. for testing or to work
around a driver bug), use the command line:

```
GONODESPlayer.exe --rendering-method mobile
GONODESPlayer.exe --rendering-method gl_compatibility
```


## Window Management

The Player does **not** manage display windows directly.  Instead, each
**WindowTOP** node in the patch controls its own OS window.

On launch, the Player automatically forces **every WindowTOP to open**,
regardless of its saved `open` parameter.  In the editor, users toggle
`open` to show/hide windows while working; in the Player, every window
should always appear.

| WindowTOP Parameter | What it controls               |
|---------------------|--------------------------------|
| `title`             | Window title bar text          |
| `resolution`        | Window size (width × height)   |
| `window_mode`       | Windowed / Fullscreen / Borderless |
| `monitor`           | Which display to open on       |
| `position`          | Window position on screen      |
| `always_on_top`     | Keep window above others       |
| `vsync`             | Per-window VSync override      |

A single patch can have **multiple WindowTOPs**, each opening its own
independent window — useful for multi-display installations.

Each WindowTOP controls VSync independently via its own `vsync` parameter.


## Building a Player Package

Use the **Build** button in the GONODES editor toolbar.  This performs a
"Quick Build" that copies:

1. The Player binary + `.pck`
2. Your `.gnpatch` file
3. The project assets folder (images, videos, etc.)
4. A generated `config.json`

To the output directory you specify.  The result is a self-contained
folder you can zip and distribute.

See [EDITOR.md](EDITOR.md) for details on the Build dialog.


## File Structure

| File                         | Purpose                              |
|------------------------------|--------------------------------------|
| `scenes/player_main.gd`     | Player runtime logic                 |
| `scenes/player_main.tscn`   | Player scene (Control root)          |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic  |

## Headless / Windowless Operation

The Player doesn't require WindowTOP nodes.  Patches that only use
file-save nodes (FileSaveTOP, FileSaveDAT, MovieOutIMG, FFmpegOutIMG,
RecordCHOP) or network-output nodes (OSCOutCHOP) run headless — the
cook engine keeps their chains alive via `is_sink = true`.

For **Script operators** with side effects (HTTP, hardware control, etc.),
enable the **Force Active** toggle so the script acts as a sink:

```
ScriptCHOP  →  Force Active = ON,  Time Dependent = ON
```

This makes the script cook every frame without needing any downstream
WindowTOP, perfect for headless automation or data-processing pipelines.


## Troubleshooting

| Problem                       | Solution                              |
|-------------------------------|---------------------------------------|
| Black screen, no windows open | Ensure your patch has at least one WindowTOP — the Player auto-opens all of them |
| "No patch file specified"     | Check that `config.json` exists next to the exe and has a valid `patch` path |
| Poor performance              | Try `--rendering-method gl_compatibility` for lighter GPU load |
| Player crashes on launch      | GPU may not support Vulkan — the fallback should handle this, but try forcing Compatibility via CLI |
