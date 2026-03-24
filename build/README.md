# GONODES Unified Native Build System

Build all C++ GDExtension addons from a single entry point. Extensions
declare their configuration in `build.cfg` files; the shared `gn_build.py`
module handles everything else.

## Quick Start

```bash
cd build

# Build everything for the current platform:
scons -j4

# Build everything for a specific platform:
scons platform=windows arch=x86_64 -j4
scons platform=linux   arch=arm64  -j4
scons platform=macos   arch=arm64  -j4

# Build a single extension:
scons ext=gn_ext_hap   platform=windows -j4
scons ext=gn_ext_midi  platform=linux   -j4

# Build gn_ext_native (delegates to its own godot-cpp SConstruct):
scons ext=gn_ext_native platform=windows -j4

# List all discovered extensions:
scons --list-extensions
```

You can also build from each extension's own directory (same results):

```bash
cd addons/gn_ext_hap/native
scons platform=windows arch=x86_64 -j4
```

## Build Flags

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `platform` | `windows`, `linux`, `macos` | Host OS | Target operating system |
| `arch` | `x86_64`, `arm64` | Host CPU | Target architecture |
| `target` | `template_release`, `template_debug` | `template_release` | Release = optimized. Debug = symbols |
| `ext` | `gn_ext_<name>` | *(all)* | Build only this extension |
| `-j N` | integer | 1 | Parallel jobs |

## Discovered Extensions

| Extension | Platforms | Library | Notes |
|-----------|-----------|---------|-------|
| `gn_ext_native` | All | `gn_native` | Special: uses godot-cpp SConstruct |
| `gn_ext_hap` | All | `gn_hap_codec` | HAP video codec |
| `gn_ext_spout` | Windows | `gn_spout` | Spout2 texture sharing |
| `gn_ext_syphon` | macOS | `gn_syphon` | Syphon texture sharing |
| `gn_ext_video_capture` | All | `gn_video_capture` | Webcam/capture devices |
| `gn_ext_gpu_encode` | Windows, macOS | `gn_gpu_encode` | Hardware H.264 encoding |
| `gn_ext_midi` | All | `gn_midi` | MIDI I/O via RtMidi |
| `gn_ext_ndi` | All | `gn_ndi` | NDI video/audio I/O |
| `gn_ext_ml` | All | `gn_ml` | ONNX Runtime ML inference |
| `gn_ext_depth_sensor` | All | `gn_depth_sensor` | Azure Kinect + RealSense + Ultraleap |
| `gn_ext_blackmagic` | Windows, macOS | `gn_blackmagic` | Blackmagic capture card I/O |
| `gn_ext_serial` | All | — | Serial port I/O (depends on gn_native) |
| `gn_ext_user_native` | All | `gn_user_native` | User C++ operator hot-reload |
| `gn_ext_user_python` | All | `gn_user_python` | User Python operator hot-reload |

Extensions that don't support the target platform are auto-skipped.

## Cross-Compilation

```bash
# Linux ARM64 from x86_64 host:
sudo apt-get install g++-aarch64-linux-gnu
scons platform=linux arch=arm64 -j4

# Windows ARM64 (MSVC cross-tools):
scons platform=windows arch=arm64 -j4

# macOS universal binary (build both, then lipo):
scons platform=macos arch=arm64 -j4
scons platform=macos arch=x86_64 -j4
```

## Adding a New Extension

Any folder in `addons/` matching `gn_ext_*` that contains `native/build.cfg`
is automatically discovered by the build system and CI pipelines. No other
files need editing.  Extensions without a `native/build.cfg` (pure GDScript,
prebuilt binaries) are silently skipped.

### Required layout

```
addons/gn_ext_<name>/
├── gn_extension.cfg          # GDScript extension manifest (operators, etc.)
├── native/
│   ├── build.cfg             # ← Declares name, platforms, sources, libs
│   ├── SConstruct            # ← Optional: 6-line shim for standalone builds
│   └── src/
│       ├── register_types.h
│       ├── register_types.cpp
│       └── my_node.cpp
└── operators/                # GDScript operator wrappers (if any)
```

### build.cfg reference

```ini
[library]
name = gn_my_extension            # Output library name (libgn_my_extension.dll/.so/.dylib)
entry_symbol = gn_my_extension_init  # GDExtension init function name
platforms = windows, macos, linux  # Omit platforms you don't support

[sources]
cpp = src/*.cpp                    # Glob patterns relative to native/
c = src/*.c                        # Optional: C sources
objcxx = src/*.mm                  # Optional: Obj-C++ (macOS only)
thirdparty_cpp = vendor/*.cpp      # Optional: bundled third-party C++
thirdparty_c = vendor/*.c          # Optional: bundled third-party C
thirdparty_cc = vendor/*.cc        # Optional: bundled third-party .cc
include_dirs = vendor, src/util    # Optional: extra -I paths (relative to native/)

[windows]
libs = mfplat, mf, ole32          # Optional: system libraries to link
defines = MY_WIN_DEFINE            # Optional: preprocessor defines

[macos]
frameworks = CoreMedia, AVFoundation  # Optional: macOS frameworks
objcxx_sources = src/mac/*.mm        # Optional: platform-specific Obj-C++
defines = MY_MAC_DEFINE

[linux]
libs = alsa                        # Optional: system libraries
defines = MY_LINUX_DEFINE
```

**Conventions:**
- All paths in `build.cfg` are **relative to `native/`**.
- Third-party source code lives inside `native/` (e.g., `native/vendor/`).
- Prebuilt external `.lib`/`.a`/`.dll` files are NOT handled by `build.cfg` —
  put them in `native/lib/<platform>/` and add link flags manually if needed.
- godot-cpp includes are set up automatically from the shared checkout at
  `addons/gn_ext_native/native/godot-cpp/`.

### SConstruct shim (optional, for standalone builds)

```python
# gn_ext_<name> — Thin shim delegating to the shared GONODES build system.
import os, sys
sys.path.insert(0, os.path.normpath(os.path.join(Dir("#").abspath, "..", "..", "..", "build")))
from gn_build import build_extension
build_extension(native_dir=Dir("#").abspath)
```

### Build and verify

```bash
# From the unified build:
cd build && scons ext=gn_ext_<name> -j4

# Or standalone:
cd addons/gn_ext_<name>/native && scons platform=windows -j4

# Verify it was discovered:
cd build && scons --list-extensions
```

CI pipelines auto-discover it on next push.

## Files

| File | Purpose |
|------|---------|
| `gn_build.py` | Shared Python module: config parsing, env setup, source collection |
| `SConstruct` | Root SCons entry: discovers extensions, orchestrates builds |
| `ci_discover.py` | Outputs GitHub Actions matrix JSON for dynamic CI jobs |

See [dev_docs/BUILD.md](../dev_docs/BUILD.md) for the complete build
system reference including Player templates, export presets, and CI details.
