# GONODES Player â€” Internals

> **Audience:** Contributors, deployment engineers, advanced users.  
> **User-facing version:** `addons/gonodes/help/player.md` (accessible via in-editor Help window)

This document covers Player runtime internals: boot sequence, WindowOUT
auto-open mechanics, headless operation, scene swap, and troubleshooting.
For basic usage (config.json, hotkeys, Quick Build), see the user-facing help.


## Boot Sequence

```
GONODESPlayer.exe
  â”œâ”€â”€ config.json        â† settings (patch path)
  â”œâ”€â”€ MyShow.gnpatch     â† the patch file
  â””â”€â”€ MyShow/            â† project assets folder (optional)
```

**Implementation (`scenes/player_main.gd`):**

1. `_ready()` reads `config.json` from `OS.get_executable_path().get_base_dir()`.
2. Resolves `.gnpatch` path (relative to exe dir). `--patch` CLI arg overrides.
3. Deserializes network via `GNNetwork.from_dict()`.
4. **WindowOUT force-open:** Iterates all nodes, finds WindowOUT instances, sets `open` parameter to `true` regardless of saved state.
5. Creates `GNCookEngine`, assigns network, enables cooking.
6. If no WindowOUT exists, shows a fallback info label in the main Control.


## config.json

> Full user-facing config docs are in `help/player.md`.

```json
{
  "patch": "MyShow.gnpatch"
}
```

Parsed by `player_main.gd::_load_config()` via `JSON.parse_string()`.
Only the `patch` field is currently used. Additional fields are silently
ignored â€” future-proof for adding e.g. `log_level`, `headless` flags.

VSync and FPS are intentionally absent â€” they're per-window settings
controlled by each WindowOUT node. A global override would conflict with
multi-window setups.


## Command-Line Arguments

| Argument                        | Description                         |
|---------------------------------|-------------------------------------|
| `--patch <path>`                | Override config.json patch path     |
| `--rendering-method <method>`   | Force a specific Godot renderer     |

CLI parsing is in `_ready()` via `OS.get_cmdline_args()`. `--patch` is
custom; `--rendering-method` is a standard Godot argument passed through.


## Hotkeys (Implementation)

Handled in `player_main.gd::_unhandled_key_input()`:

| Key | Action | Implementation |
|-----|--------|----------------|
| Esc | Quit | `get_tree().quit()` |
| F1  | Debug overlay | Toggles `_debug_label.visible` |
| F11 | Fullscreen | Toggles `DisplayServer.window_set_mode()` |


## Rendering Backend â€” Internals

The Player uses automatic renderer selection (same as the editor):
Forward+ (Vulkan/D3D12) â†’ Compatibility (OpenGL 3.3) fallback.

**Why the fallback works:** The `fallback_to_opengl3 = true` project setting
is baked into the `.pck` at export time. Godot's runtime checks GPU
capabilities at startup and selects the appropriate renderer before any
scene loads. This is a Godot engine feature â€” no GONODES code involved.

**D3D12 on Windows:** The project uses `rendering_device/driver.windows="d3d12"`
in project.godot. The D3D12 Agility SDK is bundled in the export via
`export_d3d12=1`. This ensures the D3D12 runtime works on any Windows 10/11
machine regardless of system D3D12 version.

### No renderer in config.json â€” Design Decision

A global renderer override is intentionally omitted:
- Forward+ fallback covers all practical scenarios automatically
- A user-facing config option would risk crashes (e.g. requesting Vulkan on a machine without it)
- Power users can still override via `--rendering-method` CLI

### No VSync/FPS in config.json â€” Design Decision

VSync and frame-rate are **per-window** settings controlled by each WindowOUT.
A single patch can have multiple WindowOUTs with independent VSync.
A global config toggle would conflict with per-window control.


## Window Management â€” Implementation

The Player does **not** manage display windows directly.  Each WindowOUT
creates and owns its OS window via `DisplayServer.create_sub_window()`.

**Auto-open implementation:** In `player_main.gd::_setup_network()`, after
loading the patch, the Player iterates all nodes and calls
`node.parameters["open"].set_value(true)` on every WindowOUT instance.
This is a one-time override â€” the editor's saved `open` state is ignored.

Each WindowOUT handles its own window lifecycle: creation, resize, move,
fullscreen toggle, and destruction. The Player has no window management
code beyond the initial force-open pass.

**Multi-window:** Multiple WindowOUTs each get independent OS windows.
VSync is per-window via WindowOUT's `vsync` parameter.


## Building a Player Package

> Full build details are in `BUILD.md` and the user-facing `help/building.md`.

The Quick Build (editor Build button) delegates to `GNPatchExporter` which
copies the pre-built binary + `.pck` + patch + assets + config.json to the
output directory.

Template binaries must be pre-built via `scripts/build_templates.ps1` or
`.sh`. Rebuild whenever Godot is upgraded â€” the binary and `.pck` must be
from the same Godot version.


## File Structure

| File                         | Purpose                              |
|------------------------------|--------------------------------------|
| `scenes/player_main.gd`     | Player runtime logic                 |
| `scenes/player_main.tscn`   | Player scene (Control root)          |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic  |

## Headless / Windowless Operation â€” Internals

The Player runs fine without WindowOUTs. The cook engine keeps chains alive
via the `is_sink` mechanism on file-save operators and `Force Active` scripts.

**How `is_sink` works:** During `GNCookEngine._compute_active_set()`, BFS
starts from all nodes where `is_sink == true`. This includes:
- WindowOUT (always)
- TextureSaveOUT, ImageSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, RecordOUT (always)
- OscOUT (always)
- Script operators with `Force Active = ON` (parameter-driven)

Without any sink nodes, the cook engine has an empty active set and no
nodes cook â€” the Player idles at near-zero CPU.


## Troubleshooting

| Problem                       | Solution                              |
|-------------------------------|---------------------------------------|
| Black screen, no windows open | Ensure your patch has at least one WindowOUT â€” the Player auto-opens all of them |
| "No patch file specified"     | Check that `config.json` exists next to the exe and has a valid `patch` path |
| Poor performance              | Try `--rendering-method gl_compatibility` for lighter GPU load |
| Player crashes on launch      | GPU may not support Vulkan â€” the fallback should handle this, but try forcing Compatibility via CLI |
