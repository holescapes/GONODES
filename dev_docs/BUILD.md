# GONODES Build System

> **Audience:** Contributors, CI/release engineers, advanced users.  
> **User-facing version:** `addons/gonodes/help/building.md` (accessible via in-editor Help window)

This document is the complete build system reference with internals-level
detail: export preset tuning, release optimizations, GDExtension handling
mechanics, main-scene swap implementation, and CI pipeline setup.


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

# Shortcut: build everything (Player + Editor, all platforms)
.\scripts\build_templates.ps1 -BuildAll -Clean
```

### Linux / macOS (Bash)

```bash
# Build Player for the current host platform (auto-detected)
./scripts/build_templates.sh --godot /path/to/godot

# Build Player for all desktop platforms
./scripts/build_templates.sh --godot /path/to/godot --platforms all

# Build both Player and Editor for all platforms, clean first
./scripts/build_templates.sh --godot /path/to/godot --platforms all --include-editor --clean

# Shortcut: build everything (Player + Editor, all platforms)
./scripts/build_templates.sh --build-all --clean
```


## Script Parameters

### PowerShell (`build_templates.ps1`)

| Parameter              | Default          | Description                                        |
|------------------------|------------------|----------------------------------------------------||
| `-GodotPath`           | auto-detect      | Path to the Godot editor executable                |
| `-ProjectPath`         | script's parent  | GONODES project root (contains `project.godot`)    |
| `-OutputDir`           | `<project>/templates` | Where templates are written                   |
| `-Platforms`           | host platform    | Comma-separated list, or `"all"`                   |
| `-BuildAll`            | off              | Shortcut: Player + Editor for all platforms        |
| `-IncludeEditor`       | off              | Also build Editor binaries                         |
| `-GDExtensions`        | `auto`           | GDExtension handling mode: `auto`, `all`, `none`, or addon names |
| `-Clean`               | off              | Remove templates/ before building                  |
| `-RestoreOnly`         | off              | Recovery: restore `project.godot` after interruption|

### Bash (`build_templates.sh`)

| Flag               | Default          | Description                                       |
|--------------------|------------------|---------------------------------------------------|
| `--godot PATH`     | auto-detect      | Path to the Godot editor binary                   |
| `--project PATH`   | script's parent  | GONODES project root                              |
| `--output PATH`    | `<project>/templates` | Where templates are written                  |
| `--platforms LIST`  | host platform    | Comma-separated list, or `all`                   |
| `--build-all`      | off              | Shortcut: Player + Editor for all platforms       |
| `--include-editor` | off              | Also build Editor binaries                        |
| `--gdext MODE`     | `auto`           | GDExtension handling mode: `auto`, `all`, `none`, or addon names |
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

The build scripts control GDExtension handling via the `-GDExtensions` /
`--gdext` parameter, which accepts four modes:

| Mode               | Behaviour |
|--------------------|----------|
| `auto` (default)   | Smart filter: keeps each `.gdextension` library entry whose file exists on disk, comments out missing entries.  If **all** entries are missing the extension is deleted entirely so Godot doesn't attempt to load it. |
| `all`              | Leave everything as-is.  If a referenced library is missing for a target platform that export will fail. |
| `none`             | Delete every `.gdextension` file during the build.  Zero native dependencies; base GONODES always builds cleanly. |
| `name,name,...`    | Named addons (matched by folder name under `addons/`) get `auto` treatment; everything else is deleted. |

Original files are always restored after the build (even on Ctrl+C / error).
The scripts also delete `.godot/uid_cache.bin` before and after changes so
Godot never chokes on stale UID references.

### Examples

```powershell
# Default (auto): host-platform libs kept, missing platform entries removed
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"

# Include all GDExtension libraries as-is
.\scripts\build_templates.ps1 -GDExtensions "all"

# Disable everything (zero native addons)
.\scripts\build_templates.ps1 -GDExtensions "none"

