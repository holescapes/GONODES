# GONODES

**A real-time node-based visual programming framework built on [Godot 4.6](https://godotengine.org), inspired by [TouchDesigner](https://derivative.ca).**

GONODES brings the creative power of node-based visual programming to the Godot ecosystem — wire together operators, tweak parameters in real time, and export your patches as standalone apps on any platform Godot supports.

---

## What Is This?

If you've used TouchDesigner, Max/MSP, vvvv, or VUO, you know the workflow: connect nodes together, data flows through wires, visuals appear in real time. GONODES brings that to Godot.

You build **patches** — networks of connected operators that process textures, signals, geometry, and data in real time. An LFO drives a noise texture. A CHOP channel modulates brightness. A particle system reacts to audio. You see everything update live as you wire things together.

### Why Godot?

- **Cross-platform for free.** Export your patches as standalone apps on Windows, macOS, Linux, Android, iOS, and Web.
- **GPU-powered.** Vulkan and OpenGL rendering, compute shaders, GPU particles — all built in.
- **LibGodot.** Starting with Godot 4.6, the engine can be embedded as a library in other applications. This means GONODES patches can run inside VJ tools like VDMX or Resolume.
- **Open source.** No licensing fees, no black boxes.

---

## On the Shoulders of Giants

GONODES does not try to replace Godot — it tries to *complete* it for a different audience. Every time we needed a capability, our first question was: "does Godot already have this?" Almost always, the answer was yes.

**Rendering** is handled entirely by Godot's `RenderingDevice` and `RenderingServer`. TOP textures are Godot `RID` handles. The 3D pipeline is a live Godot `SubViewport`. We do not write a single pixel ourselves that Godot's Vulkan / D3D12 / Metal back-end would have written better. GPU particles run on Godot's compute pipeline; 3D volumes use Godot's `Texture3D`. When Godot gains a new rendering feature — better shadow cascades, more samplers, a new anti-aliasing mode — GONODES gets it automatically.

**The editor** runs as a Godot `EditorPlugin`. The node graph is a `GraphEdit` widget. The inspector is a `Control` tree. Every piece of Godot's UI toolkit — theming, input handling, font rendering, internationalization, accessibility — flows through to GONODES without extra code.

**Export** is Godot's export system, untouched. A GONODES patch becomes a standalone desktop or mobile app via the same export templates and project settings any Godot game uses. LibGodot (available from 4.6 onward) means patches can be embedded as a living subsystem inside another application — a VJ host, an installation controller, a real-time broadcast graphics engine — with no modification to the GONODES codebase.

**Scripting** reuses Godot's GDScript VM. When you write an expression like `chop("lfo1", "out") * 10.0` in a parameter field, that fragment is compiled and run by the same runtime that powers Godot games. We get a production-grade, sandboxed, hot-reloadable scripting environment for free.

**GDExtension** means GONODES can reach out to native code — FFmpeg for video decoding, custom C++ operators for CPU-heavy algorithms — through Godot's stable ABI. The host engine is already there; we just write the bindings.

The philosophy scales forward: Godot's roadmap is our roadmap. Improvements to the renderer, the physics engine, the animation system, WebAssembly support, XR integration — every one of those becomes available to GONODES patches the moment Godot ships it. We spend our effort on what is *unique* to GONODES (the operator model, the cook engine, the parameter system, the real-time wiring) and borrow everything else from one of the most actively developed open-source engines in the world.

Building on Godot is not a constraint. It is the point.

---

## Core Concepts

### Operator Families

Everything in GONODES is an **operator** (node). Operators are organized into families:

| Family | What It Processes | Examples |
|--------|-------------------|----------|
| **TOP** | Textures and images | Noise, Composite, Levels, Blur |
| **CHOP** | Signals and channels (floats over time) | LFO, Math, Audio In, MIDI |
| **SOP** | 3D geometry (meshes, points) | Grid, Transform, Merge |
| **POP** | Point clouds and particles (GPU) | Particle, Force, Noise |
| **DAT** | Data tables and text | Table, Script, OSC In |
| **MAT** | Materials and shaders | PBR, Custom Shader |
| **COMP** | 3D scene containers and sub-networks | Geometry, Camera, Light |
| **UI** | 2D interface widgets for PanelTOP | Button, Slider, Knob, XYPad, TextureRect, ColorPicker, Tree, TabContainer |

### How It Works

1. **Drop nodes** onto the canvas from the palette.
2. **Wire them together.** Data flows left to right. Connections are type-safe — you can only connect compatible ports.
3. **Rename nodes.** Double-click a node's title bar to rename it inline. All connections, expressions, and references update automatically.
4. **Tweak parameters** in the inspector. Every parameter can be a constant value, a live expression, or bound to another node's output.
5. **See results instantly.** TOP outputs show live texture previews. The viewer panel shows full-resolution output.
6. **Export.** Package your patch as a standalone app for any platform.

### Parameter Referencing

Any parameter on any node can reference data from other nodes:

```
chop("lfo1", "out") * 10.0           # Drive a value with an LFO
op("noise1", "scale")                # Read another node's parameter
sin(time * 2.0) + 0.5                # Math expressions with timeramp(\"falloff\", 0.5)                 # Sample a ramp parameter curve at t=0.5
chop(\"ramp1\", \"falloff\")             # Read a RampCHOP channel as a float```

You can also **bind** parameters directly (zero-overhead link) or use **CHOP export** to push one signal to many parameters at once.

### Debugging & Profiling

Press **F2** (or click the **Debug** toolbar button) to open the debug system:

- **Debug Panel** — a docked panel below the graph with three tabs:
  - **Cook Chain** — every node in topological cook order, with per-node cook time, status, and active/inactive flag. Sort by cook time to find bottlenecks.
  - **Active Chains** — tree view rooted at each sink (WindowOUT, viewers), showing all upstream dependencies. Instantly see what feeds each output.
  - **Param References** — all expression-mode parameters with their cross-references (`chop()`, `par()`, `set_par()`) and evaluation time.
- **Graph Overlay** — five toggleable layers drawn directly on the canvas (like map layers you turn on/off):
  - **#Order** — cook order badges on each node
  - **Dim** — inactive nodes greyed out at 40% opacity
  - **Dirty** — orange border flash on nodes dirtied this frame (see the dirty wave ripple downstream)
  - **Sinks** — colored halo rings on sinks, colored dots on their upstream chains
  - **Flow** — data dimensions on every wire (e.g., `512×512` for textures, `3ch×128` for channels, `2400v` for geometry)

Double-click any row in the debug panel to select and scroll to that node. All debug state persists across sessions.

---

## Project Status

**Phase 7 Complete. 329+ operators across 11 families (TOP, IMG, CHOP, DAT, SOP, POP, VOL, COMP, MAT, OUT, UI) plus 69 native C++ accelerated operators, 2 shader extensions (Shadertoy, ISF), 5 hardware I/O extensions (Spout, Syphon, Video Capture, MIDI, GPU Encode), and 1 projection-mapping extension (Mapper). Save/load, copy/paste, undo/redo, live node previews, performance profiling, expression system, sub-networks, spare parameters, parameter presets, custom operator assets (.gnasset), GPU particles (POP), volumetric 3D textures (VOL), compute shader detection & graceful degradation, debug window & overlay system, OSC/MIDI/Audio I/O, 353 help patches, 690 automated tests passing.**

### Completed

- **Phase 1: Core Framework** — GNNode, GNNetwork, GNCookEngine, GNParameter, GNData, GNPort, GNConnection, GNFamily (11 core classes)
- **Phase 2: First Operators** — NoiseTOP, LevelTOP, CompositeTOP, LFO_CHOP, NoiseCHOP, MathCHOP, WindowOUT (7 operators + 3 shaders + test scene)
- **Phase 3: Node Graph UI** — GNGraphEditor (GraphEdit canvas), GNNodeView (family-colored GraphNodes), GNNodePalette (Tab to open, search + family grouping), bidirectional network sync, editor scene with HSplit layout
- **Phase 4: Parameters & Inspector** — GNParamInspector (live parameter panel), GNParamRow (type-specific controls: sliders, spinboxes, color pickers, enums, checkboxes), expression inline editor with mode toggle (C/E), live cook time display, NoiseTOP 4-algorithm shader
- **Phase 5: Operator Expansion** — 20 new TOPs + 17 new CHOPs + 14 new GPU shaders + CustomShaderTOP. Total at end of phase: 46 operators (26 TOPs + 20 CHOPs).
- **Phase 5.5: DAT, SOP, COMP & 3D Pipeline** — 12 DAT operators + 14 SOP operators + 3 COMP operators + RenderTOP. GNTableData and GNGeoData data types. Full 3D scene rendering pipeline using Godot's native scene graph. Total: ~75 operators across 5 families.
- **Phase 5.6: UI Polish & Node Renaming** — Canvas anchoring fix (all 21 TOPs use `set_anchors_and_offsets_preset`), viewer panel sizing fix (`expand_mode = IGNORE_SIZE`, `clip_contents`), inline node renaming (double-click title bar with full ID update chain), inspector refresh on rename.
- **Phase 5.7: File Parameters & Media Input** — FILE parameter type with project file picker (FileDialog). TextTOP font selection (TTF/OTF/WOFF). ImageFileInTOP (PNG, JPG, WebP, HDR, EXR, SVG). MovieFileInTOP (Godot VideoStreamPlayer, .ogv Theora).
- **Phase 5.8: Extension Registry Architecture** — GNExtensionRegistry singleton replaces static match-factory and description dictionary. Dynamic operator registration API. Extension scanning (`gn_ext_*` addon manifests with `gn_extension.cfg`). ClassDB dependency guards for GDExtension addons. FFmpeg extension as future reference implementation.
- **Phase 6: Integration & Stabilization** — Save/load patches (`.gnpatch` JSON), copy/paste with ID remapping, undo/redo (Godot UndoRedo), live node previews (per-family: texture, channels, tables, mesh stats), per-node preview toggle (right-click on/off), global preview master switch, performance profiling overlay (per-node cook time badges), right-click context menu, MAT family (PBR_MAT + Shader_MAT), MergeCOMP, shadow system (per-light/per-object/global), multiple floating viewer windows, WindowOUT open/close toggle, stress test (59 nodes, auto-report), bug fixes.
- **Architecture: Node/RefCounted migration** — GNNode extends Node (scene tree), GNData extends RefCounted (lightweight)
- **Multi-window output** — WindowOUT creates OS windows for VJ output on any connected display (zero-copy GPU texture routing)
- **Logging system** — GNLogger with level filtering, per-category muting, and runtime toggle button
- **Expression system** — `chop("lfo1", "out") * 5.0` drives parameters across node families in real time
- **Cook engine optimization** — Cached adjacency maps, upfront dirty propagation, zero-alloc input gathering, multi-input port support

### Known Bugs

- **WindowOUT ESC key:** Cannot ESC out of Fullscreen/Borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector panel.

### Operator Library

| Family | Count | Highlights |
|--------|-------|-----------|
| **TOP** | 77 | Noise, Composite, Level, Blur, Ramp, Text, ImageFileIn, MovieFileIn, FFmpegIn, Transform, CustomShader, Render, Feedback, Displace, ChromaKey, AnalyzeTOP, TimeMachine, Panel, SpoutIn/Out, SyphonIn/Out, MovieFileOut, QuadMap, BezierMap, GridWarp, EdgeBlend, ProjectionMask, Stoner, ProjectorBlend, and more |
| **IMG** | 14 | NoiseIMG, CheckerboardIMG, BlurIMG, EdgeDetectIMG, PixelSortIMG, ImgToTOP, TOPtoIMG, WebcamIMG, ImageFileInIMG, ImageSequenceIMG, ScreenGrabIMG, ScriptIMG, VideoDeviceInIMG, NullIMG |
| **CHOP** | 63 | LFO, Noise, Math, Constant, Wave, Filter, Lag, Timer, Trigger, Speed, Smooth, Spring, Delay, Envelope, Ramp, Expression, Keyboard/Mouse/Gamepad input, MidiIn, MidiOut, and more |
| **DAT** | 29 | Constant, Text, JSONDAT, WebDAT, FileInDAT, ScriptDAT, **CallbackDAT**, OPFindDAT, Evaluate, CHOPtoDAT, SOPtoDAT, TOPtoDAT, and more |
| **SOP** | 57 | Grid, Box, Sphere, Torus, Transform, Noise, Subdivide, Boolean, Extrude, Sweep, Skin, Bend, Twist, Font, ScriptSOP, and more |
| **COMP** | 20 | Geometry, Camera, Light, Merge, RigidBody, StaticBody, SoftBody, Area, Joint, Environment, Null, Switch, **GenericScriptNode**, Instance, Replicator, Animation, SubNetwork, InTunnel, OutTunnel, Engines |
| **MAT** | 6 | PBR, Shader, Constant, Wireframe, PointSprite, Depth |
| **OUT** | 9 | WindowOUT, TextureSaveOUT, ImageSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, AudioDeviceOUT, RecordOUT, OscOUT |
| **POP** | 10 | Source, Force, Turbulence, Collision, Attract, Limit, Advect, Instance, Render, ParticleState |
| **VOL** | 10 | Noise, Blend, Blur, Displace, Fluid, MarchingCubes, Raymarch, SOPtoVOL, CHOPtoVOL, Analyze |
| **UI** | 8 | ButtonUI, SliderUI, ToggleUI, LabelUI, KnobUI, XYPadUI, DropdownUI, ContainerUI |

### Extensions

| Extension | Operators | Description |
|-----------|-----------|-------------|
| **gn_ext_shadertoy** | ShadertoyTOP | Runtime Shadertoy GLSL translation — write, paste, or fetch any `mainImage` shader. Auto-mapped built-ins, URL fetch via Shadertoy API (requires free API key), 10 factory presets, inline code editor with syntax highlighting. |
| **gn_ext_isf** | ISFFileTOP | ISF v2 (Interactive Shader Format) support — auto-generated parameters and input ports from JSON `INPUTS` header, single-pass and multi-pass with persistent buffers, 10 factory presets, inline code editor. |
| **gn_ext_spout** | SpoutInTOP, SpoutOutTOP | Windows-only Spout2 texture sharing — send/receive GPU textures between GONODES and other apps (Resolume, OBS, TouchDesigner). |
| **gn_ext_syphon** | SyphonInTOP, SyphonOutTOP | macOS-only Syphon texture sharing — send/receive GPU textures via IOSurface (VDMX, MadMapper, CoGe). |
| **gn_ext_video_capture** | VideoDeviceInIMG | Cross-platform webcam/capture device input — Media Foundation (Windows), AVFoundation (macOS), V4L2 (Linux). |
| **gn_ext_midi** | MidiInCHOP, MidiOutCHOP | Cross-platform MIDI I/O via RtMidi — receive/send notes, CC, pitch bend to external controllers and DAWs. |
| **gn_ext_gpu_encode** | MovieFileOutTOP | Hardware-accelerated video encoding — Media Foundation (Windows), VideoToolbox (macOS). Record to H.264 MP4. |
| **gn_ext_mapper** | QuadMapTOP, BezierMapTOP, GridWarpTOP, EdgeBlendTOP, ProjectionMaskTOP, StonerTOP, ProjectorBlendTOP | Projection mapping toolkit — GPU perspective/bezier/grid warping, soft edge blending, masking for multi-projector setups. |

### Advanced Scripting

All Script operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG, GenericScriptNode, CallbackDAT) share a common runtime GDScript compilation engine with these features:

