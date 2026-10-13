# GONODES Build System

> **Audience:** Contributors, CI/release engineers, advanced users.  
> **User-facing version:** `addons/gonodes/help/building.md` (accessible via in-editor Help window)

This document is the complete build system reference with internals-level
detail: export preset tuning, release optimizations, GDExtension handling
mechanics, main-scene swap implementation, and CI pipeline setup.


## Overview

GONODES uses a **Quick Build** paradigm: pre-built Player binaries are stored
in the `templates/` folder.  When the user clicks **Build** in the editor,
the **Export Patch** dialog opens.  The user picks a target platform (8
options covering desktop, mobile, and web), a renderer (Forward+, Mobile,
or Compatibility), and an output folder.  The exporter copies the correct
Player template + `.pck` + patch + assets + `config.json` to the output
folder.  No Godot export templates are needed at runtime.

Two build scripts automate template creation:

| Script                          | For                                       |
|---------------------------------|-------------------------------------------|
| `scripts/build_templates.ps1`   | PowerShell --- Windows, or any OS with pwsh |
| `scripts/build_templates.sh`    | Bash --- Linux, macOS                       |

Both scripts are functionally identical and produce the same output.


## Fresh Clone — Complete Build

After cloning the repository, nothing is compiled. All native extension
`.gdextension` files ship as `.gdextension.disabled` so Godot starts
cleanly without missing-binary errors.

The repo contains **source only** — SDKs, toolchains, and compiled binaries
are downloaded or built locally (never committed). A fresh clone does not
require any git cleanup.

### Windows prerequisites (from zero)

Install these once before the build steps below:

1. **Python 3.10+** — [python.org](https://www.python.org/downloads/) or
   `winget install Python.Python.3.12`
2. **SCons** — `pip install scons`
3. **MSVC** — Visual Studio 2022 **Build Tools** with the C++ workload
   (not just the installer shell). Example:

   ```powershell
   winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   ```

   `check_env.py` / `build_windows.ps1` locate Build Tools via `vswhere -products *`
   (the IDE-only default miss Build Tools).
4. **Godot** matching `versions.env` → `GODOT_VERSION` (currently **4.7.2**) —
   [godotengine.org/download](https://godotengine.org/download). Prefer the
   `*_console.exe` for scripts. Point the build/test tooling at it:

   ```powershell
   $env:GONODES_GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
   ```

5. **Export templates** (only needed for Player/editor export, not for compiling
   GDExtensions) — install the matching `.tpz` for your Godot version under
   `%APPDATA%\Godot\export_templates\<version>.stable\` (Editor → Manage Export
   Templates, or unzip the downloaded `.tpz` so `version.txt` sits in that folder).

On Windows, set UTF-8 before running any project Python script (avoids
`UnicodeEncodeError` on the default cp1252 console):

```powershell
$env:PYTHONUTF8 = "1"
```

### First-time Windows checklist (scripts for each step)

| Step | Script / command | What it does |
|------|------------------|--------------|
| 0. Pre-flight | `python scripts/check_env.py` | Python, SCons, MSVC (Build Tools), Godot, godot-cpp, SDK probes |
| 1. Fetch deps | `python setup_deps.py` | Clones godot-cpp; runs extension `setup` / `vendor_clone` from `build.cfg` |
| 1b. Setups for build tier | `python scripts/run_extension_setups.py --for-build --tier all` | Same setups scoped to the tier you will compile (also run by `build_windows.ps1`) |
| 2–3. Compile | `.\scripts\build_windows.ps1` | Injects MSVC env, builds godot-cpp + `build/scons tier=all` |
| 2–3. Faster subset | `.\scripts\build_windows.ps1 -Shipped` | Core + extension tiers only (skips optional depth/NDI/Blackmagic) |
| 4. Verify DLLs | `python scripts/check_builds.py` | Lists which native libs exist |
| 5. Activate | `python scripts/sync_gdextensions.py` | Renames `.gdextension.disabled` ↔ `.gdextension` when binaries exist (also runs post-`scons`) |
| 6. Import + test | `& $env:GONODES_GODOT --headless --path . --import` then `-s res://tests/test_runner.gd` | Register `class_name`s; run suite |
| 7. Player templates (optional) | `.\scripts\build_templates.ps1` | Godot export → `templates/` for Quick Build |
| 7b. One extension pack (optional) | `.\scripts\pack_extension.ps1 -ExtensionName gn_ext_mapper` | Writes `templates/extensions/gn_ext_mapper.pck`. Refuses `gn_ext_native`. The player export still includes addons. |

**Quick path (Windows):** one script covers steps 1–3:

```powershell
$env:PYTHONUTF8 = "1"
$env:GONODES_GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
python scripts/check_env.py
.\scripts\build_windows.ps1
python scripts/check_builds.py
```

`build_windows.ps1` defaults to `tier=all`. Optional proprietary SDKs (NDI,
Blackmagic, Azure Kinect, RealSense, …) are **skipped** when probe files are
missing — not fatal. Use `-Shipped` for a faster first compile (no optional tier).

> **Note:** Empty SDK folders that contain headers but no `.lib` files are treated
> as missing (link would otherwise fail with LNK1181).

### Step-by-step (all platforms)

```bash
# 0. Pre-flight — verify tools, godot-cpp, and SDK presence
python scripts/check_env.py

# 1. Fetch all dependencies (godot-cpp + extension build.cfg setups)
#    Reads `setup` / `vendor_clone` from each native/build.cfg; also picks up
#    setup_*.py in extension roots without a build.cfg entry (e.g. webrender).
#    Extension script failures are non-fatal (e.g. optional ML models).
python setup_deps.py

# 1b. Before building, run setups for every extension you plan to compile
#     (default Windows script uses tier=all; optional SDK downloaders included):
python scripts/run_extension_setups.py --for-build --tier all

# To fetch ONLY godot-cpp and skip extension SDKs (faster for CI/testing):
# python setup_deps.py --core

# 2. Build godot-cpp (once per Godot version)
#    Windows: run inside MSVC environment (Developer Command Prompt or build_windows.ps1)
cd addons/gn_ext_native/native/godot-cpp
scons platform=windows arch=x86_64 target=template_release -j8
cd ../../../..

# 3. Build all native extensions
cd build
scons platform=windows arch=x86_64 target=template_release -j8
cd ..
# Post-build hook automatically runs sync_gdextensions.py to activate extensions.
# Extensions whose SDKs are missing are SKIPPED (not fatal) — e.g. NDI when
# the SDK is absent, or OpenCV on Linux/macOS until the system package is
# installed (setup_opencv.py writes native/opencv_sdk/.system_found).
# Runtime DLLs declared in build.cfg (runtime_dlls field) are auto-copied to their
# destination (bin/ for most; runtime/ for extensions that need Godot [dependencies]
# pre-loading, since native/ is .gdignored and invisible to res:// paths).

# 4. Bundle toolchains for user C++/Python nodes (optional)
python scripts/bundle_toolchain.py

# 5. Export Player templates (optional — only needed for Quick Build)
.\scripts\build_templates.ps1 -Platforms all
```

> **Note:** `setup_deps.py` (step 1) already runs `setup_python.py` and
> `setup_opencv.py` (Windows). You do **not** need a separate step before
> building `gn_ext_user_python` or `gn_ext_opencv`.

### What `setup_deps.py` downloads

These stay out of git. The same `setup` and `vendor_clone` lines run locally and in GitHub Actions.

| Library | License | How it arrives |
|---------|---------|----------------|
| CPython 3.10 + NumPy | PSF / BSD | `setup_python.py --bundle` |
| ONNX Runtime | MIT | `setup_ml.py --sdk-only` (YOLOv8 weights are AGPL and are not downloaded) |
| OpenCV | Apache 2.0 | Windows: official SDK zip. Linux and macOS: `libopencv-dev` / `brew install opencv` (the CI build installs that package) |
| Spout2 | BSD | git clone on Windows |
| Syphon | BSD-3 | git clone on macOS |
| CEF | MIT/BSD | `setup_cef.py` prebuilt binaries |

### SDKs you install yourself

`python scripts/show_manual_sdks.py` prints which of these are missing and the folder the build probe expects. A missing one does not stop the rest of the build.

| SDK | Why it is not fetched | Where to read the steps |
|-----|------------------------|-------------------------|
| NDI | Proprietary | `addons/gn_ext_ndi/README.md` |
| Blackmagic DeckLink | Proprietary | `addons/gn_ext_blackmagic/README.md` |
| Azure Kinect, Ultraleap | Proprietary device SDKs | `addons/gn_ext_depth_sensor/README.md` |
| Intel RealSense | Apache 2.0, shipped as an installer | same depth-sensor README |
| FFmpeg | LGPL shared libraries, no fetch script in this repo | `addons/gn_ext_ffmpeg/README.md` |

Unified `build/scons` continues when optional extensions are skipped.

**Build selection** (see `build/gn_ext_plan.py`):

| Command | Builds |
|---------|--------|
| `scons` | **Shipped:** `tier=core` + `tier=extension` + `gn_ext_native`. Skips optional tier, wrong platform, and missing SDKs |
| `scons tier=all` | All tiers (optional included when SDK probes pass) |
| `scons tier=core` | Core tier + `gn_ext_native` |
| `scons tier=optional` | Optional tier only (NDI, Blackmagic, depth backends, …) |
| `scons tier=minimal` | `default=true` extensions only (fast subset) |
| `scons exts=a,b,c` | Explicit list |
| `scons ext=gn_ext_hap` | Single extension |

Inspect before building: `python scripts/list_extensions.py --tier all` or `cd build && scons --list-extensions`.

See [NEW_EXTENSION_CHECKLIST.md](NEW_EXTENSION_CHECKLIST.md) for the extension author checklist.

### First test run (after build)

Godot must import the project once to register `class_name` globals. Use the
console binary and set `GONODES_GODOT` (see prerequisites):

```powershell
& $env:GONODES_GODOT --headless --path . --import
& $env:GONODES_GODOT --headless --path . -s res://tests/test_runner.gd
```

See [dev_docs/TESTING.md](TESTING.md) for filters and tags.

### Runtime Dependencies

Some native extensions link against third-party shared libraries at load-time.
The build system handles this via `runtime_dlls` in each extension's `native/build.cfg`:

```ini
[windows]
libs = opencv_world4100
runtime_dlls = opencv_sdk/opencv/build/x64/vc16/bin/opencv_world4100.dll
```

During build step 3, `gn_build.py` copies these DLLs to the output directory.

#### Important: `.gdignore` and `res://` path resolution

The `native/` directory in every extension has a `.gdignore` file, which prevents
Godot's editor VFS from scanning its contents. A side effect: `res://` paths pointing
inside `native/` **cannot be resolved by Godot** — this means:

- `[dependencies]` entries in `.gdextension` that point inside `native/` are silently ignored
- Godot will fail to pre-load those DLLs, causing Error 126 when loading the main library

**Rule:** If a runtime DLL must appear in a `[dependencies]` section, it MUST live outside
`native/`. Use `runtime_dlls_dest` in `build.cfg` to copy it to a non-gdignored location:

```ini
[windows]
runtime_dlls = bin/win64/python3.dll, bin/win64/python310.dll
runtime_dlls_dest = bin/win64   # relative to extension root, NOT native/
```

OpenCV's `opencv_world4100.dll` doesn't need pre-loading (Windows finds it via
`LOAD_WITH_ALTERED_SEARCH_PATH` in the same dir as the DLL) so it stays in `bin/`.
Python's `python3.dll`/`python310.dll` DO need pre-loading, so they live in `bin/win64/`.

If you get "Could not find module ... (or one of its dependencies)" errors, verify:
1. The SDK is present (e.g., `native/opencv_sdk/` for OpenCV)
2. `runtime_dlls` paths in `build.cfg` are correct (relative to `native/`)
3. If the DLL needs pre-loading: set `runtime_dlls_dest` to a path outside `native/`
4. The `.gdextension` `[dependencies]` section uses the non-`native/` path


## When to Rebuild Templates

Rebuild the templates whenever you:

- **Upgrade Godot** — export templates are version-locked.  A Player built
  with an older Godot won't load a `.pck` from a newer editor.  Always rebuild
  templates after updating the engine (`versions.env` → `GODOT_VERSION`).
- **Make a GONODES release** — ensures the Player binaries include any new
  operators, cook engine changes, or scene modifications.
- **Add or change export presets** — new architecture, code-signing, etc.

> **Current Godot version: 4.7.2 stable**
>
> When you upgrade Godot, also update the Godot export templates:
> **Editor → Manage Export Templates → Download for Current Version**.
> Also update `versions.env` at the project root (see below).


## Dependency Version Management

All external dependency versions are centralized in `versions.env` at the
project root.  This is the **single source of truth** — `setup_deps.py`,
CI workflows, and the release checklist all read from it.

```bash
# versions.env
GODOT_VERSION=4.7.2
GODOTCPP_BRANCH=4.5
```

### Upgrading Godot or godot-cpp

1. Edit `versions.env` with the new values.
2. Run `python scripts/check_versions.py` to verify all CI workflows match.
3. Fix any reported mismatches in `.github/workflows/*.yml`.
4. Run `python setup_deps.py --core` to re-fetch godot-cpp at the new branch.
5. Rebuild godot-cpp and all native extensions (see "Fresh Clone" above).
6. Rebuild Player templates (see below).

### Validation

```bash
python scripts/check_versions.py
# Output: "All CI workflows match versions.env ✓"
```

The script scans every `.yml`/`.yaml` file under `.github/workflows/` for
`GODOT_VERSION:` and `GODOTCPP_BRANCH:` entries and verifies they match
`versions.env`. It also checks `addons/gonodes/template_source.cfg`.
Run it in CI as a pre-flight check to prevent version drift.


## Prerequisites

1. **Godot editor binary matching `versions.env`** --- can be the standard editor or a console
   build (console build recommended for CI, produces better log output).

2. **Godot export templates** --- install via `Editor --> Manage Export Templates`
   in the Godot editor.  Downloading "for Current Version" installs templates
   for all platforms at once (desktop, mobile, and web).

3. **Export presets** --- the project ships with optimized presets for all 8
   platform targets (5 desktop + Android + iOS + Web) in `export_presets.cfg`.

4. **Platform-specific SDKs** (mobile only):
   - **Android**: Android SDK + JDK --- configure in Godot's
     `Editor --> Editor Settings --> Export --> Android`
   - **iOS**: Requires macOS with Xcode (cannot build from Windows/Linux)


## Quick Start

### Windows (PowerShell)

```powershell
# Build Player for the current host platform (auto-detected)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe"

# Build Player for all platforms (desktop + mobile + web)
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe" -Platforms "all"

# Build just web + android
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe" -Platforms "web,android"

# Build both Player and Editor for all platforms, clean first
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot_console.exe" -Platforms "all" -IncludeEditor -Clean

# Shortcut: build everything (Player + Editor, all platforms)
.\scripts\build_templates.ps1 -BuildAll -Clean
```

> **Note:** On PowerShell 5.1 (Windows default), use
> `powershell -ExecutionPolicy Bypass -File .\scripts\build_templates.ps1 ...`
> if you get an execution policy error.

### Linux / macOS (Bash)

```bash
# Build Player for the current host platform (auto-detected)
./scripts/build_templates.sh --godot /path/to/godot

# Build Player for all platforms (desktop + mobile + web)
./scripts/build_templates.sh --godot /path/to/godot --platforms all

# Build just web + android
./scripts/build_templates.sh --godot /path/to/godot --platforms web,android

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

| Platform          | OS      | Architecture | Template folder             |
|-------------------|---------|--------------|-----------------------------|
| `windows_x86_64`  | Windows | Intel/AMD 64 | `templates/windows_x86_64/` |
| `windows_arm64`   | Windows | ARM 64       | `templates/windows_arm64/`  |
| `linux_x86_64`    | Linux   | Intel/AMD 64 | `templates/linux_x86_64/`   |
| `linux_arm64`     | Linux   | ARM 64       | `templates/linux_arm64/`    |
| `macos`           | macOS   | Universal    | `templates/macos/`          |
| `android`         | Android | ARM 64       | `templates/android/`        |
| `ios`             | iOS     | ARM 64       | `templates/ios/`            |
| `web`             | Web     | WASM         | `templates/web/`            |

When no `--platforms` is given, both scripts auto-detect the host OS and
architecture and build for the current machine only (desktop only).
Mobile and web are only built when explicitly requested or with `"all"`.


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

The Export Patch dialog automatically finds the correct platform's
template from `templates/<platform>/` and shows an availability hint
if the template is missing.


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

**Build-time filtering** is handled by the build scripts (see below).
**Runtime gating** is handled by the extension registry's `platforms`,
`architectures`, `renderers`, and `dependencies` keys in `gn_extension.cfg`
— see [CONTRIBUTING.md § 5](CONTRIBUTING.md) for the full format.  This
prevents operators from appearing in the palette on unsupported OS/
architecture/renderer combos even when the `.gdextension` file is present
(e.g., Syphon on Windows, Spout on ARM64 Windows, or compute-only
extensions on the Compatibility renderer).

The full runtime guard pipeline (in order):

| Level | Guard | Mechanism |
|-------|-------|-----------|
| GDExtension load | Binary exists on disk | `sync_native_extensions()` — `.gdextension` ↔ `.disabled` rename |
| Extension manifest | `platforms` | `OS.get_name()` match |
| Extension manifest | `architectures` | `Engine.get_architecture_name()` match |
| Extension manifest | `renderers` | `GNGpuContext.get_current_renderer()` match |
| Extension manifest | `dependencies` | `ClassDB.class_exists()` per class |
| Per-node cook | `requires_compute()` | `GNGpuContext.is_compute_available()` — falls back to `_cook_cpu()` or skips |
| Per-node cook | `supported_renderers()` | Runtime renderer match or skip with warning badge |
| Per-node cook | `supported_platforms()` | Runtime OS match or skip with warning badge |

**Auto-activation** is handled by `GNExtensionRegistry.sync_native_extensions()`,
called from the plugin's `_enter_tree()`.  It scans every subdirectory
within each `gn_ext_*` folder for `.gdextension` files whose platform
binary is missing, renaming them to
`.gdextension.disabled` (so Godot won't try to load them).  When the
binary appears, the file is renamed back.  This keeps all native
artifacts inside the extension folder (self-containment) and eliminates
the `GDExtension dynamic library not found` console errors that occur
when extensions are checked in but not yet compiled on the current
machine.  See [CONTRIBUTING.md § 5 — Native Binary Auto-Activation](CONTRIBUTING.md)
for the full behaviour.

The build scripts control GDExtension handling via the `-GDExtensions` /
`--gdext` parameter, which accepts four modes:

| Mode               | Behaviour |
|--------------------|----------|
| `auto` (default)   | Smart filter: keeps each `.gdextension` library entry whose file exists on disk, comments out missing entries.  If **all** entries are missing the extension is deleted entirely so Godot doesn't attempt to load it.  Each platform export also excludes any addon folder that has no library for that OS and architecture, so the player does not log missing-library errors for binaries it cannot load. |
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


## Export Patch Dialog (Runtime)

The user-facing Export Patch dialog (`gn_export_dialog.gd`) provides:

- **Platform dropdown** --- 8 concrete targets (all the platform names above)
- **Renderer dropdown** --- Forward+, Mobile, Compatibility (independent of platform)
- **Template availability hint** --- orange warning if no template exists for
  the selected platform
- **Compatibility scan** --- checks every node in the patch against the selected
  platform + renderer and reports incompatible/fallback nodes

The renderer is not hardcoded per platform.  The user chooses based on their
target hardware.  The selected renderer is written to `config.json` alongside
the patch path.

`config.json` for desktop/mobile:
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

`config.json` for web:
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

The `renderer` field is **active** --- on startup the Player compares it
against the running renderer and re-launches with `--rendering-method` if
they differ.  A `CONFIG_OPTIONS.txt` file is also generated alongside
config.json by the exporter, documenting all available fields and values.


## Export Presets

All presets are defined in `export_presets.cfg` at the project root:

| Preset                      | Index | Purpose         |
|-----------------------------|-------|-----------------||
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
| Player Android ARM64        | 10    | Build script    |
| Player iOS ARM64            | 11    | Build script    |
| Player Web                  | 12    | Build script    |

Editor builds are only available for the 5 desktop platforms.  Mobile and
web have Player-only presets (no editor builds --- the GONODES editor is
desktop-only).


## Extension Self-Containment

**Every GN extension must be entirely self-contained inside its
`addons/gn_ext_<name>/` folder.**  Never place extension assets in
`addons/gonodes/` or any other directory outside the extension root.

This applies to operator scripts, shader presets, help patches, textures,
data files, and any other asset the extension provides.  The core discovery
systems (`gn_script_helper`, `gn_help_window`, `GNExtensionRegistry`) scan
`gn_ext_*/` directories automatically — no manual registration outside the
extension folder is needed.

See the existing extensions for reference:

| Extension | Path | What it contains |
|-----------|------|-----------------|
| `gn_ext_native` | `addons/gn_ext_native/` | C++ native operators + GDScript wrappers (103 ops, 9 phases) |
| `gn_ext_shadertoy` | `addons/gn_ext_shadertoy/` | Shadertoy GLSL translator + shader presets |
| `gn_ext_isf` | `addons/gn_ext_isf/` | ISF shader translator + shader presets |
| `gn_ext_ffmpeg` | `addons/gn_ext_ffmpeg/` | FFmpeg video I/O operators |
| `gn_ext_spout` | `addons/gn_ext_spout/` | Windows Spout2 texture sharing (SpoutInTOP, SpoutOutTOP) |
| `gn_ext_syphon` | `addons/gn_ext_syphon/` | macOS Syphon texture sharing (SyphonInTOP, SyphonOutTOP) |
| `gn_ext_video_capture` | `addons/gn_ext_video_capture/` | Cross-platform webcam/capture device input (VideoDeviceInIMG) |
| `gn_ext_midi` | `addons/gn_ext_midi/` | Cross-platform MIDI I/O via RtMidi (RtMidiInCHOP, RtMidiOutCHOP) |
| `gn_ext_gpu_encode` | `addons/gn_ext_gpu_encode/` | Hardware GPU video encoding (MovieFileOutTOP) |
| `gn_ext_mapper` | `addons/gn_ext_mapper/` | Projection mapping toolkit — GPU warping, edge blend, masking (7 TOPs) |
| `gn_ext_hap` | `addons/gn_ext_hap/` | HAP codec GPU-direct video (HapInTOP, HapOUT) |
| `gn_ext_serial` | `addons/gn_ext_serial/` | Serial port send/receive (SerialSendDAT, SerialReceiveDAT) |
| `gn_ext_ndi` | `addons/gn_ext_ndi/` | NDI video-over-IP (4 ops — requires NDI SDK) |
| `gn_ext_ml` | `addons/gn_ext_ml/` | ML inference via ONNX Runtime (7 ops — requires ONNX Runtime) |
| `gn_ext_depth_sensor` | `addons/gn_ext_depth_sensor/` | Depth sensors — Azure Kinect, RealSense, Ultraleap (5 ops) |
| `gn_ext_blackmagic` | `addons/gn_ext_blackmagic/` | Blackmagic DeckLink I/O (3 ops — requires DeckLink SDK) |
| `gn_ext_host_bridge` | `addons/gn_ext_host_bridge/` | Internal bridge between libgonodes C API and GNEmbeddedHost (GDExtension, no operators) |

> **Note:** This table is a reference snapshot. New extensions added to
> `addons/gn_ext_*/` are auto-discovered by the build system, CI pipelines,
> and `setup_deps.py` — no manual registration needed. Update this table
> when adding or removing extensions for documentation purposes.

Full details on the required directory layout and the discovery mechanism
are in [CONTRIBUTING.md → Extension Self-Containment Rule](CONTRIBUTING.md#extension-self-containment-rule).


## libgonodes (Embedding SDK)

`libgonodes/` is the C shared library for embedding GONODES in third-party
apps.  It uses CMake (not SCons) and has its own version (`LIBGONODES_VERSION`
in `versions.env`, currently **2.5.0**).

libgonodes has a **separate release cycle** — it only needs rebuilding when
the Godot version bumps or the C API changes.  See
[RELEASE_CHECKLIST.md → libgonodes](RELEASE_CHECKLIST.md#libgonodes-separate-release-cycle)
for the full release procedure.

### Quick build

```bash
# 1. Build LibGodot (from Godot source tree):
scons platform=windows target=template_release libgodot=yes -j8

# 2. Build libgonodes:
cd libgonodes
mkdir build && cd build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --config Release

# 3. Ship: libgonodes.dll + libgodot.dll + GONODES .pck in the same directory.
```

See `libgonodes/README.md` for the full C API reference and examples.


## Native Library Builds (gn_native)

The `gn_ext_native` extension is a C++ GDExtension that accelerates 103
CPU-heavy operators (46 SOP, 28 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP, 1 Serial)
with native inner loops across 9 build phases.  The GDScript wrapper
operators in `gn_ext_native` auto-fallback to pure GDScript when the
compiled binaries are unavailable.

### Architecture

```
addons/gn_ext_native/
├── gn_extension.cfg          # Extension descriptor (103 operators)
├── native/                   # C++ GDExtension source
│   ├── SConstruct            # SCons build configuration
│   ├── gn_native.gdextension # Library manifest (all platforms + architectures)
│   ├── godot-cpp/            # Cloned at setup time (not tracked in git)
│   ├── bin/                  # Compiled binaries per platform (gitignored)
│   │   ├── win64/            # Windows x86_64 + ARM64
│   │   ├── linux64/          # Linux x86_64 + ARM64
│   │   └── macos/            # macOS universal (x86_64 + arm64)
│   └── src/                  # C++ source files
│       ├── sop/              # 46 SOP operators (geometry processors)
│       ├── chop/             # 28 CHOP operators (signal processing)
│       ├── img/              # 5 IMG operators (CPU image processing)
│       ├── top/              # 4 TOP operators (texture analysis/bridges)
│       ├── vol/              # 9 VOL operators (volumetric data)
│       ├── pop/              # 9 POP operators (particle system)
│       └── serial/           # 1 Serial operator (hardware I/O)
└── operators/                # GDScript wrappers (auto-fallback)
    ├── sop/
    ├── chop/
    ├── img/
    ├── top/
    ├── vol/
    └── pop/
```

### Building Locally

Prerequisites: Python 3, SCons, a C++ compiler (MSVC on Windows, g++ on Linux, clang on macOS).

```bash
# 1. Fetch all dependencies (first time only, from repo root)
python setup_deps.py --core

# 2. Build for the current platform
cd addons/gn_ext_native/native
scons platform=windows arch=x86_64 target=template_release -j4   # Windows
scons platform=linux   arch=x86_64 target=template_release -j4   # Linux
scons platform=macos   arch=arm64  target=template_release -j4   # macOS (Apple Silicon)
```

Build targets:

| Flag | Value | Purpose |
|------|-------|---------|
| `platform` | `windows`, `linux`, `macos` | Target OS |
| `arch` | `x86_64`, `arm64` | Target architecture |
| `target` | `template_release` | Release-optimized (debug builds not used) |

Output lands in `bin/<platform>/`.  The `.gdextension` manifest already
has entries for all 5 platform/arch combinations — Godot loads the correct
binary automatically.

### Cross-Compilation

**Linux ARM64 from x86_64:** Install the cross-compiler toolchain and build:

```bash
sudo apt-get install g++-aarch64-linux-gnu
cd addons/gn_ext_native/native
scons platform=linux arch=arm64 target=template_release -j4
```

SCons auto-detects the `aarch64-linux-gnu-g++` cross-compiler.

**macOS Universal Binary:** Build both architectures and combine with `lipo`:

```bash
cd addons/gn_ext_native/native
scons platform=macos arch=arm64  target=template_release -j4
scons platform=macos arch=x86_64 target=template_release -j4
cd bin/macos
lipo -create *arm64* *x86_64* -output libgn_native.macos.template_release.universal.dylib
```

**Windows ARM64:** Use MSVC ARM64 cross-tools (installed via Visual Studio):

```powershell
cd addons\gn_ext_native\native
scons platform=windows arch=arm64 target=template_release -j4
```


## Writing C++ Extensions for GONODES

If you need native-speed algorithms — mesh processing, signal filtering,
image kernels, physics solvers, or wrapping an external C/C++ library — you
can build a GDExtension that plugs into the GONODES operator model.

### How It Works

1. **Create a self-contained extension folder:** `addons/gn_ext_<name>/`
   following the [Extension Self-Containment](#extension-self-containment)
   rules above.

2. **Add a `native/` subfolder** for C++ source, a `SConstruct` build
   script. godot-cpp is shared from `gn_ext_native/native/godot-cpp/` (cloned by `setup_deps.py`).

3. **Write C++ processor classes** that extend `godot::RefCounted`.
   Expose a `process()` (or similar) method via `ClassDB::bind_methods()`.
   This is the hot inner loop — pixel iteration, vertex math, FFT, etc.

4. **Write GDScript wrapper operators** in `operators/<family>/` that call
   the C++ class when available and fall back to pure GDScript otherwise:

   ```gdscript
   func _cook(dt: float) -> void:
       if ClassDB.class_exists("GNNativeMyAlgo"):
           var processor = ClassDB.instantiate("GNNativeMyAlgo")
           processor.process(input_data, params)
       else:
           _cook_gdscript(dt)  # pure GDScript fallback
   ```

5. **Register operators** in `gn_extension.cfg` — the registry discovers
   them automatically.

6. **Add a `build.cfg`** declaring your library name, supported platforms,
   sources, and any system libraries or frameworks. Add the 6-line
   `SConstruct` shim. See above for the full format and example.

7. **Build** with `cd build && scons ext=gn_ext_<name> platform=<PLATFORM> -j4`,
   or from the extension directory: `cd addons/gn_ext_<name>/native && scons`.

Use `gn_ext_hap` as the simplest reference for a new extension. Copy its
`build.cfg` and `SConstruct` to bootstrap quickly.

### std:: vs Godot-Native Types in C++

When writing GDExtension C++ code, you have access to both the C++ Standard
Library and Godot's own container/math types. Here's what works best:

**Use std:: for internal computation:**

- `std::vector<T>`, `std::sort`, `std::unordered_map` — battle-tested,
  full-featured, and familiar to any C++ developer.
- `std::sin`, `std::cos`, `std::sqrt` — identical underlying C library
  calls; no performance difference vs `Math::sin()`.
- Lambda-based sorting with `std::sort` is cleaner than Godot's
  `SortArray` with comparator structs.

**Use Godot types at the API boundary:**

- `PackedVector3Array`, `PackedFloat32Array`, `PackedByteArray` — these
  are what GDScript passes in and expects back. Accept them as parameters,
  return them as results.
- `Vector3`, `Color`, `Transform3D` — use Godot's math types in your
  function signatures so GDScript can call you without conversions.
- `String`, `Dictionary`, `Array` — for any data crossing the
  GDScript↔C++ boundary.

**The hybrid pattern (recommended):**

```cpp
// API boundary: Godot types in the function signature
void GNNativeMyAlgo::process(PackedVector3Array p_points, float p_threshold) {
    // Internal: std:: for the heavy lifting
    const Vector3 *pts = p_points.ptr();
    int count = p_points.size();
    std::vector<int> indices(count);
    std::iota(indices.begin(), indices.end(), 0);
    std::sort(indices.begin(), indices.end(), [&](int a, int b) {
        return pts[a].y < pts[b].y;
    });
    // ... algorithm using std:: containers and math ...
    // API boundary: write results back to Godot types
    PackedVector3Array result;
    result.resize(count);
    // ...
}
```

This gives you the best of both worlds: Godot types where GDScript needs
them, std:: where raw performance and API richness matter.

**Why not all-Godot internally?**

- `LocalVector<T>` (Godot's internal vector) lacks sized constructors,
  `.assign()`, range constructors, and algorithm compatibility.
- `SortArray` requires comparator structs instead of lambdas.
- `HashMap` works fine but has a different API from `std::unordered_map`.
- The performance difference is negligible — both `std::vector` and
  `LocalVector` are contiguous arrays with identical cache behavior.
- Using std:: keeps your C++ idiomatic and portable. If you later want to
  reuse an algorithm outside Godot, it just works.

**Exception:** If you're modifying existing Godot engine code or writing
code that must integrate deeply with Godot internals (custom servers,
rendering callbacks), prefer Godot types throughout for consistency with
the engine codebase.

### Wrapping External Libraries

For external C/C++ libraries (FFmpeg, RtMidi, NDI SDK, OpenCV, etc.):

1. Place the library headers and pre-built binaries (or source) inside
   your extension's `native/` folder.
2. Update `SConstruct` to add include paths and link flags.
3. Write a thin `RefCounted` wrapper class that exposes the library
   functionality to GDScript via `ClassDB`.
4. Add the `.dll`/`.so`/`.dylib` to your `.gdextension` manifest so
   Godot loads them alongside your extension.

See `gn_ext_ffmpeg` for a working example of wrapping an external library.

### Unified Build System for All Native Extensions

GONODES uses a **unified, declarative build system** for all C++ GDExtension
addons (except `gn_ext_native`, which uses godot-cpp's SConstruct directly).

Each extension declares its configuration in a small `build.cfg` INI file.
A shared Python module (`build/gn_build.py`) reads these configs and handles
all platform detection, compiler setup, godot-cpp linking, and cross-compilation.

#### Architecture

```
build/
  gn_build.py          # Shared build logic (platform detection, env setup, source collection)
  SConstruct           # Root entry point — auto-discovers and builds all extensions
  ci_discover.py       # CI helper — outputs GitHub Actions matrix JSON

addons/gn_ext_<name>/
  native/
    build.cfg          # Declarative build config (name, platforms, sources, libs)
    SConstruct         # Thin shim (6 lines) — delegates to build/gn_build.py
    src/               # C++ source files
    bin/               # Compiled output (per-platform subdirectories)
```

#### build.cfg Format

Each extension's `build.cfg` declares what to build and where:

```ini
# build.cfg — Example (HAP codec)
[library]
name = gn_hap_codec
entry_symbol = gn_hap_codec_init
platforms = windows, macos, linux
tier = core
default = true

[sources]
cpp = src/*.cpp
thirdparty_c = hap/*.c
thirdparty_cc = snappy/*.cc
thirdparty_cpp = squish/*.cpp
include_dirs = hap, snappy, squish

[windows]
libs = <system libs if any>
defines = <platform defines if any>

[macos]
frameworks = <macOS frameworks if any>

[linux]
libs = <linux libs if any>
defines = <linux defines if any>
```

| Section | Key | Description |
|---------|-----|-------------|
| `[library]` | `name` | Output library name (e.g., `gn_hap_codec` produces `libgn_hap_codec.<platform>.<target>.<arch>.dll`) |
| | `entry_symbol` | GDExtension init function name |
| | `platforms` | Comma-separated list: `windows`, `macos`, `linux` (or omit for all) |
| | `tier` | `core` (default build set), `extension` (normal pack), or `optional` (proprietary/large SDK) |
| | `default` | `true`/`false` — include in bare `scons` (default: `true` except when `optional=true`) |
| | `optional` | `true` — missing SDK probe skips extension instead of failing unified build |
| | `setup` | Pre-build setup script relative to extension root (e.g., `setup_ml.py --sdk-only --no-enable`). Run by `setup_deps.py` and `scripts/run_extension_setups.py` before compile |
| | `vendor_setup` | Alias for `setup` (legacy) |
| | `vendor_clone` | Git repo + destination dir relative to `native/` (e.g., `https://github.com/leadedge/Spout2.git Spout2`). Cloned by `setup_deps.py` / `run_extension_setups.py` |
| `[sources]` | `cpp` | Glob pattern for C++ sources (default: `src/*.cpp`) |
| | `c` | Glob pattern for C sources |
| | `objcxx` | Glob pattern for Objective-C++ sources (`.mm` files, macOS) |
| | `thirdparty_cpp/c/cc` | Glob patterns for bundled third-party code |
| | `include_dirs` | Comma-separated include directories |
| `[windows]` / `[linux]` / `[macos]` | `libs` | Libraries to link |
| | `lib_dirs` | Library search paths (used to auto-derive `probe` if not set) |
| | `probe` | Comma-separated files that must exist before compile (relative to `native/`). Auto-derived as `{lib_dirs}/{libs}.lib` on Windows when omitted |
| | `defines` | Preprocessor defines |
| | `frameworks` | macOS frameworks (macOS section only) |
| | `libs_<suffix>` / `lib_dirs_<suffix>` | Optional partial SDK backends (see depth_sensor) |

#### All Native Extensions

| Extension | Library Name | Platforms | What It Builds |
|-----------|-------------|-----------|----------------|
| `gn_ext_native` | `gn_native` | All | 92 native operators (uses godot-cpp SConstruct directly) |
| `gn_ext_hap` | `gn_hap_codec` | All | HAP video codec (bundles hap, snappy, squish) |
| `gn_ext_spout` | `gn_spout` | Windows | Spout2 texture sharing (bundles Spout2 SDK) |
| `gn_ext_syphon` | `gn_syphon` | macOS | Syphon texture sharing (ObjC++ bridge) |
| `gn_ext_video_capture` | `gn_video_capture` | All | Webcam/capture (MF, AVFoundation, V4L2) |
| `gn_ext_gpu_encode` | `gn_gpu_encode` | Windows, macOS | Hardware H.264 encoding (MF, VideoToolbox) |
| `gn_ext_midi` | `gn_midi` | All | MIDI I/O (bundles RtMidi) |

#### Prerequisites

- **Python 3.x** and **SCons 4.x** (`pip install scons`)
- **C++ compiler**: MSVC on Windows, g++ on Linux, clang on macOS
- **godot-cpp** cloned and built in `gn_ext_native/native/godot-cpp/`

```bash
# First time: fetch dependencies and build godot-cpp (from repo root)
python setup_deps.py --core
cd addons/gn_ext_native/native/godot-cpp
scons platform=<PLATFORM> arch=<ARCH> target=template_release -j4
```

All other extensions link against this pre-built godot-cpp. No symlinks
or junctions are needed — `gn_build.py` resolves the path automatically.

#### Build Commands

##### Unified Build (from `build/` directory)

```bash
cd build

# Build ALL extensions for the current host platform:
scons -j4

# Build ALL extensions for a specific platform/arch:
scons platform=windows arch=x86_64 target=template_release -j4
scons platform=linux   arch=x86_64 target=template_release -j4
scons platform=linux   arch=arm64  target=template_release -j4
scons platform=macos   arch=arm64  target=template_release -j4
scons platform=macos   arch=x86_64 target=template_release -j4

# Build a SINGLE extension:
scons ext=gn_ext_hap    platform=windows -j4
scons ext=gn_ext_midi   platform=linux   -j4
scons ext=gn_ext_spout  platform=windows -j4   # Spout is Windows-only

# Build gn_ext_native (delegates to its own SConstruct):
scons ext=gn_ext_native platform=windows -j4

# List all discovered extensions and their platform support:
scons --list-extensions
```

**Auto-skip logic:** Extensions that don't support the target platform are
silently skipped. Running `scons platform=linux` will skip `gn_ext_spout`
(Windows-only) and `gn_ext_syphon` (macOS-only) automatically.

##### Standalone Build (from each extension's directory)

Each extension's `SConstruct` is a 6-line shim that delegates to `gn_build.py`.
You can build from the extension directory directly:

```bash
# Standalone build — same as the old per-extension workflow
cd addons/gn_ext_hap/native
scons platform=windows arch=x86_64 target=template_release -j4

cd addons/gn_ext_midi/native
scons platform=linux arch=x86_64 target=template_release -j4
```

This produces identical output to the unified build. Both paths work.

##### Build Flags Reference

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `platform` | `windows`, `linux`, `macos` | Auto-detected from host OS | Target operating system |
| `arch` | `x86_64`, `arm64` | Auto-detected from host CPU | Target architecture |
| `target` | `template_release` | `template_release` | Release-optimized (debug builds not used) |
| `ext` | `gn_ext_<name>` | *(all)* | Build only this extension (unified build only) |
| `-j N` | integer | 1 | Parallel compilation jobs |
| `--list-extensions` | flag | off | Print discovered extensions and exit |

##### Compiler Flags Applied Automatically

| Platform | Flags | Notes |
|----------|-------|-------|
| Windows | `/std:c++17 /EHsc /utf-8 /MT /O2 /DLL` | Static CRT (`/MT`) matches godot-cpp |
| Windows ARM64 | + `/arch:ARM64` | Cross-compiled from x86_64 host |
| Linux | `-std=c++17 -fPIC -O2 -shared` | Position-independent code |
| Linux ARM64 | Uses `aarch64-linux-gnu-g++` | Cross-compiled from x86_64 host |
| macOS | `-std=c++17 -fPIC -O2 -arch <arch> -dynamiclib` | ObjC++ support (`.mm` files) with `-fobjc-arc` |

##### Cross-Compilation

**Linux ARM64 from x86_64:**
```bash
sudo apt-get install g++-aarch64-linux-gnu
cd build
scons platform=linux arch=arm64 target=template_release -j4
```

**macOS Universal Binary:**
```bash
cd build
scons platform=macos arch=arm64  target=template_release -j4
scons platform=macos arch=x86_64 target=template_release -j4
# Then lipo per extension:
cd ../addons/gn_ext_hap/native/bin/macos
lipo -create *arm64* *x86_64* -output libgn_hap_codec.macos.template_release.dylib
```

**Windows ARM64:**
```powershell
cd build
scons platform=windows arch=arm64 target=template_release -j4
```

##### Output Locations

All binaries land in `addons/gn_ext_<name>/native/bin/<platform>/`:

```
addons/gn_ext_hap/native/bin/
  win64/   libgn_hap_codec.windows.template_release.x86_64.dll
  linux64/ libgn_hap_codec.linux.template_release.x86_64.so
  macos/   libgn_hap_codec.macos.template_release.arm64.dylib

addons/gn_ext_spout/native/bin/
  win64/   libgn_spout.windows.template_release.x86_64.dll

addons/gn_ext_midi/native/bin/
  win64/   libgn_midi.windows.template_release.x86_64.dll
  linux64/ libgn_midi.linux.template_release.x86_64.so
  macos/   libgn_midi.macos.template_release.arm64.dylib
```

### Adding a New Native Extension

See **[NEW_EXTENSION_CHECKLIST.md](NEW_EXTENSION_CHECKLIST.md)** for the full step-by-step checklist (build.cfg policy, SDK setup, shipped-build verification, PR checklist).


## CI Pipelines

GONODES has three workflow files in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build-extensions.yml` | Extension/build file changes | Incremental native library builds (all platforms) |
| `tests.yml` | Push to main/dev/release, PRs | Build native libs (Linux) → run headless test suite |
| `release.yml` | Version tags (`v*`), manual | Full release: native libs → tests → desktop and web players → standalone editors → GitHub Release |

### Quick summary

- **Dev cycle:** push code → `tests.yml` compiles Linux extensions, runs 1,355 tests headless.
- **Release:** push a `v*` tag → `release.yml` builds native libraries, exports standalone editors and players for Windows x86_64, Windows ARM64, Linux x86_64, Linux ARM64, macOS, and a web player, and creates a GitHub Release. Each editor archive contains the player for that same OS. Android and iOS players are not in that release. `scripts/template_release.py stage` packs the zips the Build dialog downloads.
- **Native-only:** `build-extensions.yml` runs when only native C++ code changes, skips Player export.

### Release strategy

These workflows assume a **public** GitHub repository and the standard hosted runners (`ubuntu-22.04`, `windows-2022`, `macos-14`). Minutes on those runners are free, with no monthly cap. The workflows do not request larger runners. Those are billed even for a public repository.

The Free-plan limit this pipeline is written around is **Actions artifact storage: 500 MB**, averaged across the month. A file kept for one day counts as about one-thirtieth of its size. Files attached to a **GitHub Release** are a different store. That page is what people download, and it is what the editor fetches the first time it exports for another platform. Each Release file can be up to 2 GB.

Retention follows from that split:

| What is uploaded | Workflow | Kept | Why |
|---|---|---|---|
| CEF, Python runtimes, godot-cpp, and per-extension binaries produced during a release | `release.yml` | 1 day | Later jobs in the same run download them. CEF is about 550 MB and is uploaded once, from the Linux extension job. One day of that file is about 18 MB of the monthly average. |
| Player, editor, and source-archive zips | `release.yml` | 1 day | The last job attaches those same files to the GitHub Release. That copy is the one that lasts. The Windows and Linux packages contain CEF again, so leaving the artifact copy up for a week would use most of the 500 MB by itself. |
| Extension and `gn_ext_native` binaries | `build-extensions.yml` | 7 days | Long enough to download a pull-request build. A 90-day copy counted the full size for three months. |
| Test log | `tests.yml` | 30 days | A text file. The native binaries from that workflow expire after 1 day. |

Run `release.yml` about **once a month**, from a `v*` tag or the Run workflow button. Leave `tests.yml` on every push to `main`, `dev`, and `release/**`. Leave `build-extensions.yml` on native-code changes only. Another full release in the same month does not spend minutes, and it does add another set of CEF-sized zips to that month's storage average.

Android and iOS players are not part of this workflow. They are built by hand where the Android SDK or Xcode is available. The steps are in `addons/gonodes/help/building.md`.

### Native Library CI

A unified CI workflow automatically discovers all extensions with a
`native/build.cfg` and builds them for every platform they support.

#### Platforms & Runners

| Target | Runner | Compiler | Notes |
|--------|--------|----------|-------|
| Linux x86_64 | Ubuntu 22.04 | g++ | Standard build |
| Linux ARM64 | Ubuntu 22.04 | g++-aarch64-linux-gnu | Cross-compiled on x86_64 |
| macOS Universal | macOS M1 | clang | arm64 + x86_64 combined via `lipo` |
| Windows x86_64 | Windows | MSVC | Standard build |
| Windows ARM64 | Windows | MSVC ARM64 cross-tools | Cross-compiled |

#### GitHub Actions (`.github/workflows/build-extensions.yml`)

A single unified workflow with two stages:

1. **Discover** — runs `build/ci_discover.py` to scan for extensions with
   `native/build.cfg`, outputs a dynamic matrix
2. **Build** — 5 platform jobs per extension (auto-skips unsupported platforms)
   plus 5 dedicated jobs for `gn_ext_native` (uses its own SConstruct)

Each job clones godot-cpp (`--depth 1 --branch 4.5`) after checkout since
it is not tracked in git. Windows Spout builds also clone the Spout2 SDK.
Extension-specific SDKs (ONNX Runtime, CPython) are fetched by their
`setup_*.py` scripts via a "Setup vendor SDK" step.

Triggers on changes to `addons/gn_ext_*/native/**`, `build/**`, or the
workflow file, plus manual dispatch.

```bash
# What each job runs (unified build):
cd build
scons platform=<PLATFORM> arch=<ARCH> target=template_release -j4

# gn_ext_native jobs run from its own directory:
cd addons/gn_ext_native/native
scons platform=<PLATFORM> arch=<ARCH> target=template_release -j4
```

Adding a new extension with a `build.cfg` automatically appears in the next
CI run — no workflow edits. Artifact lifetimes are in [Release strategy](#release-strategy).

#### GitLab CI (`.gitlab-ci.yml`)

Two job groups:

1. **`build:native-*`** — 5 jobs for `gn_ext_native` (dedicated SConstruct)
2. **`build:ext-*`** — 5 jobs that build ALL `build.cfg` extensions at once
   via `cd build && scons`. Extensions that don't support the target platform
   are auto-skipped.

Triggers on changes to `addons/gn_ext_*/native/**`, `build/**`, or
`.gitlab-ci.yml`, plus manual trigger.

macOS jobs build both architectures and run `lipo` to create universal binaries.

### Full Build Workflow

The complete release build flow:

1. **CI builds all native libraries** for all 5 platform targets
2. **Download artifacts** and drop binaries into each extension's
   `native/bin/{win64,linux64,macos}/`
3. **Build Player templates** locally:
   ```bash
   ./scripts/build_templates.sh --godot /path/to/godot --platforms all --clean
   ```
4. The build script's GDExtension handling (`--gdext auto`) automatically
   includes the native binaries for each target platform
5. **Result:** Player binaries with native acceleration on all platforms


## CI / Automation (Player Exports)

The build scripts are designed for unattended use.  Exit code = number of
failed exports (0 = all succeeded).

### Automated Releases

The `release.yml` workflow is the recommended way to cut a release:

```bash
git tag v0.2.0-alpha
git push origin v0.2.0-alpha
```

This triggers the full pipeline: native extension builds (5 platforms) →
tests → Player exports (Windows, Linux, macOS) → Editor packaging →
GitHub Release with all artifacts attached. No local build needed.

Tags containing `alpha`, `beta`, `rc`, or `dev` are automatically marked
as pre-releases. The workflow can also be triggered manually from the
Actions tab with a custom version string.

### Local builds

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
| `scripts/build_templates.ps1`                 | PowerShell build script (all OSes). Players go to `templates/`. Editors go to `editor_dist/`. |
| `scripts/build_templates.sh`                  | Bash build script (Linux/macOS)      |
| `scripts/template_release.py`                 | Version stamp, GitHub release record, and editor/player zip layout |
| `export_presets.cfg`                          | Godot export preset definitions      |
| `templates/`                                  | Built Player binaries (.gitignored)  |
| `editor_dist/`                                | Built Editor binaries (.gitignored)  |
| `addons/gonodes/core/gn_patch_exporter.gd`   | Quick Build copy logic (runtime)     |
| **Unified native build system** | |
| `build/gn_build.py`                          | Shared build logic (platform detection, env setup, source collection) |
| `build/SConstruct`                           | Root entry point — auto-discovers and builds all extensions |
| `build/ci_discover.py`                        | CI helper — outputs GitHub Actions matrix JSON |
| `addons/gn_ext_*/native/build.cfg`           | Per-extension declarative build config |
| `addons/gn_ext_*/native/SConstruct`          | Per-extension thin shim (delegates to gn_build.py) |
| **gn_ext_native (special case)** | |
| `addons/gn_ext_native/native/SConstruct`     | godot-cpp SConstruct (builds godot-cpp + native operators) |
| `addons/gn_ext_native/native/gn_native.gdextension` | GDExtension manifest (all 5 platforms) |
| `addons/gn_ext_native/native/godot-cpp/`     | Cloned by `setup_deps.py` — godot-cpp bindings (gitignored) |
| **CI workflows** | |
| `.github/workflows/build-extensions.yml`      | GitHub Actions — unified native build (all extensions) |
| `.github/workflows/tests.yml`                 | GitHub Actions — build + run headless test suite |
| `.github/workflows/release.yml`               | GitHub Actions — full release pipeline (build → test → export → publish) |
| `.gitlab-ci.yml`                              | GitLab CI — unified native build (all extensions) |
| **Dependency setup** | |
| `setup_deps.py`                               | Root setup — clones godot-cpp; runs extension `setup` / `vendor_clone` from `build.cfg` |
| `build/gn_ext_setup.py`                       | Shared setup planner/runner (used by `setup_deps.py` and `run_extension_setups.py`) |
| `scripts/run_extension_setups.py`             | Targeted pre-build SDK fetch matching scons tier |
| `addons/gn_ext_ml/setup_ml.py`                | Downloads ONNX Runtime SDK + pre-trained models |
| `addons/gn_ext_opencv/setup_opencv.py`        | Downloads OpenCV SDK (Windows) |
| `addons/gn_ext_user_python/setup_python.py`   | Downloads embeddable CPython + NumPy |
| `scripts/build_windows.ps1`                   | All-in-one Windows build (`tier=all` default; `-Shipped` for subset) |
| **Post-build / release** | |
| `scripts/sync_gdextensions.py`                | Activate/deactivate `.gdextension` based on binary presence |
| `scripts/clean_builds.py`                     | Remove all binaries + deactivate extensions (pre-release clean) |
| `scripts/check_builds.py`                     | Verify native extension build outputs exist |
