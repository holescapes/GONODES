# GONODES Player — Internals

> **Audience:** Contributors, deployment engineers, advanced users.  
> **User-facing version:** `addons/gonodes/help/player.md` (accessible via in-editor Help window)

This document covers Player runtime internals: boot sequence, WindowOUT
auto-open mechanics, headless operation, scene swap, and troubleshooting.
For basic usage (config.json, hotkeys, Quick Build), see the user-facing help.


## Boot Sequence

```
GONODESPlayer.exe
  ├── config.json        ← settings (patch path)
  ├── MyShow.gnpatch     ← the patch file
  └── MyShow/            ← project assets folder (optional)
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
> A companion `CONFIG_OPTIONS.txt` is generated alongside config.json during export.

```json
{
  "patch": "MyShow.gnpatch",
  "renderer": "forward_plus",
  "settings": {
    "log_level": 1,
    "log_to_file": false,
    "parallel_cook_enabled": false,
    "max_cooks_per_frame": 0
  }
}
```

Parsed by `player_main.gd::_parse_config()` via `JSON.parse()`.

| Field | Read by | Effect |
|-------|---------|--------|
| `patch` | `_parse_config()` | Resolved relative to exe dir |
| `patch_url` | `_parse_config()` | Web builds — fetched via HTTP |
| `renderer` | `_check_renderer_mismatch()` | If active renderer doesn't match, Player re-launches with `--rendering-method` |
| `settings.log_level` | `_apply_runtime_settings()` | Sets `GNLogger.level` |
| `settings.log_to_file` | `_apply_runtime_settings()` | Enables file logging |
| `settings.parallel_cook_enabled` | `_apply_runtime_settings()` | Sets `cook_engine.parallel_cook_enabled` |
| `settings.max_cooks_per_frame` | `_apply_runtime_settings()` | Sets `cook_engine.max_cooks_per_frame` |

VSync and FPS are intentionally absent — they're per-window settings
controlled by each WindowOUT node. A global override would conflict with
multi-window setups.


## Command-Line Arguments

| Argument                        | Description                         |
|---------------------------------|-------------------------------------|
| `--patch <path>`                | Override config.json patch path     |
| `--rendering-method <method>`   | Force a specific Godot renderer     |
| `--log-level <0-3>`            | Override log level                  |
| `--log-file [path]`            | Enable file logging                 |
| `--parallel-cook`              | Enable parallel cooking             |
| `--max-cooks <N>`              | Override max cooks per frame        |

CLI parsing is in `_parse_config()` via `OS.get_cmdline_args()`. All CLI
args override config.json values.


## Hotkeys (Implementation)

Handled in `player_main.gd::_unhandled_key_input()`:

| Key | Action | Implementation |
|-----|--------|----------------|
| Esc | Quit | `get_tree().quit()` |
| F1  | Debug overlay | Toggles `_debug_label.visible` |
| F11 | Fullscreen | Toggles `DisplayServer.window_set_mode()` |


## Rendering Backend — Internals

### Renderer selection flow

1. The renderer is chosen in the GONODES editor (Preferences > Renderer or
   Export Patch dialog). Both write the value to persistent storage.
2. The exporter writes `"renderer": "<value>"` into `config.json`.
3. On Player startup, `_check_renderer_mismatch()` compares `config.json`'s
   `renderer` against `GNGpuContext.get_current_renderer()`.
4. If they differ, the Player spawns a new process with
   `--rendering-method <desired>` and quits. A `--renderer-set` sentinel
   flag prevents infinite relaunch loops.
5. `GNCookEngine` reads the active renderer via `GNGpuContext` and skips
   nodes whose `supported_renderers()` doesn't include it.

### Renderer values

| Value | Godot renderer | GPU API |
|-------|---------------|---------|
| `forward_plus` | Forward+ | Vulkan / D3D12 |
| `mobile` | Mobile | Vulkan (mobile profile) |
| `gl_compatibility` | Compatibility | OpenGL ES 3.0 / WebGL2 |

### Automatic fallback

`fallback_to_opengl3 = true` is baked into the `.pck` at export time.
If Vulkan isn't available, Godot falls back to Compatibility automatically.

### D3D12 on Windows

`rendering_device/driver.windows="d3d12"` in project.godot. The D3D12
Agility SDK is bundled via `export_d3d12=1`.

### No VSync/FPS in config.json — Design Decision

VSync and frame-rate are **per-window** settings controlled by each WindowOUT.
A single patch can have multiple WindowOUTs with independent VSync.
A global config toggle would conflict with per-window control.


## Window Management — Implementation

The Player does **not** manage display windows directly.  Each WindowOUT
creates and owns its OS window via `DisplayServer.create_sub_window()`.

**Auto-open implementation:** In `player_main.gd::_setup_network()`, after
loading the patch, the Player iterates all nodes and calls
`node.parameters["open"].set_value(true)` on every WindowOUT instance.
This is a one-time override — the editor's saved `open` state is ignored.

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
`.sh`. Rebuild whenever Godot is upgraded — the binary and `.pck` must be
from the same Godot version.


## File Structure

| File                         | Purpose                              |
|------------------------------|--------------------------------------|
| `scenes/player_main.gd`     | Player runtime logic                 |
| `scenes/player_main.tscn`   | Player scene (Control root)          |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic  |

## Headless / Windowless Operation — Internals

The Player runs fine without WindowOUTs. The cook engine keeps chains alive
via the `is_sink` mechanism on file-save operators and `Force Active` scripts.

**How `is_sink` works:** During `GNCookEngine._compute_active_set()`, BFS
starts from all nodes where `is_sink == true`. This includes:
- WindowOUT (always)
- SinkOUT (when Active = ON; accepts any family — pure keep-alive, no side effects)
- TextureSaveOUT, ImageSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, RecordOUT (always)
- OscOUT (always)
- Script operators with `Force Active = ON` (parameter-driven)

Without any sink nodes, the cook engine has an empty active set and no
nodes cook — the Player idles at near-zero CPU.


## Troubleshooting

| Problem                       | Solution                              |
|-------------------------------|---------------------------------------|
| Black screen, no windows open | Ensure your patch has at least one WindowOUT — the Player auto-opens all of them |
| "No patch file specified"     | Check that `config.json` exists next to the exe and has a valid `patch` path |
| Poor performance              | Try `--rendering-method gl_compatibility` for lighter GPU load |
| Player crashes on launch      | GPU may not support Vulkan — the fallback should handle this, but try forcing Compatibility via CLI |