- **`set_par()`** — writable parameter references: modify params on self or any reachable node with auto dirty-propagation
- **Network API** — procedural graph construction: `network_add_node()`, `network_remove_node()`, `network_connect()`, `network_disconnect()`, `network_node_ids()`, `network_node_info()`
- **GenericScriptNode** — family-less multi-output node using `# @output chop/top/dat/sop/img/mat` annotations to create typed output ports dynamically
- **CallbackDAT** — event-driven scripting that observes an upstream node and fires callbacks on cook, parameter change, creation, or startup

### 3D Scene Pipeline

SOPs produce geometry → MATs define materials → COMPs compose the 3D scene → RenderTOP renders through an isolated SubViewport back into the TOP texture pipeline:

```
GridSOP → TransformSOP → GeometryCOMP (MeshInstance3D) ─┐
				   ↑           ↑                        │
			  PBR_MAT     CameraCOMP (Camera3D)       ├─→ RenderTOP → texture output
						  LightCOMP  (Light3D)        │
						  MergeCOMP  (Node3D group) ──┘
```

SOP generators use Godot's built-in mesh types (BoxMesh, SphereMesh, etc.) and SurfaceTool for procedural generation. NoiseSOP uses FastNoiseLite for vertex displacement. MAT operators wrap Godot's Material system (StandardMaterial3D, ShaderMaterial) for per-object material assignment. GeometryCOMP accepts SOP, MAT, and TOP inputs. MergeCOMP groups multiple COMPs for scene composition. Shadow controls span all three levels: per-light (LightCOMP), per-object (GeometryCOMP), and global quality (RenderTOP).

