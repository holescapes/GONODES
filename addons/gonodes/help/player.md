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
  "renderer": "forward_plus"
}
```

### Web

```json
{
  "patch_url": "MyShow.gnpatch",
  "renderer": "gl_compatibility"
}
```

| Field      | Type   | Default | Description                                  |
|------------|--------|---------|----------------------------------------------|
| `patch`    | string | `""`    | Path to the `.gnpatch` relative to exe       |
| `patch_url`| string | `""`    | URL or relative path for web (HTTP fetch)    |
| `renderer` | string | `""`    | Renderer chosen at export time (informational)|

The `renderer` value records which rendering backend was selected in the Export Patch dialog. The rendering method is baked into the Player binary at build time; this field serves as documentation of the intended configuration.

VSync and display parameters are controlled by each WindowOUT in the patch, not by config.json.


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

The rendering backend is selected at export time via the Export Patch dialog's **Renderer** dropdown. It is baked into the Player binary's `.pck`.

| Renderer        | Technology       | Best for                                           |
|-----------------|------------------|----------------------------------------------------|
| Forward+        | Vulkan / D3D12   | Desktop, Apple Silicon, Windows ARM                |
| Mobile          | Vulkan (mobile)  | Android (modern), iOS, Apple Silicon               |
| Compatibility   | OpenGL ES 3.0 / WebGL2 | Web, older Android, Raspberry Pi, widest support |

If Forward+ is selected but the GPU doesn't support Vulkan, Godot automatically falls back to Compatibility (OpenGL 3.3) --- this is handled by `fallback_to_opengl3 = true` baked into the `.pck`.

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

For **Script operators** with side effects (HTTP, hardware control, etc.), enable the **Force Active** toggle so the script acts as a sink:

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