# Include only the ffmpeg addon, disable all others
.\scripts\build_templates.ps1 -GDExtensions "ffmpeg"
```

```bash
# Bash equivalents
./scripts/build_templates.sh --gdext auto     # default
./scripts/build_templates.sh --gdext all
./scripts/build_templates.sh --gdext none
./scripts/build_templates.sh --gdext ffmpeg
```

With `all` mode the script runs a pre-flight check that scans every
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


## Native Library Builds (gn_native)

The `gn_native` addon is a C++ GDExtension that accelerates 16 CPU-heavy
operators (4 IMG, 11 SOP, 1 CHOP) with native inner loops.  The GDScript
wrapper operators in `gn_ext_native` auto-fallback to pure GDScript when
the compiled binaries are unavailable.

### Architecture

```
addons/
├── gn_native/               # C++ GDExtension source
│   ├── SConstruct            # SCons build configuration
│   ├── gn_native.gdextension # Library manifest (all platforms + architectures)
│   ├── godot-cpp/            # Submodule — godot-cpp bindings (4.5 branch)
│   ├── bin/                  # Compiled binaries per platform
│   │   ├── win64/            # Windows x86_64 + ARM64
│   │   ├── linux64/          # Linux x86_64 + ARM64
│   │   └── macos/            # macOS universal (x86_64 + arm64)
│   └── src/                  # C++ source files
│       ├── img/              # GNNativeBlur, GNNativeNoise, GNNativePixelSort, GNNativeEdgeDetect
│       ├── sop/              # GNNativeIsoSurface, GNNativeRay, GNNativeFacet, etc. (11 ops)
│       └── chop/             # GNNativeSmooth
└── gn_ext_native/            # GDScript wrappers + gn_extension.cfg
    └── operators/            # BlurIMGNative, NoiseIMGNative, etc.
```

### Building Locally

Prerequisites: Python 3, SCons, a C++ compiler (MSVC on Windows, g++ on Linux, clang on macOS).

```bash
# 1. Initialize the godot-cpp submodule (first time only)
cd addons/gn_native
git submodule update --init --recursive