---

## GPU Architecture: Why SSBO & Texture3D (Not GPGPU)

GONODES uses Godot's `RenderingDevice` compute pipeline for two performance-critical families: **POP** (GPU particles) and **VOL** (3D volumetrics). The design is deliberate — we chose **SSBOs** for particles and **Texture3D** for volumes instead of the GPGPU (texture-as-data) pattern used by some older engines.

### POP — SSBO-Based GPU Particles

Particle state (position, velocity, age, life, color, scale) is stored in flat **Shader Storage Buffer Objects** (`RDStorageBuffer`), not packed into 2D textures.

**Why SSBOs over GPGPU textures:**

| | SSBO | GPGPU (texture-as-data) |
|---|---|---|
| **Data layout** | Flat struct array — natural for a 1D particle list | 2D grid — requires awkward `idx → (x, y)` mapping |
| **Struct flexibility** | Arbitrary per-particle fields in one buffer (64-byte stride) | Limited to RGBA channels per texel; multiple textures needed for extra attributes |
| **Size limits** | Buffer size limit only (typically 2 GB+) | Texture dimension cap: 16384×16384 ≈ 268M pixels, problematic for non-power-of-2 counts |
| **Godot fit** | `RenderingDevice` API is buffer-centric — SSBO creation is native and simple | 2D render targets require SubViewport hacks or manual texture management |
| **Read/write** | Read-write in one dispatch (double-buffered A→B swap) | Requires ping-pong render passes or image load/store |
| **CPU readback** | `buffer_get_data()` → `PackedFloat32Array` for downstream SOP/CHOP | `texture_get_data()` → Image → decode per-pixel — slower and more complex |

