# GONODES Release Checklist

> **Audience:** Repo moderators cutting a release.  
> **For build instructions:** See [BUILD.md](BUILD.md) — the single source of truth for building from a fresh clone.

This checklist is a verification and packaging guide, not a build tutorial. Each phase references BUILD.md sections for the actual commands.

---

## Phase 0: Version & Branch

- [ ] Confirm Godot version matches `versions.env` → `GODOT_VERSION` (currently **4.6.1**)
- [ ] Confirm godot-cpp branch matches `versions.env` → `GODOTCPP_BRANCH` (currently **4.5**)
- [ ] Run `python scripts/check_versions.py` — CI workflows match `versions.env`
- [ ] Update version string in `project.godot` → `config/version`
- [ ] Tag release branch (e.g., `release/v1.2.0`)

---

## Phase 1: Build Everything

Follow [BUILD.md](BUILD.md) for detailed commands. This phase ensures all binaries are compiled from clean source.

### Environment check

- [ ] Run `python scripts/check_env.py --strict` — all PASS

### Dependencies

- [ ] `python setup_deps.py --core` — godot-cpp cloned and ready
- [ ] `python setup_deps.py` (without `--core`) — runs all extension `setup_*.py` scripts automatically
- [ ] Closed-source SDKs placed in correct paths (see BUILD.md § "Wrapping External Libraries" and the SDK table below)

<details>
<summary>SDK location reference (update when adding new SDK-dependent extensions)</summary>

| SDK | Required by | Location |
|-----|-------------|----------|
| FFmpeg 6.0 | gn_ext_ffmpeg | `addons/gn_ext_ffmpeg/native/{win64,linux64,macos}/` |
| NDI SDK | gn_ext_ndi | `addons/gn_ext_ndi/native/ndi_sdk/` |
| ONNX Runtime | gn_ext_ml | `addons/gn_ext_ml/native/onnxruntime/lib/` (auto-fetched by `setup_ml.py`) |
| DeckLink SDK | gn_ext_blackmagic | `addons/gn_ext_blackmagic/native/decklink_sdk/` |
| Azure Kinect SDK | gn_ext_depth_sensor | `addons/gn_ext_depth_sensor/native/azure_kinect_sdk/` |
| RealSense SDK | gn_ext_depth_sensor | `addons/gn_ext_depth_sensor/native/realsense_sdk/` |
| Ultraleap SDK | gn_ext_depth_sensor | `addons/gn_ext_depth_sensor/native/ultraleap_sdk/` |

</details>

### Native extension builds

See BUILD.md § "Unified Build System" and § "Native Library Builds".

- [ ] Build godot-cpp for each target platform
- [ ] Build all extensions: `cd build && scons platform=<PLATFORM> -j8`
- [ ] Run `python scripts/check_builds.py --all` — all extensions have binaries
- [ ] Run `python scripts/sync_gdextensions.py` — all `.gdextension` files activated

### Bundle toolchains

- [ ] `python scripts/bundle_toolchain.py --all` then `--verify` (user C++ nodes)
- [ ] `python addons/gn_ext_user_python/setup_python.py` then `--verify` (user Python nodes)

### Export Player templates

See BUILD.md § "Quick Start" and § "Output Structure".

- [ ] Godot export templates installed (Editor → Manage Export Templates)
- [ ] Set `GONODES_GODOT` env var to Godot editor path
- [ ] Windows: `.\scripts\build_templates.ps1 -Platforms all`
- [ ] Linux/macOS: `./scripts/build_templates.sh --platforms all`
- [ ] Verify outputs exist: `templates/windows_x86_64/`, `templates/linux_x86_64/`, `templates/macos/`, etc.

---

## Phase 2: Validate

### Smoke tests

- [ ] Open project in Godot editor — **no red errors** in Output panel
- [ ] Create a test patch using at least one operator from each native extension
- [ ] Run the editor player (F5) — patch renders correctly
- [ ] Launch the standalone Player from `templates/` — loads and runs

