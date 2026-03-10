# GONODES Player

The GONODES Player is a minimal standalone runtime that loads and runs `.gnpatch` files without the editor UI. It boots the cook engine, processes the node graph, and WindowOUT nodes open their own OS windows for visual output.


## How It Works

```
GONODESPlayer.exe
  â”œâ”€â”€ config.json        â† settings (patch path)
  â”œâ”€â”€ MyShow.gnpatch     â† the patch file
  â””â”€â”€ MyShow/            â† project assets folder (optional)
```

1. On launch, the Player reads `config.json` from next to the executable.
2. Resolves the `.gnpatch` path (relative to the exe directory).
3. **Auto-opens all WindowOUTs** â€” the Player forces `open = true` on every WindowOUT in the network so all display windows appear immediately, regardless of how the patch was saved in the editor.
4. Boots the cook engine with the loaded network.
5. WindowOUT nodes open their own OS windows with their configured title, resolution, fullscreen mode, and monitor.
6. If no WindowOUT exists, a fallback info label is shown in the main window.


## config.json

```json
{
  "patch": "MyShow.gnpatch"
}
```

| Field   | Type   | Default | Description                           |
|---------|--------|---------|---------------------------------------|
| `patch` | string | `""`    | Path to the `.gnpatch` relative to exe|

All other runtime settings (renderer, VSync, window layout) are automatic. The renderer falls back from Forward+ to Compatibility if needed. VSync and display parameters are controlled by each WindowOUT in the patch.


## Command-Line Arguments

| Argument                      | Description                         |
|-------------------------------|-------------------------------------|
| `--patch <path>`              | Override the patch path from config |
| `--rendering-method <method>` | Force a specific renderer           |

`--patch` takes priority over `config.json`. Path can be absolute or relative to the exe directory.

`--rendering-method` accepts `forward_plus`, `mobile`, or `gl_compatibility`.


## Player Hotkeys

| Key | Action                                             |
|-----|----------------------------------------------------|
| Esc | Quit the Player                                    |
| F1  | Toggle debug info overlay (frame count, cook time) |
| F11 | Toggle fullscreen on the main window               |

The debug overlay is hidden by default. Press F1 to show it.


## Rendering Backend

The Player uses automatic renderer selection:

- **Forward+** (Vulkan / D3D12) is tried first.
- If the GPU doesn't support Vulkan, Godot falls back to **Compatibility** (OpenGL 3.3) automatically.

This is handled by `fallback_to_opengl3 = true` baked into the Player's `.pck` file.

| Machine                | What happens                       |
|------------------------|------------------------------------|
| Modern GPU (Vulkan)    | Forward+ is used automatically     |
| Older GPU (no Vulkan)  | Compatibility (OpenGL 3.3) is used |
| Laptop with integrated | Compatibility is used automatically|

Power-user override via command line:
```
GONODESPlayer.exe --rendering-method mobile
GONODESPlayer.exe --rendering-method gl_compatibility
```


## Window Management

The Player does **not** manage display windows directly. Each **WindowOUT** node in the patch controls its own OS window.

On launch, the Player automatically forces every WindowOUT to open, regardless of its saved `open` parameter.

| WindowOUT Parameter | What it controls              |
|---------------------|-------------------------------|
| `title`             | Window title bar text         |
| `resolution`        | Window size (width Ã— height)  |
| `window_mode`       | Windowed / Fullscreen / Borderless |
| `monitor`           | Which display to open on      |
| `position`          | Window position on screen     |
| `always_on_top`     | Keep window above others      |
| `vsync`             | Per-window VSync override     |

A single patch can have **multiple WindowOUTs**, each opening its own independent window â€” useful for multi-display installations.

> VSync and frame-rate are per-window settings (not global). There's no VSync in config.json because each WindowOUT controls it independently.


## Quick Build (Creating a Player Package)

Use the **Build** button in the GONODES editor toolbar. This copies:

1. The Player binary + `.pck` (from `templates/<platform>/`)
2. Your `.gnpatch` file
3. The project assets folder (images, videos, etc.)
4. A generated `config.json`

The result is a self-contained folder you can zip and distribute.

See the **Building** help section for how to prepare Player templates.


## Headless / Windowless Operation

The Player doesn't require WindowOUT nodes. Patches that only use file-save operators (ImageSaveOUT, TextureSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, RecordOUT) or network-output nodes (OscOUT) run headless â€” the cook engine keeps their chains alive via `is_sink = true`.

For **Script operators** with side effects (HTTP, hardware control, etc.), enable the **Force Active** toggle so the script acts as a sink:

| Parameter      | Setting | Why                                      |
|----------------|---------|------------------------------------------|
| Force Active   | ON      | Keep chain alive without downstream sink |
| Time Dependent | ON      | Re-cook every frame                      |

This makes the script cook every frame without needing any downstream WindowOUT â€” perfect for headless automation or data-processing pipelines.


## Key Files

| File                                            | Purpose                     |
|-------------------------------------------------|-----------------------------|
| `scenes/player_main.gd`                        | Player runtime logic        |
| `scenes/player_main.tscn`                      | Player scene (Control root) |
| `addons/gonodes/core/gn_patch_exporter.gd`     | Quick Build copy logic      |