SSBOs also integrate cleanly with existing infrastructure: `GNGeoData.point_attribs` maps directly to/from buffer data for SOP↔POP bridging.

### VOL — Texture3D Compute Volumes

Volumetric data (density, velocity, pressure) is stored in **3D textures** (`RDTextureFormat` with `TEXTURE_TYPE_3D`), not SSBOs.

**Why Texture3D is the right choice for volumes:**

- **Hardware trilinear filtering** — `sampler3D` gives free interpolated reads, essential for fluid advection (semi-Lagrangian) and raymarching.
- **Natural 3D addressing** — voxel grids map directly to 3D texture coordinates. No index gymnastics.
- **Image load/store** — `layout(r32f) uniform image3D` for per-voxel compute writes, `uniform sampler3D` for filtered reads in the same pipeline.
- **Mip-maps** — automatic multi-resolution for LOD-aware rendering (future).
- **Raymarcher integration** — the volume can be directly sampled in a fragment shader for real-time rendering without any data conversion.

Where spatial filtering on particle data is needed (e.g., density splatting), a **scatter/gather bridge** converts between SSBO and Texture3D:

```
[SSBO particles] → scatter → [3D texture grid]
									↓
							  blur / advect / diffuse
									↓
[SSBO particles] ← gather ← [3D texture grid]
```

