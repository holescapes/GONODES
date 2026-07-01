# Building & Exporting in GONODES

This guide covers building GONODES Player templates for all supported platforms and using the **Export Patch** dialog to package your patches for distribution.

> **Native C++ extensions** (MIDI, Spout, OpenCV, etc.) are built separately from
> the editor export flow. See [dev_docs/BUILD.md](../../dev_docs/BUILD.md) for the
> full fresh-clone guide. On Windows, run `scripts/build_windows.ps1` from the repo
> root (defaults to `tier=all` after fetching SDKs). Install Python, SCons, and MSVC first.


## Overview

GONODES uses a **Quick Build** paradigm: pre-built Player binaries are stored in `templates/`. When you click **Build** in the editor, the Export Patch dialog opens. You pick a target platform, a renderer, and an output folder. The exporter copies the correct Player template + your `.gnpatch` + assets + `config.json` to the output folder. No Godot export templates are needed at runtime.


## The Export Patch Dialog

Click **Build** in the editor toolbar to open the Export Patch dialog.

### Target Platform

Choose which OS and architecture to export for:

| Platform           | What it produces                     |
|--------------------|--------------------------------------|
| Windows x86_64     | `.exe` + `.pck` --- standard PC      |
| Windows ARM64      | `.exe` + `.pck` --- Snapdragon laptops, Surface Pro X |
| Linux x86_64       | Binary + `.pck` --- standard Linux   |
| Linux ARM64        | Binary + `.pck` --- Raspberry Pi, ARM servers |
| macOS (Universal)  | `.app` bundle --- Intel + Apple Silicon |
| Android            | `.apk` package                       |
| iOS                | `.ipa` package (needs re-signing)    |
| Web                | `.html` + `.wasm` + `.pck`           |

The dropdown auto-selects your current machine. You can cross-build for any platform that has a pre-built template.

### Renderer

Choose the rendering backend independently from the platform:

| Renderer        | Best for                                                        |
|-----------------|-----------------------------------------------------------------|
| **Forward+**    | Desktop (Win/Mac/Linux), Apple Silicon, Windows ARM (Vulkan)    |
| **Mobile**      | Android (modern), iOS, Apple Silicon                            |
| **Compatibility** | Web (WebGL2), older Android, Raspberry Pi, widest device support |

The dialog suggests a sensible default per platform, but the final choice is yours --- you know your target hardware best.

### Template Availability

If no pre-built template exists for the selected platform, an orange hint appears:

> *No template found for Linux ARM64. Build it first: scripts/build_templates -Platforms linux_arm64*

