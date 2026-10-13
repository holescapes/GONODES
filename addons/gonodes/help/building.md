# Building & Exporting in GONODES

This guide covers building GONODES Player templates for all supported platforms and using the **Export Patch** dialog to package your patches for distribution.

> **Native C++ extensions** (MIDI, Spout, OpenCV, etc.) are built separately from
> the editor export flow. See [dev_docs/BUILD.md](../../../dev_docs/BUILD.md) for the
> full fresh-clone guide (checklist + script per step). On Windows:
>
> ```powershell
> $env:PYTHONUTF8 = "1"
> $env:GONODES_GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
> python scripts/check_env.py
> .\scripts\build_windows.ps1          # tier=all; use -Shipped for a faster subset
> python scripts/check_builds.py
> ```
>
> Prerequisites: Python 3.10+, SCons, VS 2022 Build Tools **with C++ workload**,
> and Godot matching `versions.env`.


## Overview

GONODES uses a **Quick Build** paradigm: pre-built Player binaries are stored in `templates/`. When you click **Build** in the editor, the Export Patch dialog opens. You pick a target platform, a renderer, and an output folder. The exporter copies the correct Player template + your `.gnpatch` + assets + `config.json` to the output folder. No Godot export templates are needed at that moment.


## Standalone editor and players

A release **editor** is its own program. Godot is packed inside that executable. You author patches there. You do not install Godot.

A release **player** is a second program. Godot is packed inside it too. You run a finished patch with the player. You do not install Godot.

Each editor download includes the player for that same operating system, in `templates/` next to the editor. Exporting for the machine you are on works with no network.

The first time you export for another desktop system, the other desktop architecture, or the web, the Build dialog downloads that player from the GitHub release that matches this editor and stores it under `templates/`. A `TEMPLATE_VERSION.txt` file in that folder records the Godot version and the GONODES version. A later editor refuses a player from a different version and downloads the matching one.

These players are in the release:

| Platform | Folder |
|----------|--------|
| Windows x86_64 | `templates/windows_x86_64/` |
| Windows ARM64 | `templates/windows_arm64/` |
| Linux x86_64 | `templates/linux_x86_64/` |
| Linux ARM64 | `templates/linux_arm64/` |
| macOS | `templates/macos/` |
| Web | `templates/web/` |

### Android and iOS

Android and iOS players are not produced by the release, and the editor will not download them. Authoring still uses the standalone editor. What you build by hand is only the player template.

1. Use the Godot version in `versions.env` (`GODOT_VERSION`). Install that editor and its export templates (Editor, Manage Export Templates, Download for Current Version). The people who only run the standalone editor skip this step.
2. **Android:** install the Android SDK and JDK, then set them in Godot under Editor, Editor Settings, Export, Android.
3. **iOS:** use a Mac with Xcode. This template cannot be created on Windows or Linux. After export, re-sign the `.ipa` with your Apple developer certificate before it will install.
4. From the GONODES project, build just that player:

```powershell
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" -Platforms android
```

```bash
./scripts/build_templates.sh --godot /path/to/godot --platforms ios
```

5. The player lands in `templates/android/` or `templates/ios/`, with `TEMPLATE_VERSION.txt`. Copy that folder next to any standalone editor, under the same `templates/<platform>/` path. Build then copies it like any other player.

Editors are written to `editor_dist/<platform>/`, not into `templates/`, so a player export does not pick up the editor executable. `scripts/template_release.py stage` packs a release editor with its matching player already nested under `templates/`.


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

If the selected player is missing, an orange hint appears. On a release editor the hint says the player will download when you press Build. Android and iOS tell you to build that player yourself. A source checkout with no release recorded in `template_source.cfg` still points at `scripts/build_templates`.

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

1. **Godot editor binary matching `versions.env`** (console build recommended --- produces better log output)
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

- **Upgrade Godot** --- export templates are version-locked. A Player built with one Godot version will not load a `.pck` from another. Rebuild templates after changing `versions.env`.
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
| "No template found" in dialog   | Desktop and web players download when a release is configured. Android and iOS: run the build script, then copy `templates/<platform>/` next to the editor |


## Key Files

| File                                        | Purpose                            |
|---------------------------------------------|------------------------------------|
| `scripts/build_templates.ps1`               | PowerShell build script            |
| `scripts/build_templates.sh`                | Bash build script                  |
| `export_presets.cfg`                        | Godot export preset definitions    |
| `scripts/template_release.py`               | Version stamp and release zip layout |
| `templates/`                                | Built Player binaries              |
| `editor_dist/`                              | Built Editor binaries              |
| `addons/gonodes/core/gn_template_store.gd` | Template stamp check and download  |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic (runtime)   |
| `addons/gonodes/ui/gn_export_dialog.gd`    | Export Patch dialog (UI)           |