# 2. Build for the current platform
scons platform=windows arch=x86_64 target=template_release -j4   # Windows
scons platform=linux   arch=x86_64 target=template_release -j4   # Linux
scons platform=macos   arch=arm64  target=template_release -j4   # macOS (Apple Silicon)
```

Build targets:

| Flag | Value | Purpose |
|------|-------|---------|
| `platform` | `windows`, `linux`, `macos` | Target OS |
| `arch` | `x86_64`, `arm64` | Target architecture |
| `target` | `template_debug`, `template_release` | Debug has symbols; release is optimized + stripped |

Output lands in `bin/<platform>/`.  The `.gdextension` manifest already
has entries for all 5 platform/arch combinations — Godot loads the correct
binary automatically.

### Cross-Compilation

**Linux ARM64 from x86_64:** Install the cross-compiler toolchain and build:

```bash
sudo apt-get install g++-aarch64-linux-gnu
cd addons/gn_native
scons platform=linux arch=arm64 target=template_release -j4
```

SCons auto-detects the `aarch64-linux-gnu-g++` cross-compiler.

**macOS Universal Binary:** Build both architectures and combine with `lipo`:

```bash
cd addons/gn_native
scons platform=macos arch=arm64  target=template_release -j4
scons platform=macos arch=x86_64 target=template_release -j4
cd bin/macos
lipo -create *arm64* *x86_64* -output libgn_native.macos.template_release.universal.dylib
```

**Windows ARM64:** Use MSVC ARM64 cross-tools (installed via Visual Studio):

```powershell
cd addons\gn_native
scons platform=windows arch=arm64 target=template_release -j4
```


## CI Pipelines

GONODES has two tiers of CI:

1. **Player/Editor exports** — build the Godot Player binaries (see [CI / Automation](#ci--automation-player-exports) below).
2. **Native library builds** — compile the C++ GDExtension for all 5 platform targets.

### Native Library CI (gn_native)

Both GitHub Actions and GitLab CI build the native library for 5 targets:

| Target | Runner | Compiler | Notes |
|--------|--------|----------|-------|
| Linux x86_64 | ubuntu-22.04 | g++ | Standard build |
| Linux ARM64 | ubuntu-22.04 | g++-aarch64-linux-gnu | Cross-compiled on x86_64 (free tier) |
| macOS Universal | macos-14 (M1) | clang | arm64 + x86_64 combined via `lipo` |
| Windows x86_64 | Windows runner | MSVC | Standard build |
| Windows ARM64 | Windows runner | MSVC ARM64 cross-tools | Cross-compiled |

#### GitHub Actions (`.github/workflows/build-native.yml`)

Triggers automatically on push to `addons/gn_native/src/**` or `SConstruct`,
plus manual dispatch.  Each platform is a separate job running in parallel.

```bash
# All 5 jobs use the same core command:
cd addons/gn_native
scons platform=<PLATFORM> arch=<ARCH> target=template_release -j4
```

Artifacts are uploaded with 90-day retention.  Download them from the
Actions tab and drop into `addons/gn_native/bin/<platform>/`.

#### GitLab CI (`.gitlab-ci.yml`)

Same 5 targets.  Uses YAML anchors (`&build_rules`) for shared rules.
Triggers on changes to `addons/gn_native/src/**`, `SConstruct`, or
`.gitlab-ci.yml`, plus manual trigger.

### Full Build Workflow

The complete release build flow:

1. **CI builds native libraries** → download artifacts for all 5 platforms
2. **Drop binaries** into `addons/gn_native/bin/{win64,linux64,macos}/`
3. **Build Player templates** locally:
   ```bash
   ./scripts/build_templates.sh --godot /path/to/godot --platforms all --clean
   ```
4. The build script's GDExtension handling (`--gdext auto`) automatically
   includes the native binaries for each target platform.
5. **Result:** Player binaries with native acceleration on all platforms.


## CI / Automation (Player Exports)

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


## UTF-8 Encoding Safeguards

> **Hard Rule 25.23** — see `GONODES_CONTEXT.md` for the full specification.

All text files in this project (`.md`, `.gd`, `.cfg`, `.tscn`, `.gnpatch`)
are UTF-8 without BOM.  Incorrect encoding handling causes **compounding
corruption** that is extremely difficult to reverse.

### The Problem

PowerShell's `Get-Content` defaults to the system's ANSI codepage
(Windows-1252 on Western systems), not UTF-8.  Reading a UTF-8 file and
writing it back produces mojibake: `—` (em-dash) becomes `Ã¢â‚¬â€`,
`ö` becomes `Ã¶`, etc.  Each read/write cycle compounds the damage.

### Rules

1. **Never** use bare `Get-Content` / `Set-Content` on files that may
   contain non-ASCII characters.  Always pass `-Encoding UTF8` on **both**:

   ```powershell
   $content = Get-Content "file.md" -Raw -Encoding UTF8
   # ... modify ...
   Set-Content "file.md" -Value $content -Encoding UTF8
   ```

2. **Prefer Python** for text manipulation involving non-ASCII:

   ```python
   with open(path, 'r', encoding='utf-8') as f:
       content = f.read()
   ```

3. **Corruption signature:** If you see `Ã¢â‚¬â€` instead of `—`, the
   file has been re-encoded through Win-1252.  STOP — do not write it
   again.  Use byte-level repair (see `scripts/fix_encoding.py`).


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
| GDExtension DLL error during export  | Use `-GDExtensions "auto"` (default) or `"none"` to exclude the addon, or ensure it has binaries for each target platform |
| `~*.TMP` file errors during export   | Close Godot, antivirus, and retry — the script auto-cleans these but locked files need manual attention |


## File Reference

| File                                          | Purpose                              |
|-----------------------------------------------|--------------------------------------|
| `scripts/build_templates.ps1`                 | PowerShell build script (all OSes)   |
| `scripts/build_templates.sh`                  | Bash build script (Linux/macOS)      |
| `export_presets.cfg`                          | Godot export preset definitions      |
| `templates/`                                  | Built Player/Editor binaries (.gitignored) |
| `addons/gonodes/core/gn_patch_exporter.gd`   | Quick Build copy logic (runtime)     |
| `addons/gn_native/SConstruct`                 | SCons build config for C++ GDExtension |
| `addons/gn_native/gn_native.gdextension`     | GDExtension manifest (all 5 platforms) |
| `addons/gn_native/godot-cpp/`                | godot-cpp submodule (4.5 branch)     |
| `.github/workflows/build-native.yml`          | GitHub Actions CI — native library   |
| `.gitlab-ci.yml`                              | GitLab CI — native library           |
