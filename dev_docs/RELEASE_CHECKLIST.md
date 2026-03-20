# GONODES Release Checklist

Step-by-step guide for every release build. Do not skip steps — platform-specific extensions will silently fail at runtime if their binaries are missing.

---

## Phase 0: Version & Branch

- [ ] Confirm Godot version matches `project.godot` (`config/features` → currently **4.6.1**)
- [ ] Tag release branch (e.g., `release/v1.2.0`)
- [ ] Update version string in `project.godot` → `config/version`

---

## Phase 1: Ensure Dependencies Are Present

### Required on every build machine

| Dependency | How to verify | Install |
|------------|---------------|---------|
| **Godot 4.6.1 editor** | `godot --version` | Download from godotengine.org |
| **Godot 4.6.1 export templates** | Editor → Export → Manage Export Templates | Download in-editor or from godotengine.org |
| **Python 3.8+** | `python --version` | python.org |
| **SCons** | `scons --version` | `pip install scons` |
| **C++ compiler** (see per-platform below) | — | — |

### Per-platform compilers

| Platform | Compiler | Install |
|----------|----------|---------|
| Windows x86_64 | MSVC (VS 2022 Build Tools) | Visual Studio Installer → "C++ build tools" workload |
| Windows ARM64 | MSVC with ARM64 target | VS Installer → Individual Components → "MSVC ARM64 build tools" |
| Linux x86_64 | GCC 11+ | `sudo apt install build-essential` |
| Linux ARM64 | `aarch64-linux-gnu-g++` cross-compiler | `sudo apt install g++-aarch64-linux-gnu` |
| macOS | Xcode Command Line Tools | `xcode-select --install` |

### godot-cpp (shared by all native extensions)

The single godot-cpp copy lives at `addons/gn_ext_native/native/godot-cpp/`.

- [ ] Confirm it exists: `ls addons/gn_ext_native/native/godot-cpp/SConstruct`
- [ ] If missing, clone it:
  ```bash
  cd addons/gn_ext_native/native
  git clone --depth 1 --branch godot-4.2-stable https://github.com/godotengine/godot-cpp.git
  ```
- [ ] Build for each target platform (once per Godot version bump):
  ```bash
  cd addons/gn_ext_native/native/godot-cpp
  scons platform=windows arch=x86_64 target=template_release -j8
  scons platform=windows arch=arm64  target=template_release -j8
  scons platform=linux   arch=x86_64 target=template_release -j8
  scons platform=linux   arch=arm64  target=template_release -j8
  scons platform=macos   arch=arm64  target=template_release -j8
  scons platform=macos   arch=x86_64 target=template_release -j8
  ```

### Closed-source / vendored SDKs

These cannot be auto-fetched. Download manually and place in the correct paths.

| SDK | Required by | Location | Download from |
|-----|-------------|----------|---------------|
| **FFmpeg 6.0** | gn_ext_ffmpeg | `addons/gn_ext_ffmpeg/native/{win64,linux64,macos}/` | ffmpeg.org (shared libs + headers) |
| **NDI SDK** | gn_ext_ndi | `addons/gn_ext_ndi/native/ndi_sdk/` | ndi.video/sdk |
| **ONNX Runtime** | gn_ext_ml | `addons/gn_ext_ml/native/onnxruntime/lib/` | github.com/microsoft/onnxruntime/releases |
| **Blackmagic DeckLink SDK** | gn_ext_blackmagic | `addons/gn_ext_blackmagic/native/decklink_sdk/` | blackmagicdesign.com/developer |
| **Azure Kinect SDK** | gn_ext_depth_sensor (optional) | `addons/gn_ext_depth_sensor/native/azure_kinect_sdk/` | Microsoft docs |
| **Intel RealSense SDK** | gn_ext_depth_sensor (optional) | `addons/gn_ext_depth_sensor/native/realsense_sdk/` | github.com/IntelRealSense/librealsense |
| **Ultraleap SDK** | gn_ext_depth_sensor (optional) | `addons/gn_ext_depth_sensor/native/ultraleap_sdk/` | ultraleap.com/developers |

> **Tip:** Extensions with missing SDKs will simply not build. The export script handles this by removing unresolved `.gdextension` files before export.

---

## Phase 2: Build All Native Extensions

From the `build/` directory, build for each target. The root SConstruct auto-discovers all extensions with `native/build.cfg`.

