# GONODES Player

The GONODES Player is a minimal standalone runtime that loads and runs `.gnpatch` files without the editor UI. It boots the cook engine, processes the node graph, and WindowOUT nodes open their own OS windows for visual output.

The Player runs on all 8 supported platforms: Windows (x86_64 / ARM64), Linux (x86_64 / ARM64), macOS, Android, iOS, and Web.


## How It Works

```
GONODESPlayer.exe
  config.json        --- settings (patch path, renderer)
  MyShow.gnpatch     --- the patch file
  MyShow/            --- project assets folder (optional)
```

1. On launch, the Player reads `config.json` from next to the executable.
2. Resolves the `.gnpatch` path (relative to the exe directory).
3. **Auto-opens all WindowOUTs** --- the Player forces `open = true` on every WindowOUT in the network so all display windows appear immediately, regardless of how the patch was saved in the editor.
4. Boots the cook engine with the loaded network.
5. WindowOUT nodes open their own OS windows with their configured title, resolution, fullscreen mode, and monitor.
6. If no WindowOUT exists, a fallback info label is shown in the main window.


## config.json

### Desktop / Mobile

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

### Web

```json
{
	"patch_url": "MyShow.gnpatch",
	"renderer": "gl_compatibility",
	"settings": {
		"log_level": 1,
		"log_to_file": false,
		"parallel_cook_enabled": false,
		"max_cooks_per_frame": 0
	}
}
```

### All Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `patch` | string | `""` | Path to `.gnpatch` file, relative to exe directory or absolute |
| `patch_url` | string | `""` | URL or relative path for web builds (HTTP fetch) |
| `renderer` | string | `""` | Rendering backend --- see Rendering Backend section below |
| `settings.log_level` | int | `1` | Minimum log severity: 0=Debug, 1=Info, 2=Warn, 3=Error. The player always captures. 0 keeps every GONODES line. |
| `settings.log_to_file` | bool | `false` | Write GONODES and Godot engine logs to `gonodes.log` next to the exe |
| `settings.parallel_cook_enabled` | bool | `false` | Cook independent nodes on worker threads (experimental) |
| `settings.max_cooks_per_frame` | int | `0` | Max nodes to cook per frame. 0 = unlimited |

A companion `CONFIG_OPTIONS.txt` file is generated alongside `config.json` during export with detailed documentation of all fields, values, and CLI overrides.


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

The rendering backend is controlled by the `renderer` field in `config.json`. On startup, the Player checks whether the currently running renderer matches the requested one. If they differ, the Player **automatically re-launches itself** with the correct `--rendering-method` flag. This happens transparently --- you just see a brief flash as it restarts.

| Renderer Value      | Technology              | Best for                                           |
|---------------------|-------------------------|----------------------------------------------------|
| `forward_plus`      | Vulkan / D3D12          | Desktop, Apple Silicon, Windows ARM                |
| `mobile`            | Vulkan (mobile profile) | Android (modern), iOS, Apple Silicon               |
| `gl_compatibility`  | OpenGL ES 3.0 / WebGL2  | Web, older Android, Raspberry Pi, widest support   |

### Changing the Renderer

Edit `config.json` and set the `renderer` field to one of the three values above:

```json
{
	"patch": "MyShow.gnpatch",
	"renderer": "mobile"
}
```

The Player will restart with the new renderer on its next launch.

### Node Compatibility

Not all operators work on every renderer. For example, GPU compute operators (POP, VOL) require Forward+ or Mobile, and `CompositorEffectTOP` is Forward+ only. When a node's required renderer doesn't match the active one, the cook engine **automatically skips it** with a warning. Downstream nodes receive empty input --- the patch keeps running, just with those nodes disabled.

Use the **Compat** panel in the GONODES editor to check which nodes in your patch are compatible with your target renderer before exporting.

### Automatic Fallback

If Forward+ is selected but the GPU doesn't support Vulkan, Godot automatically falls back to Compatibility (OpenGL 3.3). This is handled by `fallback_to_opengl3 = true` baked into the `.pck` at export.

