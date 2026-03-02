# GONODES Build System

This document describes how to build GONODES Player (and optionally Editor)
binaries for all desktop platforms.


## Overview

GONODES uses a **Quick Build** paradigm: pre-built Player binaries are stored
in the `templates/` folder.  When the user presses **Build** in the editor,
the exporter copies the correct platform binary + `.pck` + patch + assets
to the output folder.  No Godot export templates are needed at runtime.

Two build scripts automate template creation:

| Script                          | For                                       |
|---------------------------------|-------------------------------------------|
| `scripts/build_templates.ps1`   | PowerShell — Windows, or any OS with pwsh |
| `scripts/build_templates.sh`    | Bash — Linux, macOS                       |

Both scripts are functionally identical and produce the same output.


## When to Rebuild Templates

Rebuild the templates whenever you:

- **Upgrade Godot** — export templates are version-locked.  A Player built
  with Godot 4.6.1 won't load a `.pck` from 4.7.  Always rebuild after
  updating the Godot engine.
- **Make a GONODES release** — ensures the Player binaries include any new
  operators, cook engine changes, or scene modifications.
- **Add or change export presets** — new architecture, code-signing, etc.

> **Current Godot version: 4.6.1 stable**
>
> When you upgrade Godot, also update the Godot export templates:
> **Editor → Manage Export Templates → Download for Current Version**.


## Prerequisites

1. **Godot 4.6.x editor binary** — can be the standard editor or a console
   build (console build recommended for CI, produces better log output).

2. **Godot export templates** — install via `Editor → Manage Export Templates`
   in the Godot editor.  You need templates for every platform you want to
   target (e.g. Windows x86_64, Linux x86_64, macOS).

3. **Export presets** — the project ships with optimized presets for all 5
   desktop targets in `export_presets.cfg`.  If Godot warns about a missing
   platform, install the corresponding export templates.


## Quick Start

### Windows (PowerShell)

```powershell
# Build Player for the current host platform (auto-detected)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"

# Build Player for all desktop platforms
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe" -Platforms "all"

# Build both Player and Editor for all platforms, clean first
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe" -Platforms "all" -IncludeEditor -Clean
```

### Linux / macOS (Bash)

```bash
# Build Player for the current host platform (auto-detected)
./scripts/build_templates.sh --godot /path/to/godot

# Build Player for all desktop platforms
./scripts/build_templates.sh --godot /path/to/godot --platforms all

# Build both Player and Editor for all platforms, clean first
./scripts/build_templates.sh --godot /path/to/godot --platforms all --include-editor --clean
```


## Script Parameters

### PowerShell (`build_templates.ps1`)

| Parameter              | Default          | Description                                        |
|------------------------|------------------|----------------------------------------------------||
| `-GodotPath`           | auto-detect      | Path to the Godot editor executable                |
| `-ProjectPath`         | script's parent  | GONODES project root (contains `project.godot`)    |
| `-OutputDir`           | `<project>/templates` | Where templates are written                   |
| `-Platforms`           | host platform    | Comma-separated list, or `"all"`                   |
| `-IncludeEditor`       | off              | Also build Editor binaries                         |
| `-IncludeGDExtensions` | off              | Bundle third-party GDExtension native libraries    |
| `-Clean`               | off              | Remove templates/ before building                  |
| `-RestoreOnly`         | off              | Recovery: restore `project.godot` after interruption|

### Bash (`build_templates.sh`)

| Flag               | Default          | Description                                       |
|--------------------|------------------|---------------------------------------------------|
| `--godot PATH`     | auto-detect      | Path to the Godot editor binary                   |
| `--project PATH`   | script's parent  | GONODES project root                              |
| `--output PATH`    | `<project>/templates` | Where templates are written                  |
| `--platforms LIST`  | host platform    | Comma-separated list, or `all`                   |
| `--include-editor` | off              | Also build Editor binaries                        |
| `--include-gdext`  | off              | Bundle third-party GDExtension native libraries   |
| `--clean`          | off              | Remove templates/ before building                 |
| `--restore-only`   | off              | Recovery: restore `project.godot`                 |


### Platform Names

| Platform          | OS      | Architecture |
|-------------------|---------|--------------|
| `windows_x86_64`  | Windows | Intel/AMD 64 |
| `windows_arm64`   | Windows | ARM 64       |
| `linux_x86_64`    | Linux   | Intel/AMD 64 |
| `linux_arm64`     | Linux   | ARM 64       |
| `macos`           | macOS   | Universal    |