### Renderer Compatibility

Both POP and VOL families require **compute shaders**, available on Forward+ and Mobile renderers. The Compatibility renderer (OpenGL 3.3 / WebGL2) does not support compute.

| Renderer | API | Compute | POP & VOL |
|---|---|---|---|
| **Forward+** | Vulkan / D3D12 | ✅ | Full support |
| **Mobile** | Vulkan / Metal | ✅ | Full support |
| **Compatibility** | OpenGL 3.3 / WebGL2 | ❌ | Skipped with warning |

**Graceful degradation:** GONODES detects the active renderer at startup via `GNGpuContext.is_compute_available()`. When compute is unavailable, POP/VOL nodes are automatically skipped by the cook engine with a yellow ⚠ warning badge — the rest of the graph continues cooking normally. All other families (TOP, CHOP, SOP, DAT, MAT, COMP, IMG, UI, OUT) work on every renderer.

CPU fallback paths for POP and VOL are planned for a future release, enabling basic particle and volume workflows on Compatibility/WebGL2 at reduced performance.

---

## Node Help System

Every node has a **?** button in its title bar and a **Node Help** entry in the right-click context menu. Clicking either opens a floating help window with documentation for that operator.

### How Help Content Is Generated

Help content comes from two sources, checked in order:

1. **Custom `.md` file** — If a file exists at `addons/gonodes/help/<family>/<node_type>.md`, its contents are displayed first, followed by the auto-generated reference tables.
2. **Auto-generated from metadata** — When no custom file exists (the default), the help window builds everything automatically from the operator's code:
   - **Header** — Node name with family-colored badge
   - **Description** — From `node_description` (set in `_init()`)
   - **Inputs table** — Port name, family, description, multi-input flag
   - **Outputs table** — Port name, family, description
   - **Parameters table** — Name, type, default value, range, description
   - **Properties** — Time-dependent flag, family, node type

### Writing Good Operator Descriptions

The help system pulls directly from operator metadata. To produce useful auto-generated docs, **every operator should have**:

| Metadata | Where to set it | Example |
|----------|----------------|---------|
| `node_description` | `_init()` | `node_description = "Plays a video file (.ogv) as a texture stream."` |
| Port descriptions | `add_input()` / `add_output()` | `add_output("out", GNFamily.Type.TOP, "Video frame texture")` |
| Parameter descriptions | `GNParameter.create_*()` last arg | `GNParameter.create_float("speed", 1.0, 0.0, 4.0, 0.05, "", "Playback speed multiplier")` |

