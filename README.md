# GONODES

**Real-time node-based visual programming, built on [Godot 4.7](https://godotengine.org). Inspired by [TouchDesigner](https://derivative.ca) and [Houdini](https://www.sidefx.com).**

Wire operators together, tweak parameters live, see results instantly — then export your patch as a standalone app on any platform Godot supports.

---

## Why GONODES?

If you've used TouchDesigner, Houdini, Max/MSP, vvvv, or VUO, you know the workflow: connect nodes, data flows through wires, results appear in real time. GONODES brings that to Godot — with some unique advantages:

- **Ship anywhere.** Export patches as standalone apps on Windows, macOS, Linux, Android, iOS, and Web — no runtime license fees.
- **GPU-powered.** Vulkan, Metal, D3D12, and OpenGL rendering. Compute shaders for GPU particles and volumetrics.
- **Embeddable.** With LibGodot (Godot 4.6+), GONODES patches can run inside VJ tools like VDMX or Resolume.
- **Open source.** No black boxes. Read every line, extend anything.

---

## Features at a Glance

**585 operators** across **15 families**, plus **131 native C++ accelerated variants** and **25 extension folders** (`addons/gn_ext_*/`; 23 distributable packs in the table below, plus `gn_ext_native` acceleration and internal `gn_ext_host_bridge` for LibGodot).
Parallel level-based cook engine, named output ports, dot routing nodes, and keyframe animation.

### Operator Families

| Family | Count | What It Processes | Examples |
|--------|-------|-------------------|----------|
| **TOP** | 138 | GPU texture processing | Noise, Composite, Blur, ChromaKey, Feedback, Render, GLSL, ISF, Shadertoy, Deform |
| **CHOP** | 107 | Signals, channels & audio | LFO, Audio synthesis, DMX, MIDI, OSC, Gamepad, Keyboard, Skeleton, State machine |
| **SOP** | 85 | 3D geometry | Grid, Boolean, Extrude, Subdivide, Remesh, ClothSim, L-System, PolyBevel, HeightField |
| **DAT** | 51 | Tables, text & data | JSON, WebSocket, MQTT, HTTP, ArtNet, Serial, OSC, QR, RenderPick, PanelExecute |
| **IMG** | 41 | CPU image processing | OpenCV detection, EdgeDetect, OpticalFlow, PixelSort, Webcam, ArUco, ML inference |
| **UI** | 33 | Interactive 2D widgets | Button, Slider, Knob, XYPad, ColorPicker, Tree, TabContainer, Container |
| **SDF** | 29 | Signed distance fields | Box, Sphere, Torus, Union/Intersection/Subtract, Bend, Twist, Raymarch |
| **COMP** | 27 | 3D scene composition | Geometry, Camera, Light, RigidBody, SoftBody, Animation, NavMesh, Vehicle |
| **NET** | 15 | Subnets & host bridge | SubNetwork, InTunnel, OutTunnel, HostIn/Out for LibGodot embedding |
| **MAT** | 12 | Materials & shaders | PBR, Custom GLSL, Wireframe, PointSprite, FluidSurface, NormalMap |
| **POP** | 12 | GPU particles | Source, Force, Turbulence, Boids, Collision, Advect (VOL), Ribbon trail |
| **VOL** | 12 | Volumetric 3D textures | Noise, Fluid sim (Navier-Stokes), Pyro, Marching Cubes, Raymarch |
| **OUT** | 12 | Output & export | WindowOUT, SinkOUT, MovieOUT, FFmpegOUT, AudioDeviceOUT, OscOUT, PixelDmxOUT |
| **FIX** | 8 | LED fixture mapping | Strip, Grid, Matrix, Custom — define LED UV positions for GPU sampling and DMX routing |
| **SCRIPT** | 3 | User scripting | GDScript, Python (NumPy), C++ — template-based, multi-family output |

> **GPU/CPU boundary rule:** Operators requiring GPU->CPU readback (histogram, blob detection, pixel sorting) always live in the IMG family, never TOP. The performance cost is visible in your graph. Cross the boundary explicitly with `TOPtoIMG` / `ImgToTOP`.

### Live Expression System

Any parameter can be driven by a live expression evaluated every frame:

```gdscript
chop("lfo1", "out") * 10.0        # Modulate a value with an LFO
op("noise1", "scale")              # Read another node's parameter
sin(time * 2.0) + 0.5             # Math with built-in time variable
par("subnet1/inner", "threshold")  # Hierarchical path references
set_par("target", "brightness", v) # Write to other nodes from scripts
```

Autocomplete suggests node IDs filtered by the function's expected family and supports hierarchical subnetwork paths. Rename a node and every expression referencing it updates automatically.

**Extensible** — extensions can register new top-level expression functions for custom data families (e.g. `sdf("node", "key")`) via config, or add utility functions callable as `fn("name", args)` via the `GNExpressionFunctions` API. Autocomplete adapts automatically.

### 3D Scene Pipeline

Full 3D rendering integrated into the texture pipeline:

```
GridSOP → TransformSOP → GeometryCOMP ─┐
                ↑            ↑          │
           PbrMAT       CameraCOMP   ├─→ RenderTOP → texture output
                         LightCOMP    │
                         MergeCOMP  ──┘
```

Physics simulation (Jolt), environment/post-processing, instancing, animation — all composable as nodes.

### GPU Compute

- **POP family** — SSBO-based GPU particles with double-buffered compute dispatches, CPU readback for SOP/CHOP bridging
- **VOL family** — Texture3D compute volumes with Navier-Stokes fluid sim, raymarching, marching cubes
- **Graceful degradation** — compute nodes auto-skip with a warning badge on OpenGL/WebGL2; everything else keeps working

### Projection Mapping

7 dedicated operators for multi-projector setups: perspective/bezier/grid warp, soft edge blending, projection masks, and auto-blend calibration.

### Extensions

All extensions are self-contained — delete a folder and it disappears cleanly, no core changes required.

| Extension | Ops | What It Does | Requirements |
|-----------|-----|--------------|--------------|
| **SDF** | 29 | Signed distance field composition — 10 primitives, 5 booleans, 8 modifiers, raymarcher | Pure GDScript — no build needed |
| **Audio** | 13 | Synthesis, EQ, reverb, delay, pitch shift, gate, envelope, movie extract, UDP stream, offline bounce | Pure GDScript — no native dependencies |
| **OpenCV** | 20 | 20 computer vision operators — contour, Hough, ArUco, optical flow, calibration | `setup_opencv.py` + build `gn_ext_opencv` |
| **ML** | 7 | ONNX Runtime ML inference — pose, hand, face, depth, style, segmentation, detection | Run `python scripts/setup_ml.py` to download ONNX Runtime (~30 MB) |
| **Mapper** | 7 | Projection mapping — QuadMap, BezierMap, GridWarp, EdgeBlend, Stoner, Mask, ProjectorBlend | Pure GDScript — no build needed |
| **PixelMapper** | 10 | LED pixel mapping — define fixture layouts, GPU sample, DMX output | Pure GDScript — no build needed |
| **Shadertoy** | 1 | Paste any `mainImage` GLSL — auto-translated uniforms, URL fetch, 10 presets | Pure GDScript — no build needed |
| **ISF** | 1 | Interactive Shader Format v2 — auto-generated params from JSON headers, multi-pass | Pure GDScript — no build needed |
| **LibPd** | 3 | Pure Data audio synthesis — send/receive messages, control patches | Requires compiled libpd binary (see extension README) |
| **Serial** | 2 | Serial port I/O — Arduino, DMX controllers, sensors | Requires gn_ext_native binary for full functionality |
| **HAP** | 2 | GPU-direct HAP/HAP-Q video codec — zero CPU decode, S3TC frames direct to GPU | Build `gn_ext_hap` |
| **Spout** | 2 | Windows GPU texture sharing with Resolume, OBS, TouchDesigner | Windows only — build `gn_ext_spout` |
| **Syphon** | 2 | macOS GPU texture sharing with VDMX, MadMapper, CoGe | macOS only. Requires Syphon Framework build |
| **Video Capture** | 1 | Webcam / capture device input (Media Foundation / AVFoundation / V4L2) | Build `gn_ext_video_capture` |
| **MIDI** | 2 | RtMidi I/O — notes, CC, pitch bend, clock | Build `gn_ext_midi` |
| **GPU Encode** | 1 | Hardware H.264/H.265 recording via OS encoder | Windows + macOS — build `gn_ext_gpu_encode` |
| **FFmpeg** | 1 | H.264/H.265/VP9/AV1 video decode via FFmpeg | Requires [EIRTeam.FFmpeg](https://github.com/EIRTeam/EIRTeam.FFmpeg) GDExtension |
| **NDI** | 4 | NDI video/audio I/O over the network | Requires proprietary NDI SDK. Disabled until SDK is present |
| **Depth Sensor** | 2 | Azure Kinect + RealSense + Ultraleap — depth, skeleton, hand tracking | Requires device SDK (Azure Kinect SDK / RealSense SDK / Ultraleap SDK) |
| **Blackmagic** | 3 | Blackmagic Design DeckLink capture/output | Requires DeckLink hardware and Blackmagic SDK |
| **User Native** | 1 | Write custom C++ operators in-editor with hot-reload | Bundled godot-cpp + MSVC/Clang. Compiles on first use |
| **User Python** | 1 | Write custom Python operators with NumPy | `setup_python.py` + build `gn_ext_user_python` |
| **Web Render** | 1 | Render HTML/CSS/JS/WebGL to texture via Chromium CEF | Requires `python scripts/setup_cef.py` (~550 MB download) |

Extensions can go far beyond adding operators — they can define **entirely new data families** with custom port types, wire colors, data classes, and palette sections. The SDF extension demonstrates this: it registers a new "SDF" family at runtime, complete with 29 operators, custom data type (`GNSDFData`), and its own wire color. No core code modification is required to add a new family. See [CONTRIBUTING.md §5](dev_docs/CONTRIBUTING.md) for the full extension authoring guide.

#### Extension Self-Containment

Every extension is **fully self-contained** inside its `addons/gn_ext_<name>/` folder. Core GONODES has zero hardcoded references to any extension. Delete an extension folder and everything — operators, help patches, presets, native binaries — disappears cleanly.

Extensions customize the editor through **registration hooks** provided by core:

- **Operators** — declared in `gn_extension.cfg`, auto-discovered by the registry
- **Code editors** — `boot.gd` calls `GNCodeEditor.register_code_language()` and `GNParamRow.register_code_param()` to add syntax highlighting, presets, and "Edit ↗" buttons for extension-specific params (e.g. HTML, JavaScript, ISF, GLSL)
- **Viewer display** — Override `render_for_viewer()` on operators for custom visualization; `handle_viewer_input()` virtual for input forwarding (e.g. mouse → CEF browser)
- **New families** — `GNFamily.register_family()` creates entirely new data types with custom wire colors, palette sections, and data classes
- **Native binaries** — `.gdextension` files ship as `.disabled` by default; `sync_native_extensions()` auto-activates them when the platform binary exists on disk, silencing Godot's startup warnings on machines where the binary hasn't been compiled

This design means anyone can write, distribute, and install an extension without touching a single line of core code.

### Scripting

Three consolidated SCRIPT family nodes (GDScriptSCRIPT, PythonSCRIPT, NativeSCRIPT) plus CallbackDAT:

- Template dropdown selects target context (CHOP, SOP, DAT, IMG, TOP, Generic)
- `par("name")` reads custom parameters declared via annotations
- Read and **write** parameters across the graph with `set_par()`
- Procedurally create/destroy nodes and connections via the Network API
- GDScriptSCRIPT Generic template outputs any family via `# @output` annotations
- CallbackDAT fires on cook, param change, creation, or startup

### Debug & Profiling

Press **F2** to open the debug system:

- **Cook Chain** — per-node cook time in topological order; sort to find bottlenecks
- **Active Chains** — tree view from each sink showing all upstream dependencies
- **Param References** — every cross-node expression with evaluation time
- **Graph Overlay** — five toggleable layers: cook order badges, inactive dimming, dirty propagation flash, sink halos, and data dimensions on every wire (`512×512`, `3ch×128`, `2400v`)

### Workflow

- **Smart wiring** — drop a wire on empty canvas → filtered palette shows only compatible operators → auto-connect
- **Sub-networks** — Ctrl+G to group, Enter to dive, Backspace to exit (Houdini-style dive navigation)
- **Custom operators** — save sub-networks as `.gnasset` files; they appear in the palette like built-in nodes (inspired by Houdini's Digital Assets / HDAs)
- **Presets** — save/load parameter states; copy between nodes of the same type
- **Spare parameters** — right-click any node → *Add Spare Parameter* to attach custom Float, Int, Bool, String, Color, or Vector params. Optionally set min/max range for numeric types. Drive them with expressions just like built-in params. Saved with the patch (Houdini-style)
- **User C++ / Python operators** — write custom operators in C++ or Python with hot-reload (inspired by Houdini's HDK and Python SOPs)
- **Ramp curves** — cubic Hermite ramp parameter type with visual curve editor
- **Annotations** — network boxes and sticky notes for graph organization
- **Quick Build** — one-click export to standalone app for any platform
- **Multi-window output** — WindowOUT opens OS windows on any display, per-window input tracking for keyboard/mouse/touch
- **Undo/redo, copy/paste, save/load** — all wired up

### Help System

Every operator has a **?** button that opens auto-generated documentation (inputs, outputs, parameters, description) plus hand-written guides where available. **2,085 example patches** open in floating editor windows so your work stays untouched.

### Testing

**2,082 automated tests** across 81 test files covering all 15 families, the cook engine, parameter system, data types, serialization, and operator behavior.

### GONODES Player — Standalone Export

Click **Build** in the editor and your patch becomes a standalone application — no Godot editor required at runtime.

- **Quick Build** — one-click export copies a pre-built Player binary + your `.gnpatch` + assets + `config.json` to a folder. Double-click to run.
- **8 platform targets** — Windows (x86_64, ARM64), macOS (universal), Linux (x86_64, ARM64), Android, iOS, and Web (HTML5/WebAssembly).
- **Multi-window** — each WindowOUT opens an independent OS window, auto-positioned across displays. The Player auto-opens all windows on launch.
- **Headless mode** — patches without WindowOUTs still cook: file-save operators, OSC/MIDI output, `SinkOUT` (keep-alive for any chain), and `Force Active` scripts keep the engine alive at near-zero idle.
- **Renderer fallback** — Forward+ (Vulkan/D3D12/Metal) with automatic fallback to Compatibility (OpenGL 3.3/WebGL2). GPU particles and compute volumes gracefully degrade on OpenGL.
- **config.json** — minimal config alongside the executable: `{ "patch": "MyShow.gnpatch" }`. Override via `--patch <path>` CLI.

Player templates are pre-built once via `scripts/build_templates.ps1` (or `.sh`) and stored in `templates/`. Rebuild after upgrading Godot. See [dev_docs/PLAYER.md](dev_docs/PLAYER.md) for internals and [dev_docs/BUILD.md](dev_docs/BUILD.md) for the build system.

---

## On the Shoulders of Giants

GONODES does not replace Godot — it *completes* it for a different audience. Every capability we needed, we asked: "does Godot already do this?" Almost always, yes.

**Rendering** — Godot's `RenderingDevice` and `RenderingServer` handle every pixel. TOP textures are Godot `RID` handles. The 3D pipeline runs in a live `SubViewport`. GPU particles use Godot's compute pipeline. When Godot ships a new rendering feature, GONODES gets it for free.

**Editor** — The node graph is a Godot `GraphEdit`. The inspector is a `Control` tree. Theming, input handling, font rendering, accessibility — all inherited.

**Export** — Godot's export system, untouched. A GONODES patch becomes a standalone app via the same templates any Godot game uses. LibGodot means patches can be embedded in a VJ host, an installation controller, or a broadcast graphics engine.

**Scripting** — Expressions compile and run on Godot's GDScript VM. Production-grade, sandboxed, hot-reloadable — for free.

**Native code** — GDExtension gives access to FFmpeg, RtMidi, Spout, and custom C++ operators through Godot's stable ABI.

Godot's roadmap is our roadmap. Renderer improvements, WebAssembly, XR integration — every advance becomes available to GONODES the moment Godot ships it. We focus on what's unique (the operator model, the cook engine, the parameter system) and borrow everything else from one of the most active open-source engines in the world.

Building on Godot is not a constraint. It is the point.

---

## Getting Started

### Run the Editor (no build required)

All core operators and most extensions are pure GDScript -- no compilation needed to get started.

1. Clone the repository:
   ```bash
   git clone https://gitlab.com/kino-dome/gonodes.git
   cd gonodes
   ```
2. Install **[Godot 4.7.2 stable](https://godotengine.org/download)**
   (and matching export templates when you need Player/editor exports)
3. Open Godot, click **Import**, select the `gonodes` folder
4. Open and run `scenes/gn_editor.tscn`

That is all. The editor runs immediately with **pure GDScript** operators — no
build required. Native C++ extensions (MIDI, HAP, Spout, OpenCV, etc.) must
be built locally; see [Building Native Extensions](#building-native-extensions-optional) below.

**Requirements:** Godot 4.7.2, Python 3.8+ (for build scripts). Windows 10/11,
macOS, or Linux. The repo ships **source only** — no pre-built binaries in git.

### Dependency Version Management

All external dependency versions (Godot, godot-cpp branch) are centralized in a single file at the project root:

```bash
# versions.env — single source of truth
GODOT_VERSION=4.7.2
GODOTCPP_BRANCH=4.5
```

`setup_deps.py` reads from `versions.env` automatically. CI workflows reference the same file. To upgrade Godot or godot-cpp, edit **only** `versions.env` — then run `python scripts/check_versions.py` to verify all CI workflows match.

### Building Native Extensions (optional)

GONODES works out of the box with pure GDScript. Native C++ extensions provide acceleration for CPU-heavy operators and hardware I/O. A unified build system compiles all extensions from a single entry point.

**Windows quick path:**

```powershell
$env:PYTHONUTF8 = "1"
$env:GONODES_GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
pip install scons
# VS 2022 Build Tools with C++ workload required (see dev_docs/BUILD.md)
python scripts/check_env.py
.\scripts\build_windows.ps1              # tier=all — skips optional SDKs that are missing
.\scripts\build_windows.ps1 -Shipped     # faster: core + extension tiers only
python addons/gn_ext_user_python/setup_python.py
python scripts/bundle_toolchain.py
python scripts/check_builds.py
```

**Manual steps (all platforms):**

```bash
# Prerequisites: Python 3.8+, SCons, MSVC (Windows) or GCC/Clang (Linux/macOS)
pip install scons
python scripts/check_env.py

# 1. Fetch dependencies (godot-cpp, Spout2, setup_python, setup_opencv, setup_ml, ...)
python setup_deps.py

# 2. Build godot-cpp (once per Godot version):
cd addons/gn_ext_native/native/godot-cpp
scons platform=windows arch=x86_64 target=template_release -j8
cd ../../../..

# 3. Build native extensions (optional tier included when SDK is present):
cd build
scons tier=all platform=windows arch=x86_64 target=template_release -j8
cd ..
# Extensions are auto-activated after build (sync_gdextensions.py runs post-build)
# Proprietary SDK misses (NDI, Blackmagic, …) are skipped — not fatal.

# Or build a single extension:
cd build
scons ext=gn_ext_hap platform=windows -j4
scons ext=gn_ext_midi platform=linux -j4

# List what's available:
scons --list-extensions
```

Extensions that don't support the target platform are silently skipped. See [build/README.md](build/README.md) for the full reference, or [dev_docs/BUILD.md](dev_docs/BUILD.md) for CI pipelines, cross-compilation, and Player template builds.

### GN Extensions — Operator Packs

GONODES has its own extension system built on top of Godot's GDExtension. A **GN Extension** is a folder under `addons/gn_ext_<name>/` with a `gn_extension.cfg` manifest that registers operators, declares platform requirements, and lists dependencies. The registry auto-discovers and loads them at startup.

GN Extensions can range from **pure GDScript** (no compilation needed) to **full C++ GDExtension** addons with native binaries. Three shipped extensions demonstrate the pure-GDScript approach — zero external dependencies, no build step, just operators + shaders in a folder:

| Extension | Operators | What It Does |
|-----------|-----------|-------------|
| **gn_ext_shadertoy** | 1 | Paste/fetch Shadertoy GLSL shaders, auto-translated to Godot |
| **gn_ext_isf** | 1 | ISF v2 interactive shader format with multi-pass and auto-parameter generation |
| **gn_ext_mapper** | 7 | Projection mapping — QuadMap, BezierMap, GridWarp, EdgeBlend, Stoner, Mask, ProjectorBlend |
| **gn_ext_webrender** | 1 | Render web pages to texture via Chromium CEF — URL or inline HTML, input forwarding |

These exist as extensions rather than core operators specifically to serve as **templates for building your own packs**. Copy one, rename the folder, edit `gn_extension.cfg`, add your operators — that's it. No C++ required.

Extensions that *do* use C++ for hardware I/O or performance (NDI, MIDI, Spout, depth sensors, ML inference, etc.) follow the same pattern but add a `native/` directory with a `SConstruct` and C++ source. See [dev_docs/CONTRIBUTING.md](dev_docs/CONTRIBUTING.md) for the full extension authoring guide.

### Sharing Packs — .gnasset & Extensions

GONODES supports two distribution formats:

- **`.gnasset` files** — Self-contained JSON operator packages. Right-click any SubNetwork → "Promote to Custom Asset" to create one. Recipients drop the file into `custom_operators/` or `user://gonodes_assets/` and it appears in the palette immediately. Good for individual custom operators and small reusable modules.

- **GN Extension folders** — For larger packs (multiple operators, shaders, help docs, tests), distribute an `addons/gn_ext_<name>/` folder. Users copy it into their project's `addons/` directory. The registry picks it up automatically — no code changes, no registration calls.

Both formats work today. A dedicated asset browser and community sharing portal are on the roadmap.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  UI Layer                                   │
│  Node graph, Inspector, Viewer, Debug       │
├─────────────────────────────────────────────┤
│  Operator Library (585)                     │
│  TOPs, CHOPs, SOPs, POPs, VOLs, DATs,      │
│  MATs, COMPs, IMGs, OUTs, UIs              │
├─────────────────────────────────────────────┤
│  Cook Engine                                │
│  Topological DAG walk, dirty propagation,   │
│  active-chain pruning, expression eval,     │
│  output demand culling                      │
├─────────────────────────────────────────────┤
│  Data Types & Parameters                    │
│  Textures, Channels, Geometry, Tables,      │
│  Materials — expressions, bind, export      │
├─────────────────────────────────────────────┤
│  Godot 4.7.2 Engine                           │
│  Rendering, Audio, Compute, Physics, I/O    │
└─────────────────────────────────────────────┘
```

For the full technical design document, see [GONODES_CONTEXT.md](GONODES_CONTEXT.md). For contributor guidelines, see [dev_docs/](dev_docs/).

---

## Roadmap

- ~~LibGodot embedding for host applications~~ — **Done.** Full C API (`libgonodes/`), 6 bridge operators (HostIn/OutTOP, CHOP, DAT), GPU context sharing (Vulkan/Metal/OpenGL zero-copy), hot-reload, introspection, 5 example apps. See [dev_docs/INTEGRATION.md](dev_docs/INTEGRATION.md).
- ~~Multi-threaded cook engine~~ — **Done.** Level-based parallelism via `WorkerThreadPool`. CPU families (CHOP, SOP, DAT, IMG) cook in parallel within each topological level; GPU families (TOP, POP, VOL) remain on main thread.
- ~~Event-driven expression evaluation~~ — **Done.** Expression consumer map (`_expr_consumer_map`) replaces per-frame polling; expressions only re-evaluate when referenced upstream nodes actually cook.
- ~~Output sinks (Spout, MIDI, OSC, Audio)~~ — **Done.** SpoutOutTOP, RtMidiOutCHOP, OscOUT, AudioDeviceOUT — all with `is_sink = true`.
- ~~Generic multi-output ScriptNode~~ — **Done.** `GDScriptSCRIPT` (SCRIPT family) with `# @output` annotations for any mix of data types. Template dropdown for CHOP/SOP/DAT/IMG starting code.
- ~~JSON serialization (.gnpatch)~~ — **Done.** `.gnpatch` JSON format used for all patch files, including cross-app portability via libgonodes C API.
- ~~FFmpeg GDExtension~~ — **Done.** FFmpegInTOP (decode: H.264, H.265, VP9, AV1, ProRes + all FFmpeg codecs), FFmpegOUT (encode: H.264, H.265, VP9, AV1, ProRes via CLI), MovieFileOutTOP (GPU hardware H.264/H.265 encode via MF/VideoToolbox).
- ~~HAP codec~~ — **Done.** `gn_ext_hap` GDExtension with HapInTOP (GPU-direct DXT playback, zero CPU decode) and HapOutTOP (DXT compress + Snappy + MOV mux). Supports HAP, HAP Alpha, HAP Q variants.
- ~~NDI video streaming (NDIOutTOP)~~ — **Done.** `ndi_out_top.gd` ships in `gn_ext_ndi`.
- FxPlug / FFGL plugin export
- Laser DAC drivers — EtherDream, Helios, ShowNET (GDExtension; data model via LaserCHOP ready)
- Network collaboration (shared editing)
- Modular extension distribution (per-extension `.pck` install/remove)

For the full roadmap including optimisation tiers, see [dev_docs/ROADMAP.md](dev_docs/ROADMAP.md).

### LibGONODES — Embeddable Engine

The `libgonodes/` directory contains a complete C shared library for embedding GONODES in any host application — VJ tools, media servers, game engines, creative coding frameworks. Eight working example apps are included:

| Example | What It Demonstrates |
|---------|---------------------|
| `vulkan_host/` | Vulkan shared GPU context — zero-copy texture exchange |
| `metal_host/` | Metal shared device — zero-copy on macOS/iOS |
| `opengl_host/` | OpenGL shared context — legacy GPU path |
| `sdl_host/` | SDL2 window — cross-platform minimal embedding |
| `params_demo/` | Parameter introspection and live control from the host |
| `geometry_host/` | Geometry/SOP exchange — push mesh data to HostInSOP and read cooked outputs back |
| `midi_osc_host/` | MIDI/OSC bridge — protocol injection, events, transport, and resolution override |
| `graph_edit_demo/` | Dynamic graph editing — insert, wire, and delete nodes programmatically |

See [libgonodes/README.md](libgonodes/README.md) and [dev_docs/INTEGRATION.md](dev_docs/INTEGRATION.md) for the full API reference.

---

## Known Limitations


- **Shadertoy multi-pass:** The ShadertoyTOP translator only supports single-pass Shadertoy shaders (the “Image” tab). Multi-pass shaders using Buffer A/B/C/D are not converted. **Workaround:** manually split buffer passes into separate CustomShaderTOP nodes wired together.
- **GLSLMultiTOP MRT transpiler:** SCREEN_TEXTURE and custom varyings are not supported in MRT mode. **Workaround:** use CustomShaderTOP + SelectTOP for shaders that need these features.

---

## Contributing

Start by reading [GONODES_CONTEXT.md](GONODES_CONTEXT.md) for the architecture overview and [dev_docs/CONTRIBUTING.md](dev_docs/CONTRIBUTING.md) for guidelines, then open an issue to discuss what you'd like to work on.

---

## License

MIT License — see [LICENSE](LICENSE) for the full text.

GONODES is free and open source. You can use it for personal projects, commercial products,
installations, performances, and embedded applications without restrictions or royalties.

Third-party dependencies ship under their own licenses (see `addons/gn_ext_*/` for per-extension details):
- Godot Engine — MIT
- godot-cpp — MIT
- FFmpeg (gn_ext_ffmpeg) — LGPL 2.1+ (dynamically linked)
- RtMidi (gn_ext_midi) — MIT-like
- Spout SDK (gn_ext_spout) — BSD 2-Clause
- ONNX Runtime (gn_ext_ml) — MIT

---

## Acknowledgments

- [SideFX Houdini](https://www.sidefx.com) — the gold standard of procedural content creation. Houdini's HDK, digital assets, VEX, and deep procedural philosophy directly inspired GONODES' custom operator system, sub-network packaging, spare parameters, and the cook engine's dependency-driven evaluation model.
- [Derivative TouchDesigner](https://derivative.ca) — for pioneering real-time node-based visual programming. The operator family model (TOP/CHOP/SOP/DAT/COMP/MAT), wire-based data flow, live expression system, and performance-first design are all rooted in TouchDesigner's vision.
- [Godot Engine](https://godotengine.org) — for being an incredible open-source foundation that makes all of this possible
- [VUO](https://vuo.org) — for proving embeddable node-based compositions work in host applications
- [Max/MSP](https://cycling74.com) and [vvvv](https://vvvv.org) — for decades of innovation in visual programming for media art