When no `--platforms` is given, both scripts auto-detect the host OS and
architecture and build for the current machine only.


## Output Structure

```
templates/
├── windows_x86_64/
│   ├── GONODESPlayer.exe
│   └── GONODESPlayer.pck
├── windows_arm64/
│   ├── GONODESPlayer.exe
│   └── GONODESPlayer.pck
├── linux_x86_64/
│   ├── GONODESPlayer
│   └── GONODESPlayer.pck
├── linux_arm64/
│   ├── GONODESPlayer
│   └── GONODESPlayer.pck
└── macos/
    └── GONODESPlayer.app/
```

The Quick Build button in the editor automatically finds the correct
platform's binary from `templates/<platform>/`.


## Release-Build Optimizations

Every export preset is tuned for production use.  These settings are
baked into `export_presets.cfg`:

| Setting                          | Value   | Why                                                  |
|----------------------------------|---------|------------------------------------------------------|
| `script_export_mode`             | `2`     | Compiled binary tokens — fastest script parse at load |
| `shader_baker/enabled`           | `true`  | Pre-bakes shaders at export → no first-frame stutter  |
| `embed_pck`                      | `false` | Separate `.pck` is platform-agnostic, can be shared   |
| `texture_format/s3tc_bptc`       | `true`  | Native desktop GPU texture compression (BC1–BC7)      |
| `texture_format/etc2_astc`       | `false` | Mobile-only formats — not needed on desktop            |
| `application/export_d3d12`       | `1` (Win) | Bundles D3D12 Agility SDK so the binary is fully self-contained |
| `application/export_angle`       | `0`     | ANGLE (GL ES over D3D11) not needed for desktop        |
| `export_console_wrapper`         | `0` (Player) | No separate console window for end users          |
| `--export-release` (CLI flag)    | always  | Uses **release** export templates — optimized, stripped |

### Why These Matter

- **Shader Baker** (`shader_baker/enabled=true`): Godot 4.6 can pre-compile
  shaders to SPIR-V / DXIL at export time.  Without this, shaders are
  compiled on first use at runtime, causing visible stutter on the first
  frame each material/effect appears.

- **D3D12 Agility SDK** (`export_d3d12=1`): The project uses D3D12 as its
  primary renderer on Windows (`rendering_device/driver.windows="d3d12"`
  in project.godot).  Bundling the Agility SDK ensures the D3D12 runtime
  works on any Windows 10/11 machine, even those with older system D3D12
  libraries.  Adds ~5–10 MB to the Windows binary.

- **Compiled Scripts** (`script_export_mode=2`): GDScript files are
  converted to compressed binary tokens at export.  The runtime doesn't
  need to parse text, which speeds up load time and reduces .pck size.

- **Release Export Templates**: `--export-release` selects the release
  build of the Godot runtime — compiled with full optimizations, debug
  assertions disabled, and debug symbols stripped.

### What About Static Linking?

Godot's official export templates are pre-built.  Whether they're
statically or dynamically linked depends on how Godot was compiled.
The standard templates link the C++ runtime statically on Windows
(MSVC `/MT`), making them self-contained — no Visual C++ Redistributable
needed.  On Linux the standard templates dynamically link against glibc;
on macOS against system frameworks.  This is already optimal for each OS.

If you use **custom export templates** built from source, pass
`use_static_cpp=yes` (SCons) to statically link C++ where possible.
Set the `custom_template/release` field in the preset to point at your
custom binary.


## .pck Files Are Platform-Agnostic

The `.pck` file is pure data (scenes, scripts, textures, pre-baked shaders).
It does **not** contain native code.  A single `.pck` built on Windows works
on Linux, macOS, and ARM-based machines.

Only the **binary** (the Godot runtime) differs per platform.  This is why
the Quick Build paradigm works: copy the right binary, share the `.pck`.


## GDExtension Handling

GDExtensions are third-party native libraries (C/C++/Rust plugins) that ship
as `.dll` / `.so` / `.dylib` files alongside a `.gdextension` manifest.  Not
every addon provides binaries for every platform, and missing binaries will
cause Godot's export to fail.

To keep the **base GONODES project** always buildable, the build scripts
**disable GDExtensions by default**.  Before export, all `.gdextension` files
are temporarily renamed to `.gdextension.disabled` so Godot ignores them.
They are always restored after (even on Ctrl+C / error).