### Extension loading check

- [ ] In the Godot console, confirm **every** GDExtension with compiled binaries loads without error. Run `python scripts/check_builds.py --all` to get the full list of expected extensions — each should print a `GDExtension loaded:` message.
- [ ] Verify operator count: Run `scripts/list_ops.py` and compare against previous release

### User C++ node test

- [ ] Drop a **NativeSCRIPT** into a patch
- [ ] Write minimal C++ in the editor → Build (Ctrl+B) → confirm it compiles and cooks

### User Python node test

- [ ] Drop a **PythonSCRIPT** into a patch
- [ ] Write minimal Python in the editor → Reload (Ctrl+R) → confirm it loads and cooks
- [ ] Verify NumPy import works: `import numpy as np` in the script

### Automated test suite

- [ ] Run: `godot --headless -s tests/test_runner.gd` — **ALL PASSED**, zero failures
- [ ] Run patch smoke: `godot --headless -s tests/test_runner.gd --test-tag=patch` — all help patches parse

### Manual QA — visual & workflow verification

The automated suite covers CPU-side logic. This section catches GPU rendering issues,
editor UX problems, and visual correctness that headless tests cannot verify.

**Estimated time: 3–4 hours total.**

#### ALL_CORE comprehensive test patches

Before starting manual QA, regenerate the ALL_CORE patches to ensure they cover
all currently registered operators:

```bash
python scripts/gen_all_core_patches.py
```

This creates 13 `.gnpatch` files covering **all 574 operators** across every family,
organized into logical chains with a SwitchTOP → WindowOUT for visual inspection.
Use the chain slider to step through each operator group.

| Patch | Location | Operators |
|-------|----------|-----------|
| ALL_CORE_CHOPs | `tests/manual/chop/` | 85 CHOPs in 22 chains |
| ALL_CORE_SOPs | `tests/manual/sop/` | 76 SOPs in 22 chains |
| ALL_CORE_TOPs | `tests/manual/top/` | 143 TOPs in 20 chains |
| ALL_CORE_COMPs | `tests/manual/comp/` | 26 COMPs in 5 chains |
| ALL_CORE_DATs | `tests/manual/dat/` | 48 DATs in 13 chains |
| ALL_CORE_IMGs | `tests/manual/img/` | 34 IMGs in 9 chains |
| ALL_CORE_MATs | `tests/manual/mat/` | 12 MATs in 12 chains |
| ALL_CORE_UIs | `tests/manual/ui/` | 33 UIs in 7 chains |
| ALL_CORE_POPs | `tests/manual/pop/` | 14 POPs in 5 chains |
| ALL_CORE_VOLs | `tests/manual/vol/` | 15 VOLs in 6 chains |
| ALL_CORE_OUTs | `tests/manual/output/` | 17 OUTs in 6 chains |
| ALL_CORE_SDFs | `addons/gn_ext_sdf/tests/manual/` | 29 SDFs in 7 chains |
| ALL_CORE_SCRIPTs | `tests/manual/script/` | 3 SCRIPTs in 1 chain |

- [ ] Open each ALL_CORE patch → step through all chains → no red errors, no crashes
- [ ] Visual output for GPU families (TOP, COMP, MAT, POP, VOL, SDF) looks reasonable

#### Phase A: Editor smoke (30 min)

- [ ] Open editor — graph canvas renders, no visual glitches
- [ ] Alt+A palette opens, type-filter works, family tabs work
- [ ] Add one node from each family — all appear in graph with correct color
- [ ] Wire two nodes — connection draws, data flows, viewer updates
- [ ] Inspector panel shows parameters for selected node
- [ ] Ctrl+S / Ctrl+O — save and reload patch, verify identical
- [ ] Ctrl+Z / Ctrl+Y — undo/redo works for add, delete, wire, param change
- [ ] Ctrl+C / Ctrl+V — copy/paste nodes preserves params and wiring
- [ ] F2 debug overlay — cook chain, active chains, graph overlay all display
- [ ] Viewer modes — texture preview, channel graph, table view, 3D viewport