```bash
cd build/

# ── Windows ──
scons platform=windows arch=x86_64 target=template_release -j8
scons platform=windows arch=arm64  target=template_release -j8

# ── Linux ──
scons platform=linux arch=x86_64 target=template_release -j8
scons platform=linux arch=arm64  target=template_release -j8

# ── macOS (universal = arm64 + x86_64) ──
scons platform=macos arch=arm64  target=template_release -j8
scons platform=macos arch=x86_64 target=template_release -j8
```

### Verify build outputs

- [ ] Check that each extension's `native/bin/` directory has the expected `.dll` / `.so` / `.dylib`:

| Extension | Windows x86_64 | Windows ARM64 | Linux x86_64 | Linux ARM64 | macOS |
|-----------|----------------|---------------|--------------|-------------|-------|
| gn_ext_native | `.dll` | `.dll` | `.so` | `.so` | `.dylib` |
| gn_ext_ffmpeg | `.dll` | — | `.so` | — | `.dylib` |
| gn_ext_hap | `.dll` | `.dll` | `.so` | `.so` | `.dylib` |
| gn_ext_midi | `.dll` | `.dll` | `.so` | `.so` | `.dylib` |
| gn_ext_video_capture | `.dll` | `.dll` | `.so` | `.so` | `.dylib` |
| gn_ext_gpu_encode | `.dll` | — | — | — | `.dylib` |
| gn_ext_spout | `.dll` | — | — | — | — |
| gn_ext_syphon | — | — | — | — | `.framework` |
| gn_ext_ndi | `.dll` | — | `.so` | — | `.dylib` |
| gn_ext_ml | `.dll` | — | `.so` | — | `.dylib` |
| gn_ext_blackmagic | `.dll` | — | `.so` | — | — |
| gn_ext_depth_sensor | `.dll` | — | `.so` | — | — |

### Extensions that need NO build (pure GDScript)

These just ship as-is — no compilation step:
- `gonodes` (core)
- `gn_ext_shadertoy`
- `gn_ext_isf`
- `gn_ext_mapper`
- `gn_ext_serial`
- `gn_ext_sdf`
- `gn_ext_user_native` (SDK headers + GDScript wrappers only — user compiles at runtime)

---

## Phase 3: Bundle godot-cpp for User C++ Nodes

The `gn_ext_user_native` extension lets users write custom C++ nodes **at runtime inside the editor**. For this to work without the user installing Godot or cloning repos, we ship pre-built godot-cpp.

**Why this matters:** Creative coders click "Edit C++" → write code → press Ctrl+B → it compiles and hot-reloads in 2–8 seconds. If godot-cpp headers/libs aren't present, that build fails. We must ship them.

- [ ] Copy `addons/gn_ext_native/native/godot-cpp/` into `addons/gn_ext_user_native/toolchain/godot-cpp/`
  - Include: headers (`include/`, `gen/include/`), pre-built static libs (`bin/`)
  - Exclude: `.git/`, `test/`, `doc/`, object files (`*.o`, `*.obj`)
- [ ] Verify the bundled godot-cpp was built from the **same branch** as the Godot editor version (e.g., `godot-4.2-stable` for Godot 4.6.x)
- [ ] Verify static libs exist for **all shipping platforms** (at minimum: Windows x86_64, Linux x86_64, macOS arm64)
- [ ] Verify `toolchain/README.md` matches the shipped layout
- [ ] Test: Drop a UserNativeSOP → Edit C++ → Ctrl+B → confirm it finds headers and compiles

> **Version coupling:** The bundled godot-cpp **must** match the Godot editor version. If the editor is 4.6.1 but toolchain godot-cpp is from 4.5, user-compiled nodes will crash on load due to ABI mismatch.

---

## Phase 4: Export Player Templates

The Player is a standalone runtime (no editor UI) for deployed installations.

### Windows / PowerShell
```powershell
.\scripts\build_templates.ps1 -Platforms all -GodotPath "C:\path\to\Godot_v4.6.1-stable_win64.exe"
```

### macOS / Linux
```bash
./scripts/build_templates.sh --platforms all --godot /path/to/godot
```

These scripts:
1. Swap `run/main_scene` → `player_main.tscn`
2. Remove `.gdextension` files for platforms with missing binaries
3. Run `--export-release` for each preset in `export_presets.cfg`
4. Restore everything after export