If a description is missing the help window shows "—" in its place. The more you fill in, the better the auto-generated docs become — **no separate documentation files needed**.

### Custom Help Files (`.md`)

For operators that need richer docs (usage tips, gotchas, visual diagrams, links), create a Markdown file:

```
addons/gonodes/help/<family>/<node_type>.md
```

Examples:
- `addons/gonodes/help/top/noise_top.md`
- `addons/gonodes/help/chop/lfo_chop.md`
- `addons/gonodes/help/dat/osc_in_dat.md`

The custom content appears above the auto-generated reference tables, so you don't need to repeat port/parameter info.

### Example Patches

Example patches are `.gnpatch` files that demonstrate how a node is used in practice. When examples exist for a node, the help window shows **"Open Example Patch"** buttons at the bottom. Clicking one opens the patch in a new floating editor window — your current work stays untouched.

#### Where to put them

```
addons/gonodes/help/<family>/<node_type>_<label>.gnpatch
```

#### Naming convention

The filename **must start with the `node_type`** followed by `_` and a descriptive label:

| Filename | Operator | Label shown in help |
|----------|----------|---------------------|
| `noise_top_example.gnpatch` | NoiseTOP | "Noise Top Example" |
| `noise_top_feedback.gnpatch` | NoiseTOP | "Noise Top Feedback" |
| `lfo_chop_basics.gnpatch` | LfoChop | "Lfo Chop Basics" |
| `composite_top_layers.gnpatch` | CompositeTOP | "Composite Top Layers" |

A single `.gnpatch` named exactly `<node_type>.gnpatch` (e.g. `noise_top.gnpatch`) also works.

Multiple examples per node are fully supported — each gets its own button.

#### How discovery works

When a help window opens, it scans `addons/gonodes/help/<family>/` for **all** `.gnpatch` files whose filename starts with the node's `node_type` prefix. No manifest file, no registration step — just drop a `.gnpatch` into the right folder and it's automatically discovered.

#### Folder structure

```
addons/gonodes/help/
├── top/
│   ├── noise_top.md                    # Custom help (optional)
│   ├── noise_top_example.gnpatch       # Example patch
│   ├── noise_top_feedback.gnpatch      # Another example
│   ├── composite_top_layers.gnpatch
│   └── ...
├── chop/
│   ├── lfo_chop_basics.gnpatch
│   └── ...
├── dat/
├── sop/
├── comp/
└── mat/
```

### Next Up (Phase 7: Creative Tools, Performance & Workflow)

**Script Operators:**
- [x] ScriptCHOP — user GDScript for custom channel processing
- [x] ScriptDAT — user GDScript for table/text processing
- [x] ScriptIMG — CPU-side pixel generation via GDScript (IMG family)
- [x] ScriptSOP — procedural geometry via GDScript

**IMG Family (CPU Image Processing):**
- [x] NoiseIMG — value/white noise generator
- [x] CheckerboardIMG — 2-color grid pattern
- [x] BlurIMG — separable box blur filter
- [x] EdgeDetectIMG — Sobel/Prewitt edge detection
- [x] PixelSortIMG — glitch art pixel sorting
- [x] ImgToTOP — CPU Image → GPU Texture bridge

**Media I/O:**
- [x] OSC input/output operators (OscInCHOP, OscOUT, OscInDAT)
- [x] MIDI input (MidiInCHOP, MidiInDAT with device selection)
- [x] Audio input (AudioInCHOP, AudioSpectrumCHOP, AudioFileInCHOP)
- [x] WebcamIMG — live camera feed via CameraServer
- [x] ImageSequenceIMG — numbered frame playback with alpha

**Performance:**
- [x] SubViewport UPDATE_ONCE for non-time-dependent TOPs
- [ ] Viewport pooling (reuse freed SubViewports by resolution)
- [x] Active chain cooking (skip disconnected subgraphs)
- [x] Lazy viewport creation (zero GPU footprint for unused TOPs)
- [x] GPU memory budget monitoring (VRAM tracking + warnings)
- [ ] Resolution downscaling for preview thumbnails