If you want to include native addons in your build, opt in explicitly:

```powershell
# PowerShell
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe" -IncludeGDExtensions
```

```bash
# Bash
./scripts/build_templates.sh --godot /path/to/godot --include-gdext
```

With the flag enabled, the script runs a pre-flight check that scans every
`.gdextension` file and verifies the referenced libraries exist for each
target platform.  Missing libraries are reported as warnings before export
begins.  Exports continue for other platforms even if one fails.

### Pre-Build Cleanup

Both scripts also automatically clean up stale `~*.TMP` temp files in
`addons/` before exporting.  These are left behind by Windows antivirus,
file indexers, or Godot itself and can cause confusing export errors.


## How the Main-Scene Swap Works

Godot's export always uses `project.godot`'s `run/main_scene`.  The Editor
main scene is `gn_editor.tscn`; the Player needs `player_main.tscn`.

The build scripts handle this automatically:

1. **Before Player exports**: rewrites `main_scene` → `player_main.tscn`
2. **Exports all Player presets** via `godot --headless --export-release`
3. **Restores** `main_scene` → `gn_editor.tscn`
4. (Optional) Exports Editor presets with the original main scene

If the script is interrupted mid-build (Ctrl+C, crash), `project.godot`
may be left pointing at the Player scene.  Recovery:

```bash
# Bash
./scripts/build_templates.sh --restore-only
```
```powershell
# PowerShell
.\scripts\build_templates.ps1 -RestoreOnly
```

Both scripts also install a cleanup trap / `finally` block that attempts
automatic restoration on exit.


## Export Presets

All presets are defined in `export_presets.cfg` at the project root:

| Preset                      | Index | Purpose         |
|-----------------------------|-------|-----------------|
| Editor Windows x86_64       | 0     | Manual / Editor |
| Player Windows x86_64       | 1     | Build script    |
| Player Windows ARM64        | 2     | Build script    |
| Player Linux x86_64         | 3     | Build script    |
| Player Linux ARM64          | 4     | Build script    |
| Player macOS                | 5     | Build script    |
| Editor Windows ARM64        | 6     | Build script    |
| Editor Linux x86_64         | 7     | Build script    |
| Editor Linux ARM64          | 8     | Build script    |
| Editor macOS                | 9     | Build script    |


## CI / Automation

The build scripts are designed for unattended use.  Exit code = number of
failed exports (0 = all succeeded).

```bash
# GitHub Actions (Linux runner)
./scripts/build_templates.sh --godot "$GODOT_PATH" --platforms all --clean
if [ $? -ne 0 ]; then echo "Build failed"; exit 1; fi
```

```powershell
# Windows CI
.\scripts\build_templates.ps1 -GodotPath $env:GODOT_PATH -Platforms "all" -Clean
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
```

For GitHub Actions:
1. Install Godot + export templates in the workflow
2. Run the build script with `--platforms all`
3. Archive `templates/` as a build artifact


## Troubleshooting

| Problem                              | Solution                                    |
|--------------------------------------|---------------------------------------------|
| "Preset not found" error             | Open Godot → Project → Export — verify preset names match |
| "No export template found"           | Install export templates: Editor → Manage Export Templates → Download |
| project.godot stuck on player scene  | Run `--restore-only` / `-RestoreOnly`       |
| Cross-platform build fails           | You need export templates for the target OS on the build machine |
| macOS export on non-Mac              | Works for unsigned builds. Code-signing and notarization require a Mac + Apple Developer account |
| Binary + .pck version mismatch      | Rebuild both after any Godot version change |
| First-frame stutter in Player        | Verify `shader_baker/enabled=true` in the preset — should be set on all presets |
| GDExtension DLL error during export  | Run the build without `-IncludeGDExtensions` (default) or ensure the addon has binaries for each target platform |
| `~*.TMP` file errors during export   | Close Godot, antivirus, and retry — the script auto-cleans these but locked files need manual attention |


## File Reference

| File                                          | Purpose                              |
|-----------------------------------------------|--------------------------------------|
| `scripts/build_templates.ps1`                 | PowerShell build script (all OSes)   |
| `scripts/build_templates.sh`                  | Bash build script (Linux/macOS)      |
| `export_presets.cfg`                          | Godot export preset definitions      |
| `templates/`                                  | Built Player/Editor binaries (.gitignored) |
| `addons/gonodes/core/gn_patch_exporter.gd`   | Quick Build copy logic (runtime)     |