### Verify exports

- [ ] `templates/windows_x86_64/GONODESPlayer.exe` + `.pck`
- [ ] `templates/windows_arm64/GONODESPlayer.exe` + `.pck` (if building ARM64)
- [ ] `templates/linux_x86_64/GONODESPlayer` + `.pck`
- [ ] `templates/linux_arm64/GONODESPlayer` + `.pck` (if building ARM64)
- [ ] `templates/macos/GONODESPlayer.app/` (universal)
- [ ] FFmpeg runtime libs present alongside each player binary

---

## Phase 5: Validate

### Smoke tests

- [ ] Open project in Godot editor — **no red errors** in Output panel
- [ ] Create a test patch using at least one operator from each native extension
- [ ] Run the editor player (F5) — patch renders correctly
- [ ] Launch the standalone Player from `templates/` — loads and runs

### Extension loading check

- [ ] In the Godot console, confirm each GDExtension loads:
  ```
  GDExtension loaded: gn_native
  GDExtension loaded: libgdffmpeg
  GDExtension loaded: gn_hap_codec
  GDExtension loaded: gn_midi
  GDExtension loaded: gn_video_capture
  ...
  ```
- [ ] Verify operator count: Run `scripts/list_ops.py` and compare against previous release

### User C++ node test

- [ ] Drop a UserNativeSOP into a patch
- [ ] Write minimal C++ in the editor → Build (Ctrl+B) → confirm it compiles and cooks

---

## Phase 6: Package

### Editor distribution (for creators)

```
GONODES-v{VERSION}-{platform}/
├── GONODES.exe (or .app or binary)      ← Godot editor with GONODES project
├── project.godot
├── export_presets.cfg
├── addons/                               ← All extensions + native binaries
│   ├── gonodes/
│   ├── gn_ext_native/
│   ├── gn_ext_user_native/
│   │   └── toolchain/godot-cpp/          ← Pre-built for user C++ nodes
│   ├── gn_ext_ffmpeg/
│   │   └── native/bin/ + runtime DLLs
│   └── ... (all other extensions)
├── templates/                            ← Pre-built player binaries
├── scenes/
├── docs/
└── build/                                ← For users who want to rebuild
```

### Player-only distribution (for deployment)

```
GONODESPlayer-v{VERSION}-{platform}/
├── GONODESPlayer.exe (or binary)
├── GONODESPlayer.pck
├── libgdffmpeg.*.dll / .so              ← FFmpeg runtime
├── libgn_*.dll / .so                    ← Other native extension binaries
└── avcodec-60.dll / libavcodec.so.60    ← FFmpeg dependencies
```

---

## Phase 7: Post-Release

- [ ] Update `CHANGELOG.md`
- [ ] Push release tag
- [ ] Upload packages to distribution channel
- [ ] Verify download links work
- [ ] Announce release

---

## Quick Reference: What Changes Per Release Type

| Task | Godot version bump | Native code change | GDScript-only change | New extension added |
|------|--------------------|--------------------|----------------------|---------------------|
| Rebuild godot-cpp | **YES** | no | no | no |
| Rebuild all native extensions | **YES** | **YES** | no | **YES** |
| Re-export player templates | **YES** | **YES** | **YES** | **YES** |
| Update export_presets.cfg | **YES** | no | no | maybe |
| Re-bundle toolchain godot-cpp | **YES** | no | no | no |
| Re-download closed-source SDKs | check versions | no | no | if new SDK needed |
| Rebuild libgonodes + libgodot | **YES** | if bridge ops changed | no | no |
| Re-test Quick Build templates | **YES** | **YES** | if player logic changed | **YES** |

---

## Version Coupling Rules

GONODES has several components that **must stay version-locked**. A mismatch causes silent crashes at runtime.

| Component A | Component B | Must match? | What breaks |
|-------------|-------------|-------------|-------------|
| Godot editor | Export templates | **Exact version** | Export fails or Player crashes on launch |
| Godot editor | godot-cpp | **Same branch** (e.g., `godot-4.2-stable`) | GDExtension ABI mismatch → crash |
| godot-cpp (main build) | godot-cpp (user_native toolchain) | **Identical** | User C++ nodes crash when loaded |
| libgodot.dll | libgonodes.dll | **Same Godot version** | ABI mismatch → host app crash |
| Player .pck | Player binary | **Same export** | Missing resources or script errors |