**Workflow:**
- [x] Node help system (? button + context menu, auto-generated docs, example patches)
- [x] Keyboard shortcut reference card (? key help overlay)
- [x] Node alignment tools (align H/V, distribute evenly)
- [x] Fit-to-view (F key)
- [x] Node bypass/disable toggle (B key)
- [x] Node lock toggle (L key)
- [x] Wire style options (curved/straight/right-angle)
- [x] Patch export to standalone apps (Quick Build)
- [x] Node grouping / sub-networks (Ctrl+G to group, Enter to dive, Backspace to exit)
- [x] Spare Parameters (Houdini-style add-any-param-to-any-node)
- [x] Minimap navigation
- [x] Node bookmarks (quick-jump 1-9)
- [x] Auto-layout (topological + layer assignment)
- [x] Parameter presets (save/load/copy between nodes)

### Planned (Post-Phase 7)

- CPU fallback for POP/VOL on Compatibility renderer (WebGL2, old GPUs)
- LibGodot embedding for host applications (VDMX, Resolume)
- FFmpeg GDExtension addon (`gn_ext_ffmpeg`) — H.264, VP9, AV1, ProRes
- HAP codec GDExtension (GPU-direct S3TC/DXT video for VJ workflows, alpha support)
- Syphon / Spout texture sharing
- NDI video streaming
- FxPlug / FFGL plugin export
- Multi-threaded cook engine
- GPU compute shaders for CHOPs
- Network collaboration (shared editing)
- Asset/patch marketplace
- Mobile/web export for patches


---

## Requirements

- **Godot 4.6** or later
- Desktop OS: Windows, macOS, or Linux

---

## Getting Started

> Coming soon — the project is currently in the architecture phase.

```bash
# Clone the repo
git clone https://github.com/your-username/gonodes.git

# Open in Godot 4.6
# File → Open Project → select the gonodes folder
```

---

## Architecture Overview

```
├─────────────────────────────────────────────┐
│  UI Layer                                   │
│  Node graph editor, Inspector, Viewer       │
├─────────────────────────────────────────────┤
│  Operator Library                           │
│  TOPs, CHOPs, SOPs, POPs, DATs, MATs, COMPs│
├─────────────────────────────────────────────┤
│  Cook Engine                                │
│  DAG traversal, dirty flags, lazy eval      │
├─────────────────────────────────────────────┤
│  Data Types & Parameter System              │
│  Textures, Channels, Geometry, Tables       │
│  Expressions, Bind, Export                  │
├─────────────────────────────────────────────┤
│  Godot 4.6 Engine                           │
│  Rendering, Audio, Compute, Physics, I/O    │
└─────────────────────────────────────────────┘
```

GONODES is built directly on Godot's native systems — SubViewports for texture processing, SSBO compute shaders for GPU particles, Texture3D compute for volumetrics, GraphEdit for the node editor, Resource serialization for patches. No abstraction layers, no engine-agnostic wrappers. This keeps the codebase lean and ensures patches export cleanly to every platform Godot targets. Compute-dependent operators (POP, VOL, ComputeShaderTOP) are automatically detected and gracefully skipped on renderers without compute support.

**Key design principles:**
- **Demand-driven flat-pass cooking** — achieves the same lazy evaluation as pull-based systems (Houdini, TouchDesigner) without recursive descent. Only dirty + active nodes cook each frame. Inactive subgraphs are skipped entirely via active-chain BFS from sinks. Single linear topo-sorted pass — no deep recursion, predictable timing, correct GPU render ordering.
- **Consolidate shared infrastructure in family base classes** — common members (`_viewport`, `_material`, `_cached_tex_data`, etc.) and lifecycle helpers live in `GNTopBase`, `GNChopBase`, `GNDatBase`, etc., not duplicated across operators.
- **Prefer Godot built-in classes** — `SubViewport`, `ShaderMaterial`, `ArrayMesh`, `RefCounted`, `Resource` — over custom abstractions.
- **Render only when needed** — SubViewports use `UPDATE_DISABLED` + `UPDATE_ONCE` per cook cycle, not `UPDATE_ALWAYS`.

For the full technical design document and coding guidelines, see [GONODES_CONTEXT.md](GONODES_CONTEXT.md).

---

## Project Structure