#### Phase B: Help patch walkthrough (2 hours)

Open the `?` help for 5–10 operators per family. Verify each patch loads,
nodes cook without errors, and visual output looks correct.

**Priority: visual families first, data families last.**

| Family | Sample operators to check | What to verify |
|--------|--------------------------|----------------|
| **TOP** | NoiseTOP, CompositeTOP, BlurTOP, FeedbackTOP, RenderTOP, CustomShaderTOP, DeformTOP, ChromaKeyTOP | Textures render, animated params move, shader compilation |
| **COMP** | GeometryCOMP, CameraCOMP, LightCOMP, RigidBodyCOMP, InstanceCOMP, SubNetworkNode | 3D scene assembles, physics simulates, subnets dive/exit |
| **POP** | SourcePOP, ForcePOP, TurbulencePOP, CollisionPOP, RenderPOP | Particles spawn, move, collide, render to texture |
| **VOL** | NoiseVOL, FluidVOL, MarchingCubesVOL, RaymarchVOL | Volumes generate, fluid simulates, surface extracts |
| **MAT** | PbrMAT, ShaderMAT, WireframeMAT, ConstantMAT | Materials apply to geometry, shader compiles |
| **IMG** | NoiseIMG, BlurIMG, EdgeDetectIMG, PixelSortIMG | CPU images generate and display correctly |
| **UI** | SliderUI, ButtonUI, KnobUI, XYPadUI, ColorPickerUI | Widgets render in PanelTOP, interaction works |
| **SOP** | GridSOP, BooleanSOP, NoiseSOP, ExtrudeSOP, VoronoiShatterSOP | Geometry generates, deforms, topology correct |
| **CHOP** | LFOCHOP, KeyframeCHOP, MathCHOP, AudioSpectrumCHOP, MidiInCHOP | Channels animate, math applies, I/O receives |
| **DAT** | ConstantDAT, WebDAT, JsonDAT, EvaluateDAT, ScriptDAT | Tables populate, data transforms, scripts execute |
| **OUT** | WindowOUT, RenderTOP→WindowOUT pipeline | Window opens on display, resize works |

#### Phase C: End-to-end pipelines (30 min)

- [ ] **3D rendering pipeline:** `GridSOP → TransformSOP → GeometryCOMP + PbrMAT + CameraCOMP + LightCOMP → MergeCOMP → RenderTOP → WindowOUT` — renders lit geometry
- [ ] **Audio-reactive visuals:** `AudioSpectrumCHOP → MathCHOP → expression on NoiseTOP scale → CompositeTOP → WindowOUT` — visuals react to audio
- [ ] **Particle system:** `SourcePOP → ForcePOP → TurbulencePOP → RenderPOP → NullTOP` — particles flow
- [ ] **Data pipeline:** `WebDAT → JsonDAT → SelectDAT → EvaluateDAT → NullDAT` — data flows through
- [ ] **Sub-network:** Create BaseCOMP, dive in, add InTunnel + OutTunnel + internal nodes, exit, wire external ports — data passes through
- [ ] **Expressions:** Wire `LFOCHOP`, reference it via `chop("lfo1", "out")` in a TOP param — value updates per frame
- [ ] **Save/load round-trip:** Build a 10+ node patch with expressions, subnets, and annotations → save → close → reopen → verify identical layout, params, and cooking

#### Phase D: Export & Player (30 min)

- [ ] Quick Build to Windows — produces working standalone
- [ ] Launch exported player — patch loads from config.json, renders correctly
- [ ] Player hotkeys: Escape (quit), F1 (debug overlay), F11 (fullscreen)
- [ ] If macOS available: Quick Build to macOS — verify .app runs
- [ ] If Linux available: Quick Build to Linux — verify binary runs

