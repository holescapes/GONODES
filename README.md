# GONODES

**Real-time node-based visual programming, built on [Godot 4.6](https://godotengine.org). Inspired by [TouchDesigner](https://derivative.ca).**

Wire operators together, tweak parameters live, see results instantly — then export your patch as a standalone app on any platform Godot supports.

---

## Why GONODES?

If you've used TouchDesigner, Max/MSP, vvvv, or VUO, you know the workflow: connect nodes, data flows through wires, visuals appear in real time. GONODES brings that to Godot — with some unique advantages:

- **Ship anywhere.** Export patches as standalone apps on Windows, macOS, Linux, Android, iOS, and Web — no runtime license fees.
- **GPU-powered.** Vulkan, Metal, D3D12, and OpenGL rendering. Compute shaders for GPU particles and volumetrics.
- **Embeddable.** With LibGodot (Godot 4.6+), GONODES patches can run inside VJ tools like VDMX or Resolume.
- **Open source.** No black boxes. Read every line, extend anything.

---

## Features at a Glance

**371 operators** across **11 families**, plus **69 native C++ accelerated operators** and **8 extensions**.  
Parallel level-based cook engine, named output ports, dot routing nodes, and keyframe animation.

### Operator Families

| Family | What It Processes | Examples |
|--------|-------------------|----------|
| **TOP** (83) | Textures & images | Noise, Composite, Blur, ChromaKey, Feedback, Render, Deform, Reorder |
| **CHOP** (76) | Signals & channels | LFO, Keyframe, Sequence, Clip, Channel, Object, Skeleton, MIDI |
| **SOP** (71) | 3D geometry | Grid, Boolean, Extrude, Smooth, PolyBevel, Remesh, PolySpline |
| **DAT** (37) | Data tables & text | JSON, Web, WebSocket, Serial, DMX, RenderPick, PanelExecute |
| **COMP** (20) | 3D scene & sub-networks | Geometry, Camera, Light, RigidBody, Instance, Replicator |
| **POP** (10) | GPU particles | Source, Force, Turbulence, Collision, Attract, Advect |
| **VOL** (11) | Volumetric 3D textures | Noise, Fluid sim, Marching Cubes, Raymarch |
| **MAT** (9) | Materials & shaders | PBR, Custom Shader, Wireframe, PointSprite |
| **IMG** (14) | CPU image processing | Noise, EdgeDetect, PixelSort, Webcam, ScreenGrab |
| **OUT** (9) | Output & export | WindowOUT, MovieOUT, FFmpegOUT, AudioDeviceOUT, OscOUT |
| **UI** (31) | Interactive 2D widgets | Button, Slider, Knob, XYPad, ColorPicker, Tree, TabContainer |

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
           PBR_MAT      CameraCOMP   ├─→ RenderTOP → texture output
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
| **Spout** | Windows GPU texture sharing with Resolume, OBS, TouchDesigner |
| **Syphon** | macOS GPU texture sharing with VDMX, MadMapper, CoGe |
| **Video Capture** | Cross-platform webcam input (Media Foundation / AVFoundation / V4L2) |
| **MIDI** | RtMidi I/O — notes, CC, pitch bend to controllers and DAWs |
| **GPU Encode** | Hardware H.264 MP4 recording (Media Foundation / VideoToolbox) |
| **Mapper** | Projection mapping toolkit — QuadMap, BezierMap, GridWarp, EdgeBlend, and more |

### Scripting

Six script-capable operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG, GenericScriptNode, CallbackDAT) with runtime GDScript compilation:

- Read and **write** parameters across the graph with `set_par()`
- Procedurally create/destroy nodes and connections via the Network API
- GenericScriptNode outputs any family via `# @output` annotations
- CallbackDAT fires on cook, param change, creation, or startup

### Debug & Profiling

Press **F2** to open the debug system:

- **Cook Chain** — per-node cook time in topological order; sort to find bottlenecks
- **Active Chains** — tree view from each sink showing all upstream dependencies
- **Param References** — every cross-node expression with evaluation time
- **Graph Overlay** — five toggleable layers: cook order badges, inactive dimming, dirty propagation flash, sink halos, and data dimensions on every wire (`512×512`, `3ch×128`, `2400v`)

### Workflow

- **Smart wiring** — drop a wire on empty canvas → filtered palette shows only compatible operators → auto-connect
- **Sub-networks** — Ctrl+G to group, Enter to dive, Backspace to exit
- **Custom operators** — save sub-networks as `.gnasset` files; they appear in the palette like built-in nodes
- **Presets** — save/load parameter states; copy between nodes of the same type
- **Spare parameters** — add any param type to any node (Houdini-style)
- **Ramp curves** — cubic Hermite ramp parameter type with visual curve editor
- **Annotations** — network boxes and sticky notes for graph organization
- **Quick Build** — one-click export to standalone app for any platform
- **Multi-window output** — WindowOUT opens OS windows on any display, per-window input tracking for keyboard/mouse/touch
- **Undo/redo, copy/paste, save/load** — all wired up

### Help System

Every operator has a **?** button that opens auto-generated documentation (inputs, outputs, parameters, description) plus hand-written guides where available. **1,084 example patches** — 3+ per operator — open in floating editor windows so your work stays untouched.

### Testing

**690 automated tests** covering the cook engine, parameter system, data types, serialization, and operator behavior.

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

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  UI Layer                                   │
│  Node graph, Inspector, Viewer, Debug       │
├─────────────────────────────────────────────┤
│  Operator Library (371 + extensions)        │
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
- FFmpeg GDExtension — H.264, VP9, AV1, ProRes decode/encode
- HAP codec (GPU-direct S3TC/DXT video for VJ workflows)
- NDI video streaming
- FxPlug / FFGL plugin export
- Multi-threaded cook engine
- Laser DAC drivers — EtherDream, Helios, ShowNET (GDExtension; data model via LaserCHOP ready)
- Serial port GDExtension — hardware I/O backend for SerialSendDAT / SerialReceiveDAT
- Network collaboration (shared editing)

---

## Contributing

Start by reading [GONODES_CONTEXT.md](GONODES_CONTEXT.md) for the architecture overview and [dev_docs/CONTRIBUTING.md](dev_docs/CONTRIBUTING.md) for guidelines, then open an issue to discuss what you'd like to work on.

---

## License

TBD

---

## Acknowledgments

- [Derivative TouchDesigner](https://derivative.ca) — for pioneering real-time node-based visual programming
- [Godot Engine](https://godotengine.org) — for being an incredible open-source foundation
- [VUO](https://vuo.org) — for proving embeddable node-based compositions work in host apps