**Rule of thumb:** When Godot version bumps, **everything** must be rebuilt from scratch — godot-cpp, all native extensions, player templates, libgodot, libgonodes, and the user_native toolchain bundle.

---

## In-Editor Quick Build (End-User Export)

The GONODES editor ships a **"Build" button** in the toolbar that lets creative coders export their patch as a standalone app for any platform — no command line, no Godot knowledge needed.

### How it works

```
User clicks "Build" → GNExportDialog → GNPatchExporter.quick_build()
```

**Files involved:**

| File | Role |
|------|------|
| `scenes/gn_editor.gd` → `_on_build_pressed()` | Triggers the export dialog |
| `addons/gonodes/ui/gn_export_dialog.gd` | Platform/renderer picker, compatibility scanner |
| `addons/gonodes/core/gn_patch_exporter.gd` | Copies Player template + .gnpatch + assets → output folder |
| `scenes/player_main.gd` | Standalone runtime that reads config.json and runs the patch |

### What Quick Build does

1. Scans the patch for **compatibility warnings** against the target platform + renderer:
   - GPU-only nodes without CPU fallback → red warning
   - Platform-specific nodes (Spout on macOS, Syphon on Windows) → red warning
   - Compute shader nodes on Compatibility renderer → yellow warning
   - Multi-window patches on mobile/web → yellow warning
2. Copies the pre-built Player binary from `templates/<platform>/`
3. Copies the `.gnpatch` file and its asset folder
4. Generates `config.json` with patch path + renderer choice
5. Output: self-contained folder the user can zip and share

### Supported targets

| Platform | Architecture | Renderer options | Notes |
|----------|-------------|------------------|-------|
| Windows | x86_64, ARM64 | Forward+, Mobile, Compatibility | Primary target |
| Linux | x86_64, ARM64 | Forward+, Mobile, Compatibility | |
| macOS | Universal (arm64 + x86_64) | Forward+, Mobile, Compatibility | |
| Android | ARM64 | Mobile, Compatibility | Touch input, single window |
| iOS | ARM64 | Mobile, Compatibility | Touch input, single window |
| Web | wasm32 | Compatibility only | WebGL2, no compute shaders |

### Release responsibility

For Quick Build to work, the `templates/` folder must contain **pre-built Player binaries** for every platform you want users to target. These are built in Phase 4 above. If a template is missing, the export dialog shows a helpful error.

**Important:** Native extension binaries (FFmpeg DLLs, NDI libs, etc.) are baked into the Player `.pck` during template export. If you add a new native extension, you **must re-export all templates** or the new extension won't be available in Quick Build output.

---

## libgonodes (Separate Product)

`libgonodes/` is the C shared library for embedding GONODES in third-party apps (media servers, VJ tools, game engines). It has its own build and release cycle.

### Version coupling

libgonodes dynamically loads `libgodot.dll/.so/.dylib` at runtime. The two **must** be built from the same Godot version. There is no version check — a mismatch causes a silent crash.

```
Host App → libgonodes.dll → loads libgodot.dll (same Godot version)
                                     ↓
                            Godot engine (headless)
                                     ↓
                            GNEmbeddedHost → loads .gnpatch
```

### When to rebuild

| Trigger | Rebuild libgodot? | Rebuild libgonodes? |
|---------|-------------------|---------------------|
| Godot version bump (4.6 → 4.7) | **YES** | **YES** |
| GONODES GDScript changes (cook engine, operators) | no (re-export .pck) | no |
| Bridge operator changes (HostInTOP, HostOutCHOP, etc.) | no | no (GDScript, in .pck) |
| New C API function added to libgonodes | no | **YES** |
| New .gnpatch deployed by end user | no | no |

### Build steps

1. **Build LibGodot** (Godot as a C shared library):
   ```bash
   # In Godot source tree:
   scons platform=windows target=template_release libgodot=yes -j8
   ```
   This produces `libgodot.windows.template_release.x86_64.dll`.

2. **Build libgonodes** against it:
   ```bash
   cd libgonodes
   mkdir build && cd build
   cmake .. -DGONODES_BUILD_EXAMPLES=ON
   cmake --build . --config Release
   ```

3. **Ship together:** `libgonodes.dll` + `libgodot.dll` + GONODES `.pck` in the same directory.

Only include in release if shipping the embedding SDK.