```
GONODES/
├── project.godot                    # Godot project file
├── README.md                        # This file
├── GONODES_CONTEXT.md               # Full architecture & design doc
├── addons/gonodes/
│   ├── core/                        # Framework core (21 classes)
│   │   ├── gn_node.gd              # Base operator (extends Node) — type-agnostic
│   │   ├── gn_top_base.gd          # GNTopBase — TOP family base class
│   │   ├── gn_chop_base.gd         # GNChopBase — CHOP family base class
│   │   ├── gn_dat_base.gd          # GNDatBase — DAT family base class
│   │   ├── gn_sop_base.gd          # GNSopBase — SOP family base class
│   │   ├── gn_comp_base.gd         # GNCompBase — COMP family base class
│   │   ├── gn_mat_base.gd          # GNMatBase — MAT family base class
│   │   ├── gn_ui_base.gd           # GNUiBase  UI family base class
│   │   ├── gn_cook_engine.gd       # Frame-driven cook engine
│   │   ├── gn_network.gd           # Graph model (Resource)
│   │   ├── gn_parameter.gd         # Typed parameters with expressions
│   │   ├── gn_extension_registry.gd # Dynamic operator registry + extension loader
│   │   ├── gn_data.gd              # Base output data (RefCounted)
│   │   ├── gn_texture_data.gd      # TOP output data
│   │   ├── gn_channel_data.gd      # CHOP output data
│   │   ├── gn_table_data.gd        # DAT output data (table + text modes)
│   │   ├── gn_geo_data.gd          # SOP output data (ArrayMesh wrapper)
│   │   ├── gn_material_data.gd     # MAT output data (Material wrapper)
│   │   ├── gn_port.gd              # Port definition
│   │   ├── gn_connection.gd        # Wire connection
│   │   ├── gn_family.gd            # OP family enum
│   │   └── gn_logger.gd            # Centralized logging
│   ├── operators/                   # Built-in operators organized by family
│   │   ├── top/                     # 26 TOPs: Noise, Level, Composite, Blur, Ramp, Circle, Rectangle, Constant, Text, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Cross, Displace, Lookup, Null, Switch, CustomShader, Window, Render
│   │   ├── chop/                    # 22 CHOPs: LFO, Noise, Math, Constant, Wave, Pattern, Timer, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Logic, Merge, Cross, Null, Switch, DATtoCHOP, Ramp
│   │   ├── dat/                     # 12 DATs: Constant, Text, Null, Select, Merge, Transpose, Sort, Evaluate, Switch, CHOPtoDAT, InfoDAT, OscIn
│   │   ├── sop/                     # 14 SOPs: Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch
│   │   ├── mat/                     # 2 MATs: PBR, Shader
│   │   ├── comp/                    # 4 COMPs: Geometry, Camera, Light, Merge
│   │   ├── output/                  # WindowOUT (multi-display)
│   │   └── ui/                      # 8 UIs: ButtonUI, SliderUI, ToggleUI, LabelUI, KnobUI, XYPadUI, DropdownUI, ContainerUI
│   ├── ui/                          # Editor UI
│   │   ├── gn_graph_editor.gd      # GraphEdit canvas (bidirectional sync)
│   │   ├── gn_node_view.gd         # GraphNode per operator (family colors)
│   │   ├── gn_node_palette.gd      # Popup node picker (Tab/right-click)
│   │   ├── gn_param_inspector.gd   # Parameter inspector panel
│   │   ├── gn_param_row.gd         # Per-parameter widget (type-specific)
│   │   └── gn_help_window.gd       # Floating help window (auto-docs + examples)
│   ├── help/                        # Node documentation & example patches
│   │   ├── top/                     # TOP help files & examples
│   │   ├── chop/                    # CHOP help files & examples
│   │   ├── dat/                     # DAT help files & examples
│   │   ├── sop/                     # SOP help files & examples
│   │   ├── comp/                    # COMP help files & examples
│   │   ├── mat/                     # MAT help files & examples
│   │   ├── output/                  # OUT help files & examples
│   │   └── ui/                      # UI help files & examples
│   └── shaders/                     # 17 shaders: noise_simplex, composite, levels, blur, ramp, circle, rectangle, transform2d, hsv_adjust, edge, threshold, displace, flip, tile, cross, crop, lookup, feedback
├── scenes/
│   ├── gn_editor.tscn               # Main editor scene (HSplit layout)
│   ├── gn_editor.gd                 # Editor wiring script
│   ├── player_main.tscn             # Standalone player scene
│   └── player_main.gd               # Player runtime script
└── tests/                           # Unit & integration tests (690 tests)
```

---

## Contributing

This project is in early development. If you're interested in contributing, start by reading [GONODES_CONTEXT.md](GONODES_CONTEXT.md) for the full architecture overview, then open an issue to discuss what you'd like to work on.

---

## License

TBD

---

## Acknowledgments

- [Derivative TouchDesigner](https://derivative.ca) — for pioneering the node-based real-time visual programming paradigm
- [Godot Engine](https://godotengine.org) — for being an incredible open-source foundation
- [VUO](https://vuo.org) — for proving that embeddable node-based compositions work in host apps