### Power-User Override

CLI arguments override `config.json`:
```
GONODESPlayer.exe --rendering-method mobile
GONODESPlayer.exe --rendering-method gl_compatibility
```


## Platform-Specific Notes

### Web

- The Player loads the patch via HTTP fetch (using `patch_url` in config.json)
- Threading requires COOP/COEP headers on the web server; without them, the cook engine runs single-threaded
- WindowOUT opens in an embedded viewport (no separate browser windows)
- Serve with any HTTP server: `python -m http.server 8080`

### Android

- Install via `adb install -r GONODESPlayer.apk`
- WindowOUT uses the device's native display
- Compute shaders require a Vulkan-capable device; older devices fall back to CPU

### iOS

- The `.ipa` must be re-signed with your Apple developer certificate before deploying
- Deploy via Xcode, TestFlight, or enterprise distribution

### Mobile (General)

- WindowOUT automatically uses embedded mode on mobile --- no separate OS windows
- Touch input is mapped to mouse events
- Operators that require desktop-only capabilities (FFmpeg CLI, local filesystem, webcam) are skipped at runtime


## Window Management

The Player does **not** manage display windows directly. Each **WindowOUT** node in the patch controls its own OS window.

On launch, the Player automatically forces every WindowOUT to open, regardless of its saved `open` parameter.

| WindowOUT Parameter | What it controls              |
|---------------------|-------------------------------|
| `title`             | Window title bar text         |
| `resolution`        | Window size (width × height)  |
| `window_mode`       | Windowed / Fullscreen / Borderless |
| `monitor`           | Which display to open on      |
| `position`          | Window position on screen     |
| `always_on_top`     | Keep window above others      |
| `vsync`             | Per-window VSync override     |

A single patch can have **multiple WindowOUTs**, each opening its own independent window — useful for multi-display installations.

> VSync and frame-rate are per-window settings (not global). There's no VSync in config.json because each WindowOUT controls it independently.


## Quick Build (Creating a Player Package)

Use the **Build** button in the GONODES editor toolbar to open the Export Patch dialog. Select your target platform, renderer, and output folder, then click Build. This copies:

1. The Player binary/package (from `templates/<platform>/`)
2. Your `.gnpatch` file
3. The project assets folder (images, videos, etc.)
4. A generated `config.json` with the patch path and renderer

The result is a self-contained folder you can zip and distribute. For web builds, serve the folder with an HTTP server.

See the **Building** help section for how to prepare Player templates and details on the Export Patch dialog.


## Headless / Windowless Operation

The Player doesn't require WindowOUT nodes. Patches that only use file-save operators (ImageSaveOUT, TextureSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, RecordOUT) or network-output nodes (OscOUT) run headless — the cook engine keeps their chains alive via `is_sink = true`.

### SinkOUT — Keep-Alive for Any Chain

For chains that have no natural output (no file write, no display, no network send), drop a **SinkOUT** at the end. It accepts any data family and acts as a no-op sink — the chain stays alive and cooking without producing any side effects. Toggle its **Active** parameter OFF to pause the chain.

### Force Active — Script Operators as Sinks

For **Script operators** with side effects (HTTP, hardware control, etc.), enable the **Force Active** toggle so the script itself acts as a sink:

| Parameter      | Setting | Why                                      |
|----------------|---------|------------------------------------------|
| Force Active   | ON      | Keep chain alive without downstream sink |
| Time Dependent | ON      | Re-cook every frame                      |

This makes the script cook every frame without needing any downstream WindowOUT — perfect for headless automation or data-processing pipelines.


## Key Files

| File                                            | Purpose                     |
|-------------------------------------------------|-----------------------------|
| `scenes/player_main.gd`                        | Player runtime logic        |
| `scenes/player_main.tscn`                      | Player scene (Control root) |
| `addons/gonodes/core/gn_patch_exporter.gd`     | Quick Build copy logic      |
