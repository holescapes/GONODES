# GONODES

**Real-time node-based visual programming, built on [Godot 4.6](https://godotengine.org). Inspired by [TouchDesigner](https://derivative.ca) and [Houdini](https://www.sidefx.com).**

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

**533 operators** across **13 families**, plus **92 native C++ accelerated operators** and **18 extensions**.  
Parallel level-based cook engine, named output ports, dot routing nodes, and keyframe animation.

### Operator Families

| Family | What It Processes | Examples |
|--------|-------------------|----------|
| **TOP** (101) | Textures & images | Noise, Composite, Blur, ChromaKey, Feedback, Render, Deform, Reorder |
| **CHOP** (109) | Signals & channels | LFO, Keyframe, Sequence, Clip, Channel, Object, Skeleton, MIDI |
| **SOP** (117) | 3D geometry | Grid, Boolean, Extrude, Smooth, PolyBevel, Remesh, PolySpline |
| **DAT** (44) | Data tables & text | JSON, Web, WebSocket, Serial, DMX, RenderPick, PanelExecute |
| **COMP** (19) | 3D scene & sub-networks | Geometry, Camera, Light, RigidBody, Instance, Replicator |
| **POP** (20) | GPU particles | Source, Force, Turbulence, Collision, Attract, Advect |
| **VOL** (22) | Volumetric 3D textures | Noise, Fluid sim, Marching Cubes, Raymarch |
| **MAT** (10) | Materials & shaders | PBR, Custom Shader, Wireframe, PointSprite |
| **IMG** (18) | CPU image processing | Noise, EdgeDetect, PixelSort, Webcam, ScreenGrab |
| **OUT** (13) | Output & export | WindowOUT, MovieOUT, FFmpegOUT, AudioDeviceOUT, OscOUT |
| **UI** (31) | Interactive 2D widgets | Button, Slider, Knob, XYPad, ColorPicker, Tree, TabContainer |
| **SDF** (26) | Signed distance fields | Box, Sphere, Torus, Boolean ops, Bend, Twist, Raymarch |
| **SCRIPT** (3) | User scripting | GDScript, Python, C++ — template-based multi-family output |

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

| Extension | What It Does |
|-----------|-------------|
| **Shadertoy** | Paste any `mainImage` GLSL shader — auto-translated uniforms, URL fetch, 10 presets |
| **ISF** | Interactive Shader Format v2 — auto-generated params from JSON headers, multi-pass |
| **HAP** | GPU-direct video codec — S3TC/DXT frames uploaded to GPU with zero CPU decode |
| **Spout** | Windows GPU texture sharing with Resolume, OBS, TouchDesigner |
| **Syphon** | macOS GPU texture sharing with VDMX, MadMapper, CoGe |
| **Video Capture** | Cross-platform webcam input (Media Foundation / AVFoundation / V4L2) |
| **MIDI** | RtMidi I/O — notes, CC, pitch bend to controllers and DAWs |
| **GPU Encode** | Hardware H.264 MP4 recording (Media Foundation / VideoToolbox) |
| **Mapper** | Projection mapping toolkit — QuadMap, BezierMap, GridWarp, EdgeBlend, and more |
| **SDF** | Signed distance field composition — 10 primitives, 5 booleans, 8 modifiers, raymarcher |
| **Serial** | Serial port I/O for hardware communication (Arduino, DMX controllers, sensors) |
| **NDI** | NDI video/audio I/O — send and receive over the network |
| **ML** | ONNX Runtime ML inference — pose, hand, face, depth, style, segmentation, detection |
| **Depth Sensor** | Azure Kinect + RealSense + Ultraleap — depth, color, skeleton, hand tracking |
| **Blackmagic** | Blackmagic Design capture card input/output |
| **User Native** | Write custom C++ operators in-editor with hot-reload |
| **User Python** | Write custom Python operators with NumPy |

Extensions can go far beyond adding operators — they can define **entirely new data families** with custom port types, wire colors, data classes, and palette sections. The SDF extension demonstrates this: it registers a new "SDF" family at runtime, complete with 40+ operators, custom data type (`GNSDFData`), and its own wire color. No core code modification is required to add a new family. See [CONTRIBUTING.md §5](dev_docs/CONTRIBUTING.md) for the full extension authoring guide.

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
- **Spare parameters** — add any param type to any node (Houdini-style)
- **User C++ / Python operators** — write custom operators in C++ or Python with hot-reload (inspired by Houdini's HDK and Python SOPs)
- **Ramp curves** — cubic Hermite ramp parameter type with visual curve editor
- **Annotations** — network boxes and sticky notes for graph organization
- **Quick Build** — one-click export to standalone app for any platform
- **Multi-window output** — WindowOUT opens OS windows on any display, per-window input tracking for keyboard/mouse/touch
- **Undo/redo, copy/paste, save/load** — all wired up

### Help System

Every operator has a **?** button that opens auto-generated documentation (inputs, outputs, parameters, description) plus hand-written guides where available. **1,413 example patches** — 3+ per operator — open in floating editor windows so your work stays untouched.

### Testing

**1,355 automated tests** across 31+ test files covering all 13 families, the cook engine, parameter system, data types, serialization, and operator behavior.

### GONODES Player — Standalone Export

Click **Build** in the editor and your patch becomes a standalone application — no Godot editor required at runtime.

- **Quick Build** — one-click export copies a pre-built Player binary + your `.gnpatch` + assets + `config.json` to a folder. Double-click to run.
- **8 platform targets** — Windows (x86_64, ARM64), macOS (universal), Linux (x86_64, ARM64), Android, iOS, and Web (HTML5/WebAssembly).
- **Multi-window** — each WindowOUT opens an independent OS window, auto-positioned across displays. The Player auto-opens all windows on launch.
- **Headless mode** — patches without WindowOUTs still cook: file-save operators, OSC/MIDI output, and `Force Active` scripts keep the engine alive at near-zero idle.
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

```bash
# Clone the repo
git clone https://github.com/your-username/gonodes.git

# Open in Godot 4.6+
# File → Open Project → select the gonodes folder
# Run the editor scene (scenes/gn_editor.tscn)
```

**Requirements:** Godot 4.6 or later. Windows, macOS, or Linux for the editor. Exported patches run on all Godot-supported platforms.

### Building Native Extensions (optional)

GONODES works out of the box with pure GDScript. Native C++ extensions provide acceleration for CPU-heavy operators and hardware I/O. A unified build system compiles all extensions from a single entry point:

```bash
# Prerequisites: Python 3, SCons, C++ compiler
pip install scons
cd addons/gn_ext_native/native
git submodule update --init --recursive
scons platform=windows arch=x86_64 -j4      # Build godot-cpp + native operators

# Build all other extensions (HAP, MIDI, Spout, etc.):
cd ../../../build
scons platform=windows arch=x86_64 -j4      # Auto-discovers and builds all

# Or build a single extension:
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
| **gn_ext_mapper** | 5 | Projection mapping — quad pin, bezier warp, grid warp, edge blend, mask |

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
│  Operator Library (402 + extensions)        │
│  TOPs, CHOPs, SOPs, POPs, VOLs, DATs,      │
│  MATs, COMPs, IMGs, OUTs, UIs              │
├─────────────────────────────────────────────┤
│  Cook Engine                                │
│  Topological DAG walk, dirty propagation,   │
│  active-chain pruning, expression eval      │
├─────────────────────────────────────────────┤
│  Data Types & Parameters                    │
│  Textures, Channels, Geometry, Tables,      │
│  Materials — expressions, bind, export      │
├─────────────────────────────────────────────┤
│  Godot 4.6 Engine                           │
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
- NDI video streaming (NDIOutTOP)
- FxPlug / FFGL plugin export
- Laser DAC drivers — EtherDream, Helios, ShowNET (GDExtension; data model via LaserCHOP ready)
- Network collaboration (shared editing)

### LibGONODES — Embeddable Engine

The `libgonodes/` directory contains a complete C shared library for embedding GONODES in any host application — VJ tools, media servers, game engines, creative coding frameworks. Five working example apps are included:

| Example | What It Demonstrates |
|---------|---------------------|
| `vulkan_host/` | Vulkan shared GPU context — zero-copy texture exchange |
| `metal_host/` | Metal shared device — zero-copy on macOS/iOS |
| `opengl_host/` | OpenGL shared context — legacy GPU path |
| `sdl_host/` | SDL2 window — cross-platform minimal embedding |
| `params_demo/` | Parameter introspection and live control from the host |

See [libgonodes/README.md](libgonodes/README.md) and [dev_docs/INTEGRATION.md](dev_docs/INTEGRATION.md) for the full API reference.

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
