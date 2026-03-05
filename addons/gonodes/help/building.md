# Building GONODES

This guide covers building GONODES Player binaries (templates) and using the Quick Build feature to package patches for distribution.


## Overview

GONODES uses a **Quick Build** paradigm: pre-built Player binaries are stored in `templates/`. When you press **Build** in the editor, the exporter copies the correct platform binary + `.pck` + patch + assets to the output folder. No Godot export templates are needed at runtime.


## When to Rebuild Templates

Rebuild the templates whenever you:

- **Upgrade Godot** — export templates are version-locked. A Player built with Godot 4.6.1 won't load a `.pck` from 4.7.
- **Make a GONODES release** — ensures the Player binaries include any new operators, cook engine changes, or scene modifications.
- **Add or change export presets** — new architecture, code-signing, etc.

> When you upgrade Godot, also update the export templates: **Editor → Manage Export Templates → Download for Current Version**.


## Prerequisites

1. **Godot 4.6.x editor binary** (console build recommended for CI)
2. **Godot export templates** — install via `Editor → Manage Export Templates`
3. **Export presets** — the project ships with optimized presets for all 5 desktop targets in `export_presets.cfg`


## Build Scripts

Two functionally identical scripts automate template creation:

| Script                        | For                                     |
|-------------------------------|-----------------------------------------|
| `scripts/build_templates.ps1` | PowerShell — Windows, or any OS with pwsh|
| `scripts/build_templates.sh`  | Bash — Linux, macOS                     |

### Quick Start (Windows)

```powershell
# Build Player for current platform (auto-detected)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"

# Build for all desktop platforms
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe" -Platforms "all"

# Build everything (Player + Editor, all platforms, clean)
.\scripts\build_templates.ps1 -BuildAll -Clean
```

### Quick Start (Linux / macOS)

```bash
# Build Player for current platform (auto-detected)
./scripts/build_templates.sh --godot /path/to/godot

# Build for all desktop platforms
./scripts/build_templates.sh --godot /path/to/godot --platforms all

# Build everything
./scripts/build_templates.sh --build-all --clean
```


## Platform Targets

| Platform         | OS      | Architecture |
|------------------|---------|--------------|
| `windows_x86_64` | Windows | Intel/AMD 64 |
| `windows_arm64`  | Windows | ARM 64       |
| `linux_x86_64`   | Linux   | Intel/AMD 64 |
| `linux_arm64`    | Linux   | ARM 64       |
| `macos`          | macOS   | Universal    |

When no platform is specified, both scripts auto-detect the host OS and architecture.


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
| `script_export_mode`       | `2`        | Compiled binary tokens — fastest script parse       |
| `shader_baker/enabled`     | `true`     | Pre-bakes shaders — no first-frame stutter          |
| `embed_pck`                | `false`    | Separate `.pck` is platform-agnostic                |
| `--export-release`         | always     | Release templates — optimized, stripped              |

### Shader Baker

Godot 4.6 pre-compiles shaders to SPIR-V / DXIL at export time. Without this, shaders compile on first use at runtime, causing visible stutter.

### Compiled Scripts

GDScript files are converted to compressed binary tokens. The runtime doesn't need to parse text — faster load, smaller `.pck`.

### .pck Files Are Platform-Agnostic

The `.pck` is pure data (scenes, scripts, textures, pre-baked shaders). It does **not** contain native code. A single `.pck` built on Windows works on Linux, macOS, and ARM.


## Output Structure

```
templates/
├── windows_x86_64/
│   ├── GONODESPlayer.exe
│   └── GONODESPlayer.pck
├── linux_x86_64/
│   ├── GONODESPlayer
│   └── GONODESPlayer.pck
└── macos/
    └── GONODESPlayer.app/
```


## Main-Scene Swap

Godot exports always use `project.godot`'s `run/main_scene`. The build scripts automatically:
1. Rewrite `main_scene` → `player_main.tscn` before Player exports
2. Export all Player presets
3. Restore `main_scene` → `gn_editor.tscn`

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
| "Preset not found"              | Open Godot → Project → Export — verify preset names   |
| "No export template found"      | Install export templates via Editor → Manage Export Templates |
| project.godot stuck on player   | Run `--restore-only` / `-RestoreOnly`                 |
| Cross-platform build fails      | Need export templates for target OS on build machine  |
| First-frame stutter in Player   | Verify `shader_baker/enabled=true` in the preset      |
| GDExtension DLL error           | Use `-GDExtensions "auto"` or `"none"`                |


## Key Files

| File                                        | Purpose                            |
|---------------------------------------------|------------------------------------|
| `scripts/build_templates.ps1`               | PowerShell build script            |
| `scripts/build_templates.sh`                | Bash build script                  |
| `export_presets.cfg`                        | Godot export preset definitions    |
| `templates/`                                | Built Player/Editor binaries       |
| `addons/gonodes/core/gn_patch_exporter.gd` | Quick Build copy logic (runtime)   |