See [Building Templates](#building-templates) below.

### Compatibility Check

The dialog automatically scans your patch against the selected platform + renderer and shows:

- **Green** --- all nodes compatible
- **Yellow** --- some nodes will use CPU fallback (slower but functional)
- **Red** --- some nodes will be skipped at runtime (no fallback available)

This updates live as you change the platform or renderer selection.

### Output

The build produces a self-contained folder:

```
MyShow_build/
  GONODESPlayer.exe       (or .html/.wasm/.apk/.app depending on platform)
  GONODESPlayer.pck       (desktop only)
  config.json             tells the Player which patch and renderer to use
  MyShow.gnpatch          your patch
  MyShow_assets/          project assets (textures, audio, etc.)
```

`config.json` records the patch path and chosen renderer:

```json
{
  "patch": "MyShow.gnpatch",
  "renderer": "forward_plus"
}
```

For web builds, the key is `patch_url` instead of `patch`.


## Running Your Build

| Platform    | How to run                                                         |
|-------------|--------------------------------------------------------------------|
| **Desktop** | Double-click `GONODESPlayer.exe` (or `.app` / the Linux binary)   |
| **Android** | `adb install -r GONODESPlayer.apk`, then launch on device         |
| **iOS**     | Re-sign the `.ipa` with your Apple developer certificate, deploy via Xcode or TestFlight |
| **Web**     | Serve the folder with any HTTP server (see below)                  |

### Web Deployment

Web builds need COOP/COEP headers for threading support. Quick local test:

```bash
python -m http.server 8080
```

Then open `http://localhost:8080/GONODESPlayer.html` in your browser.

For production, configure your web server to add these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without these headers, threading is disabled and the cook engine runs in single-threaded mode (still works, just slower).


## Building Templates

Templates are the pre-built Player binaries that Quick Build copies into your output folder. You only need to build them once per Godot version / GONODES release.

### Prerequisites

1. **Godot 4.6.x editor binary** (console build recommended --- produces better log output)
2. **Godot export templates** for each target platform:
   - Open Godot --> **Editor --> Manage Export Templates --> Download for Current Version**
   - This downloads templates for **all** platforms at once (desktop, mobile, web)
3. **Platform-specific SDKs** (only for mobile):
   - **Android**: Android SDK + JDK --- configure in Godot's **Editor --> Editor Settings --> Export --> Android**
   - **iOS**: Requires macOS with Xcode (cannot build iOS templates from Windows/Linux)

### Quick Start (Windows)

```powershell
# Build Player for current platform only (auto-detected)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe"

# Build Player for all platforms (desktop + mobile + web)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe" -Platforms "all"

# Build just web + android
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe" -Platforms "web,android"

# Build everything (Player + Editor, all platforms, clean first)
.\scripts\build_templates.ps1 -BuildAll -Clean
```

> **Note:** On PowerShell 5.1 (Windows default), use `powershell -ExecutionPolicy Bypass -File` if you get a script execution error.

### Quick Start (Linux / macOS)

```bash
# Build Player for current platform only (auto-detected)
./scripts/build_templates.sh --godot /path/to/godot

# Build Player for all platforms
./scripts/build_templates.sh --godot /path/to/godot --platforms all

# Build just web + android
./scripts/build_templates.sh --godot /path/to/godot --platforms web,android

# Build everything
./scripts/build_templates.sh --build-all --clean
```


## When to Rebuild Templates

Rebuild the templates whenever you:

- **Upgrade Godot** --- export templates are version-locked. A Player built with Godot 4.6.1 won't load a `.pck` from 4.7.
- **Make a GONODES release** --- ensures the Player binaries include any new operators, cook engine changes, or scene modifications.
- **Add or change export presets** --- new architecture, code-signing, etc.

> When you upgrade Godot, also update the export templates: **Editor --> Manage Export Templates --> Download for Current Version**.


## Platform Targets

| Platform          | OS      | Architecture | Template folder      |
|-------------------|---------|--------------|----------------------|
| `windows_x86_64`  | Windows | Intel/AMD 64 | `templates/windows_x86_64/` |
| `windows_arm64`   | Windows | ARM 64       | `templates/windows_arm64/`  |
| `linux_x86_64`    | Linux   | Intel/AMD 64 | `templates/linux_x86_64/`   |
| `linux_arm64`     | Linux   | ARM 64       | `templates/linux_arm64/`    |
| `macos`           | macOS   | Universal    | `templates/macos/`          |
| `android`         | Android | ARM 64       | `templates/android/`        |
| `ios`             | iOS     | ARM 64       | `templates/ios/`            |
| `web`             | Web     | WASM         | `templates/web/`            |

When no platform is specified, both scripts auto-detect the host OS and architecture and build for the current machine only.


## Script Parameters

### PowerShell

| Parameter         | Default        | Description                                 |
|-------------------|----------------|---------------------------------------------|
| `-GodotPath`      | auto-detect    | Path to the Godot editor executable         |
| `-Platforms`      | host platform  | Comma-separated list, or `"all"`            |
| `-BuildAll`       | off            | Shortcut: Player + Editor for all platforms |
| `-IncludeEditor`  | off            | Also build Editor binaries                  |
| `-GDExtensions`   | `auto`         | GDExtension handling mode (see below)       |
| `-Clean`          | off            | Remove templates/ before building           |
| `-RestoreOnly`    | off            | Recovery: restore project.godot             |

### Bash

| Flag              | Default        | Description                                 |
|-------------------|----------------|---------------------------------------------|
| `--godot PATH`    | auto-detect    | Path to the Godot editor binary             |
| `--platforms LIST`| host platform  | Comma-separated list, or `all`              |
| `--build-all`     | off            | Shortcut: Player + Editor for all platforms |
| `--include-editor`| off            | Also build Editor binaries                  |
| `--gdext MODE`    | `auto`         | GDExtension handling mode (see below)       |
| `--clean`         | off            | Remove templates/ before building           |
| `--restore-only`  | off            | Recovery: restore project.godot             |


## GDExtension Handling

GDExtensions are third-party native libraries (`.dll` / `.so` / `.dylib`). Not every addon provides binaries for every platform. The `-GDExtensions` / `--gdext` parameter controls how they're handled:

| Mode             | Behaviour                                                    |
|------------------|--------------------------------------------------------------|
| `auto` (default) | Keeps entries with existing files, removes missing entries   |
| `all`            | Leave everything as-is (may fail if files missing)           |
| `none`           | Delete all `.gdextension` files (zero native deps)          |
| `name,name,...`  | Named addons get `auto` treatment, everything else deleted   |

Original files are always restored after the build, even on Ctrl+C or error.


## Release-Build Optimizations

Every export preset is tuned for production:

| Setting                    | Value      | Why                                                 |
|----------------------------|------------|-----------------------------------------------------|
| `script_export_mode`       | `2`        | Compiled binary tokens --- fastest script parse     |
| `shader_baker/enabled`     | `true`     | Pre-bakes shaders --- no first-frame stutter        |
| `embed_pck`                | `false`    | Separate `.pck` is platform-agnostic                |
| `--export-release`         | always     | Release templates --- optimized, stripped            |

### Shader Baker

Godot 4.6 pre-compiles shaders to SPIR-V / DXIL at export time. Without this, shaders compile on first use at runtime, causing visible stutter.

### Compiled Scripts

GDScript files are converted to compressed binary tokens. The runtime doesn't need to parse text --- faster load, smaller `.pck`.

### .pck Files Are Platform-Agnostic

The `.pck` is pure data (scenes, scripts, textures, pre-baked shaders). It does **not** contain native code. A single `.pck` built on Windows works on Linux, macOS, and ARM.


## Output Structure

```
templates/
  windows_x86_64/
    GONODESPlayer.exe
    GONODESPlayer.pck
  windows_arm64/
    GONODESPlayer.exe
    GONODESPlayer.pck
  linux_x86_64/
    GONODESPlayer
    GONODESPlayer.pck
  linux_arm64/
    GONODESPlayer
    GONODESPlayer.pck
  macos/
    GONODESPlayer.app/
  android/
    GONODESPlayer.apk
  ios/
    GONODESPlayer.ipa
  web/
    GONODESPlayer.html
    GONODESPlayer.wasm
    GONODESPlayer.pck
    GONODESPlayer.js
    ...
```


## Main-Scene Swap

Godot exports always use `project.godot`'s `run/main_scene`. The build scripts automatically:
1. Rewrite `main_scene` to `player_main.tscn` before Player exports
2. Export all Player presets
3. Restore `main_scene` to `gn_editor.tscn`

If interrupted mid-build, recover with:
```powershell
.\scripts\build_templates.ps1 -RestoreOnly
```
```bash
./scripts/build_templates.sh --restore-only
```


## CI / Automation

Exit code = number of failed exports (0 = all succeeded).

```bash
# GitHub Actions
./scripts/build_templates.sh --godot "$GODOT_PATH" --platforms all --clean
```
```powershell
# Windows CI
.\scripts\build_templates.ps1 -GodotPath $env:GODOT_PATH -Platforms "all" -Clean
```


## Troubleshooting

| Problem                         | Solution                                              |
|---------------------------------|-------------------------------------------------------|
| "Preset not found"              | Open Godot --> Project --> Export --- verify preset names |
| "No export template found"      | Install export templates via Editor --> Manage Export Templates |
| project.godot stuck on player   | Run `--restore-only` / `-RestoreOnly`                 |
| Cross-platform build fails      | Need export templates for target OS on build machine  |
| First-frame stutter in Player   | Verify `shader_baker/enabled=true` in the preset      |
| GDExtension DLL error           | Use `-GDExtensions "auto"` or `"none"`                |
| Web build missing               | Install web export template in Godot, then rebuild    |
| Android build missing           | Install Android SDK + JDK, configure in Godot Editor Settings |
| iOS build fails on Windows      | iOS templates can only be built on macOS with Xcode   |
| PS execution policy error       | Use `powershell -ExecutionPolicy Bypass -File ...`    |
| "No template found" in dialog   | Run the build script for that platform first          |


## Key Files

| File                                        | Purpose                            |
|---------------------------------------------|------------------------------------|
| `scripts/build_templates.ps1`               | PowerShell build script            |
| `scripts/build_templates.sh`                | Bash build script                  |
| `export_presets.cfg`                        | Godot export preset definitions    |
| `templates/`                                | Built Player/Editor binaries       |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic (runtime)   |
| `addons/gonodes/ui/gn_export_dialog.gd`    | Export Patch dialog (UI)           |