#### Phase E: Extension hardware I/O (if hardware available)

- [ ] **MIDI:** Connect controller → MidiInCHOP receives notes/CC
- [ ] **Webcam:** VideoCaptureTOP shows live camera feed
- [ ] **Spout/Syphon:** Send/receive texture with another app (Resolume, OBS)
- [ ] **Serial:** Arduino connected → SerialReceiveDAT (gn_ext_serial) receives data
- [ ] **NDI:** Send/receive over network
- [ ] **Audio:** AudioInCHOP captures microphone, AudioDeviceOUT plays to speakers

> **Note:** Phase E is hardware-dependent — skip items where hardware is unavailable.
> If all of Phases A–D pass, the release is safe to ship.

---

## Phase 3: Clean for Release

The repository must be in **source-only state** before tagging. All compiled binaries and bundled toolchains are build artifacts — they get rebuilt by users or CI after cloning.

```bash
python scripts/clean_builds.py              # remove binaries + deactivate extensions
python scripts/clean_builds.py --dry-run    # preview first
```

This script:
1. Removes all `native/bin/` directories (compiled DLLs/SOs)
2. Renames `.gdextension` → `.gdextension.disabled` for all native extensions
3. Cleans bundled toolchains (`toolchain/godot-cpp/`, `toolchain/python/`)

- [ ] Run `python scripts/clean_builds.py` — all binaries removed
- [ ] Verify `python scripts/sync_gdextensions.py --dry-run` reports all in sync (everything disabled)
- [ ] Verify `git status` shows only expected changes (no stale binary references)
- [ ] `templates/` directory removed or empty (Player exports are also build artifacts)

> **After a fresh clone,** users run the build steps in [BUILD.md](BUILD.md).
> `sync_gdextensions.py` (or the SConstruct post-build hook) automatically
> re-activates `.gdextension` files when their binaries are compiled.

---

## Phase 4: Package

### File association icons

- [ ] Create `.gnpatch` file icon artwork (node graph motif)
  - `gnpatch.ico` — Windows (256×256, 48×48, 32×32, 16×16 multi-res)
  - `gnpatch.icns` — macOS (1024×1024 down to 16×16)
  - `gnpatch.png` — Linux (128×128 minimum)
- [ ] Place icons in `scripts/installers/` and inside app bundles
- [ ] Run per-platform registration scripts (see `scripts/installers/`)

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
│   │   └── toolchain/godot-cpp/          ← Pre-built for user C++ nodes│   ├─ gn_ext_user_python/
│   │   ├── sdk/gonodes/                  ← Python SDK package
│   │   └── toolchain/python/             ← Bundled Python (optional)│   ├── gn_ext_ffmpeg/
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

## Phase 5: Post-Release

- [ ] Update `CHANGELOG.md`
- [ ] Push release tag → triggers `.github/workflows/release.yml`
  - Builds all native extensions (5 platforms)
  - Runs headless test suite
  - Exports Player templates (Windows, Linux, macOS)
  - Packages Editor distributions
  - Creates GitHub Release with all artifacts attached
- [ ] Verify GitHub Release page: all downloads present, correct sizes
- [ ] Announce release

---

## Release Stage: Beta (not Alpha) Rationale

The initial public release of GONODES is **Beta**, not Alpha. This is a deliberate classification based on the following criteria:

### Why not Alpha

Alpha implies incomplete core functionality, frequent crashes, and missing fundamental features. GONODES has none of these issues:

- **574 operators** across 14 families — complete creative toolkit covering textures, geometry, channels, particles, volumes, compositing, materials, data tables, ISF shaders, SDF, and network I/O
- **1764 automated tests**, 1763 passing (99.94%) — the single failure is a smoke test for extension patches that require compiled native binaries, not a code defect
- **100% operator test coverage** — every operator has at least instantiation + output type verification
- **100% help file coverage** — 1,588 help .gnpatch files covering all 574 unique node types
- **Cook engine is stable** — expression system, dirty propagation, timeline, and multi-family data flow all verified
- **GPU zero-copy discipline** — audit confirmed zero unjustified CPU-GPU roundtrips across the entire codebase
- **Cross-platform build system** — SCons-based native builds, player export templates, and CI pipeline all functional on Windows, macOS, and Linux
- **Embedding API (libgonodes)** — complete C API with 60+ functions, zero-copy GPU exchange, and comprehensive test suite

### Why Beta (not Stable)

Beta indicates the software is feature-complete and functional but needs real-world usage to surface edge cases:

- **No production deployments yet** — internal testing is thorough but cannot replicate the diversity of real-world creative workflows
- **Native extensions require compiled binaries** — some extensions (FFmpeg, NDI, Blackmagic, etc.) depend on third-party SDKs that haven't been validated across all target platforms
- **libgonodes embedding** — the C API is fully implemented but has not been stress-tested in production host applications
- **GPU context sharing** — zero-copy paths exist but require matching GPU drivers and shared device setup that varies across hardware
- **Custom operator asset format (.gnasset)** — functional but serialization format may evolve based on user feedback before being locked for 1.0
- **Timeline system** — complete but performance under complex multi-track compositions needs real-world validation

### Graduation criteria (Beta → Stable 1.0)

- [ ] At least 3 independent production deployments running without critical issues
- [ ] Native extension binaries verified on all 5 target platforms (Win x64, Win ARM64, Linux x64, Linux ARM64, macOS Universal)
- [ ] libgonodes embedding validated in at least 2 different host frameworks (e.g., Unity, Unreal, custom C++ app)
- [ ] .gnasset and .gnpatch formats finalized and versioned — backward compatibility guaranteed
- [ ] Public documentation and tutorials available

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
| Godot editor | godot-cpp | **Same branch** (e.g., `godot-4.6-stable`) | GDExtension ABI mismatch → crash |
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

## libgonodes (Separate Release Cycle)

`libgonodes/` is the C shared library for embedding GONODES in third-party apps (media servers, VJ tools, game engines). It lives in the same repository but has its **own version and release cycle**.

### Why separate?

| Aspect | GONODES (editor + player) | libgonodes (embedding SDK) |
|--------|--------------------------|---------------------------|
| Version | `project.godot` → `config/version` | `versions.env` → `LIBGONODES_VERSION` (currently **2.5.0**) |
| Build system | SCons (native) + Godot export (player) | CMake |
| Release tag | `v1.2.0` | `libgonodes-v2.5.0` |
| Audience | Creative coders, VJs, artists | SDK integrators, engine developers |
| Release frequency | Every feature/bugfix cycle | Only on C API changes or Godot version bumps |

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

### Release steps (when shipping the embedding SDK)

1. Update `LIBGONODES_VERSION` in `versions.env`
2. **Build LibGodot** (Godot as a C shared library):
   ```bash
   # In Godot source tree:
   scons platform=windows target=template_release libgodot=yes -j8
   ```
   This produces `libgodot.windows.template_release.x86_64.dll`.

3. **Build libgonodes** against it:
   ```bash
   cd libgonodes
   mkdir build && cd build
   cmake .. -DGONODES_BUILD_EXAMPLES=ON
   cmake --build . --config Release
   ```

4. **Ship together:** `libgonodes.dll` + `libgodot.dll` + GONODES `.pck` in the same directory.
5. Tag: `git tag libgonodes-v2.5.0 && git push origin libgonodes-v2.5.0`

### Coordinated releases

When a GONODES release also bumps the Godot version, libgonodes **must** be rebuilt and re-released too. The GONODES release checklist (Phase 1) should note this.

When only the C API changes (no Godot bump), libgonodes can be released independently — no GONODES release needed.
