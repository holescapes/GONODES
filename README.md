# GONODES

**A real-time node-based visual programming framework built on [Godot 4.6](https://godotengine.org), inspired by [TouchDesigner](https://derivative.ca).**

GONODES brings the creative power of node-based visual programming to the Godot ecosystem â€” wire together operators, tweak parameters in real time, and export your patches as standalone apps on any platform Godot supports.

---

## What Is This?

If you've used TouchDesigner, Max/MSP, vvvv, or VUO, you know the workflow: connect nodes together, data flows through wires, visuals appear in real time. GONODES brings that to Godot.

You build **patches** â€” networks of connected operators that process textures, signals, geometry, and data in real time. An LFO drives a noise texture. A CHOP channel modulates brightness. A particle system reacts to audio. You see everything update live as you wire things together.

### Why Godot?

- **Cross-platform for free.** Export your patches as standalone apps on Windows, macOS, Linux, Android, iOS, and Web.
- **GPU-powered.** Vulkan and OpenGL rendering, compute shaders, GPU particles â€” all built in.
- **LibGodot.** Starting with Godot 4.6, the engine can be embedded as a library in other applications. This means GONODES patches can run inside VJ tools like VDMX or Resolume.
- **Open source.** No licensing fees, no black boxes.

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
2. **Wire them together.** Data flows left to right. Connections are type-safe â€” you can only connect compatible ports.
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

---

## Project Status

**Phase 6 Complete â€" Phase 7 planned. Save/load, copy/paste, undo/redo, live node previews with per-node toggle, family base classes, right-click context menu, performance profiling overlay, stress test (59 nodes). GNExtensionRegistry. MAT family (PBR, Shader) with per-object materials. MergeCOMP scene composition. Shadow system. WindowOUT open/close toggle. 3D pipeline live. 288 operators across 10 families. RAMP parameter type with curve editor. RampCHOP (dynamic 1â€"16 ramp slots). Canvas annotations (network boxes, sticky notes). Advanced scripting: GenericScriptNode (multi-output), CallbackDAT (event-driven), set_par() writable refs, Network API (procedural graph construction). 176 tests passing. Phases 1â€"6 complete.**

### Completed

- **Phase 1: Core Framework** â€” GNNode, GNNetwork, GNCookEngine, GNParameter, GNData, GNPort, GNConnection, GNFamily (11 core classes)
- **Phase 2: First Operators** â€” NoiseTOP, LevelTOP, CompositeTOP, LFO_CHOP, NoiseCHOP, MathCHOP, WindowOUT (7 operators + 3 shaders + test scene)
- **Phase 3: Node Graph UI** â€” GNGraphEditor (GraphEdit canvas), GNNodeView (family-colored GraphNodes), GNNodePalette (Tab to open, search + family grouping), bidirectional network sync, editor scene with HSplit layout
- **Phase 4: Parameters & Inspector** â€” GNParamInspector (live parameter panel), GNParamRow (type-specific controls: sliders, spinboxes, color pickers, enums, checkboxes), expression inline editor with mode toggle (C/E), live cook time display, NoiseTOP 4-algorithm shader
- **Phase 5: Operator Expansion** â€” 20 new TOPs + 17 new CHOPs + 14 new GPU shaders + CustomShaderTOP. Total at end of phase: 46 operators (26 TOPs + 20 CHOPs).
- **Phase 5.5: DAT, SOP, COMP & 3D Pipeline** â€” 12 DAT operators + 14 SOP operators + 3 COMP operators + RenderTOP. GNTableData and GNGeoData data types. Full 3D scene rendering pipeline using Godot's native scene graph. Total: ~75 operators across 5 families.
- **Phase 5.6: UI Polish & Node Renaming** â€” Canvas anchoring fix (all 21 TOPs use `set_anchors_and_offsets_preset`), viewer panel sizing fix (`expand_mode = IGNORE_SIZE`, `clip_contents`), inline node renaming (double-click title bar with full ID update chain), inspector refresh on rename.
- **Phase 5.7: File Parameters & Media Input** â€” FILE parameter type with project file picker (FileDialog). TextTOP font selection (TTF/OTF/WOFF). ImageFileInTOP (PNG, JPG, WebP, HDR, EXR, SVG). MovieFileInTOP (Godot VideoStreamPlayer, .ogv Theora).
- **Phase 5.8: Extension Registry Architecture** â€” GNExtensionRegistry singleton replaces static match-factory and description dictionary. Dynamic operator registration API. Extension scanning (`gn_ext_*` addon manifests with `gn_extension.cfg`). ClassDB dependency guards for GDExtension addons. FFmpeg extension as future reference implementation.
- **Phase 6: Integration & Stabilization** â€” Save/load patches (`.gnpatch` JSON), copy/paste with ID remapping, undo/redo (Godot UndoRedo), live node previews (per-family: texture, channels, tables, mesh stats), per-node preview toggle (right-click on/off), global preview master switch, performance profiling overlay (per-node cook time badges), right-click context menu, MAT family (PBR_MAT + Shader_MAT), MergeCOMP, shadow system (per-light/per-object/global), multiple floating viewer windows, WindowOUT open/close toggle, stress test (59 nodes, auto-report), bug fixes.
- **Architecture: Node/RefCounted migration** â€” GNNode extends Node (scene tree), GNData extends RefCounted (lightweight)
- **Multi-window output** â€” WindowOUT creates OS windows for VJ output on any connected display (zero-copy GPU texture routing)
- **Logging system** â€” GNLogger with level filtering, per-category muting, and runtime toggle button
- **Expression system** â€” `chop("lfo1", "out") * 5.0` drives parameters across node families in real time
- **Cook engine optimization** â€” Cached adjacency maps, upfront dirty propagation, zero-alloc input gathering, multi-input port support

### Known Bugs

- **WindowOUT ESC key:** Cannot ESC out of Fullscreen/Borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector panel.

### Operator Library

| Family | Count | Highlights |
|--------|-------|-----------|
| **TOP** | 63 | Noise, Composite, Level, Blur, Ramp, Text, ImageFileIn, MovieFileIn, FFmpegIn, Transform, CustomShader, Render, Feedback, Displace, ChromaKey, AnalyzeTOP, TimeMachine, Panel, and more |
| **IMG** | 12 | NoiseIMG, CheckerboardIMG, BlurIMG, EdgeDetectIMG, PixelSortIMG, ImgToTOP, TOPtoIMG, WebcamIMG, ImageFileInIMG, ImageSequenceIMG, ScreenGrabIMG, ScriptIMG |
| **CHOP** | 61 | LFO, Noise, Math, Constant, Wave, Filter, Lag, Timer, Trigger, Speed, Smooth, Spring, Delay, Envelope, Ramp, Expression, Keyboard/Mouse/Gamepad input, and more |
| **DAT** | 29 | Constant, Text, JSONDAT, WebDAT, FileInDAT, ScriptDAT, **CallbackDAT**, OPFindDAT, Evaluate, CHOPtoDAT, SOPtoDAT, TOPtoDAT, and more |
| **SOP** | 57 | Grid, Box, Sphere, Torus, Transform, Noise, Subdivide, Boolean, Extrude, Sweep, Skin, Bend, Twist, Font, ScriptSOP, and more |
| **COMP** | 20 | Geometry, Camera, Light, Merge, RigidBody, StaticBody, SoftBody, Area, Joint, Environment, Null, Switch, **GenericScriptNode**, Instance, Replicator, Animation, SubNetwork, InTunnel, OutTunnel, Engines |
| **MAT** | 6 | PBR, Shader, Constant, Wireframe, PointSprite, Depth |
| **OUT** | 9 | WindowOUT, TextureSaveOUT, ImageSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, AudioDeviceOUT, RecordOUT, OscOUT |
| **UI** | 8 | ButtonUI, SliderUI, ToggleUI, LabelUI, KnobUI, XYPadUI, DropdownUI, ContainerUI |

### Advanced Scripting

All Script operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG, GenericScriptNode, CallbackDAT) share a common runtime GDScript compilation engine with these features:

- **`set_par()`** â€” writable parameter references: modify params on self or any reachable node with auto dirty-propagation
- **Network API** â€” procedural graph construction: `network_add_node()`, `network_remove_node()`, `network_connect()`, `network_disconnect()`, `network_node_ids()`, `network_node_info()`
- **GenericScriptNode** â€” family-less multi-output node using `# @output chop/top/dat/sop/img/mat` annotations to create typed output ports dynamically
- **CallbackDAT** â€” event-driven scripting that observes an upstream node and fires callbacks on cook, parameter change, creation, or startup

### 3D Scene Pipeline

SOPs produce geometry â†’ MATs define materials â†’ COMPs compose the 3D scene â†’ RenderTOP renders through an isolated SubViewport back into the TOP texture pipeline:

```
GridSOP â†’ TransformSOP â†’ GeometryCOMP (MeshInstance3D) â”€â”
                   â†‘           â†‘                        â”‚
              PBR_MAT     CameraCOMP (Camera3D)       â”œâ”€â†’ RenderTOP â†’ texture output
                          LightCOMP  (Light3D)        â”‚
                          MergeCOMP  (Node3D group) â”€â”€â”˜
```

SOP generators use Godot's built-in mesh types (BoxMesh, SphereMesh, etc.) and SurfaceTool for procedural generation. NoiseSOP uses FastNoiseLite for vertex displacement. MAT operators wrap Godot's Material system (StandardMaterial3D, ShaderMaterial) for per-object material assignment. GeometryCOMP accepts SOP, MAT, and TOP inputs. MergeCOMP groups multiple COMPs for scene composition. Shadow controls span all three levels: per-light (LightCOMP), per-object (GeometryCOMP), and global quality (RenderTOP).

---

## Node Help System

Every node has a **?** button in its title bar and a **Node Help** entry in the right-click context menu. Clicking either opens a floating help window with documentation for that operator.

### How Help Content Is Generated

Help content comes from two sources, checked in order:

1. **Custom `.md` file** â€” If a file exists at `addons/gonodes/help/<family>/<node_type>.md`, its contents are displayed first, followed by the auto-generated reference tables.
2. **Auto-generated from metadata** â€” When no custom file exists (the default), the help window builds everything automatically from the operator's code:
   - **Header** â€” Node name with family-colored badge
   - **Description** â€” From `node_description` (set in `_init()`)
   - **Inputs table** â€” Port name, family, description, multi-input flag
   - **Outputs table** â€” Port name, family, description
   - **Parameters table** â€” Name, type, default value, range, description
   - **Properties** â€” Time-dependent flag, family, node type

### Writing Good Operator Descriptions

The help system pulls directly from operator metadata. To produce useful auto-generated docs, **every operator should have**:

| Metadata | Where to set it | Example |
|----------|----------------|---------|
| `node_description` | `_init()` | `node_description = "Plays a video file (.ogv) as a texture stream."` |
| Port descriptions | `add_input()` / `add_output()` | `add_output("out", GNFamily.Type.TOP, "Video frame texture")` |
| Parameter descriptions | `GNParameter.create_*()` last arg | `GNParameter.create_float("speed", 1.0, 0.0, 4.0, 0.05, "", "Playback speed multiplier")` |

If a description is missing the help window shows "â€”" in its place. The more you fill in, the better the auto-generated docs become â€” **no separate documentation files needed**.

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

Example patches are `.gnpatch` files that demonstrate how a node is used in practice. When examples exist for a node, the help window shows **"Open Example Patch"** buttons at the bottom. Clicking one opens the patch in a new floating editor window â€” your current work stays untouched.

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

Multiple examples per node are fully supported â€” each gets its own button.

#### How discovery works

When a help window opens, it scans `addons/gonodes/help/<family>/` for **all** `.gnpatch` files whose filename starts with the node's `node_type` prefix. No manifest file, no registration step â€” just drop a `.gnpatch` into the right folder and it's automatically discovered.

#### Folder structure

```
addons/gonodes/help/
â”œâ”€â”€ top/
â”‚   â”œâ”€â”€ noise_top.md                    # Custom help (optional)
â”‚   â”œâ”€â”€ noise_top_example.gnpatch       # Example patch
â”‚   â”œâ”€â”€ noise_top_feedback.gnpatch      # Another example
â”‚   â”œâ”€â”€ composite_top_layers.gnpatch
â”‚   â””â”€â”€ ...
â”œâ”€â”€ chop/
â”‚   â”œâ”€â”€ lfo_chop_basics.gnpatch
â”‚   â””â”€â”€ ...
â”œâ”€â”€ dat/
â”œâ”€â”€ sop/
â”œâ”€â”€ comp/
â””â”€â”€ mat/
```

### Next Up (Phase 7: Creative Tools, Performance & Workflow)

**Script Operators:**
- [x] ScriptCHOP â€” user GDScript for custom channel processing
- [x] ScriptDAT â€” user GDScript for table/text processing
- [x] ScriptIMG â€” CPU-side pixel generation via GDScript (IMG family)
- [x] ScriptSOP â€” procedural geometry via GDScript

**IMG Family (CPU Image Processing):**
- [x] NoiseIMG â€” value/white noise generator
- [x] CheckerboardIMG â€” 2-color grid pattern
- [x] BlurIMG â€” separable box blur filter
- [x] EdgeDetectIMG â€” Sobel/Prewitt edge detection
- [x] PixelSortIMG â€” glitch art pixel sorting
- [x] ImgToTOP â€” CPU Image â†’ GPU Texture bridge

**Media I/O:**
- [ ] OSC input/output operators (OscInCHOP, OscOUT, complete OscInDAT stub)
- [ ] MIDI input (MidiInCHOP, MidiInDAT with device selection)
- [ ] Audio input (AudioInCHOP, AudioSpectrumCHOP, AudioFileInCHOP)
- [ ] WebcamTOP â€” live camera feed via CameraServer
- [ ] ImageSequenceTOP â€” numbered frame playback with alpha

**Performance:**
- [x] SubViewport UPDATE_ONCE for non-time-dependent TOPs
- [ ] Viewport pooling (reuse freed SubViewports by resolution)
- [ ] Active chain cooking (skip disconnected subgraphs)
- [x] Lazy viewport creation (zero GPU footprint for unused TOPs)
- [ ] GPU memory budget monitoring (VRAM tracking + warnings)
- [ ] Resolution downscaling for preview thumbnails

**Workflow:**
- [x] Node help system (? button + context menu, auto-generated docs, example patches)
- [ ] Keyboard shortcut reference card (? key help overlay)
- [ ] Node alignment tools (align H/V, distribute evenly)
- [ ] Fit-to-view (F key)
- [ ] Node bypass/disable toggle (B key)
- [ ] Node lock toggle (L key)
- [ ] Wire style options (curved/straight/right-angle)
- [ ] Renderer selection UI (Forward+/Mobile/Compatibility dropdown)
- [ ] Patch export to standalone apps (desktop/web via Godot export templates)
- [ ] Node grouping / sub-networks (collapse â†’ dive â†’ breadcrumbs)
- [ ] Spare Parameters (Houdini-style add-any-param-to-any-node)
- [ ] Minimap navigation
- [ ] Node bookmarks (quick-jump 1-9)
- [ ] Auto-layout (topological + layer assignment)
- [ ] Parameter presets (save/load/copy between nodes)

### Planned (Post-Phase 7)

- POP family (GPU particle system â€” millions of points via compute shaders)
- LibGodot embedding for host applications (VDMX, Resolume)
- FFmpeg GDExtension addon (`gn_ext_ffmpeg`) â€” H.264, VP9, AV1, ProRes
- HAP codec GDExtension (GPU-direct S3TC/DXT video for VJ workflows, alpha support)
- Syphon / Spout texture sharing
- NDI video streaming
- FxPlug / FFGL plugin export
- ComputeShaderTOP (user-editable GPU compute shader)
- Multi-threaded cook engine
- GPU compute shaders for CHOPs
- Python scripting DAT (embedded Python via GDExtension)
- Network collaboration (shared editing)
- Asset/patch marketplace
- Mobile/web export for patches

### Deferred Operators (known algorithms, need research/complexity)

- **ScreenGrabTOP** â€” capture viewport contents as texture (viewport-only, no OS-level grab)
- **InstanceCOMP** â€” MultiMeshInstance3D-based instancing for massive geometry duplication
- **AnimationCOMP** â€” AnimationPlayer wrapper for keyframe animation on COMP properties
- **SpringSOP** â€” mass-spring soft body deformer (CPU vertex simulation)
- **ParticleSOP** â€” CPU particle system emitting from SOP surface points
- **AudioDeviceOUT** â€” output CHOP channels as audio via AudioStreamGenerator

---

## Requirements

- **Godot 4.6** or later
- Desktop OS: Windows, macOS, or Linux

---

## Getting Started

> Coming soon â€” the project is currently in the architecture phase.

```bash
# Clone the repo
git clone https://github.com/your-username/gonodes.git

# Open in Godot 4.6
# File â†’ Open Project â†’ select the gonodes folder
```

---

## Architecture Overview

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  UI Layer                                   â”‚
â”‚  Node graph editor, Inspector, Viewer       â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚  Operator Library                           â”‚
â”‚  TOPs, CHOPs, SOPs, POPs, DATs, MATs, COMPsâ”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚  Cook Engine                                â”‚
â”‚  DAG traversal, dirty flags, lazy eval      â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚  Data Types & Parameter System              â”‚
â”‚  Textures, Channels, Geometry, Tables       â”‚
â”‚  Expressions, Bind, Export                  â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚  Godot 4.6 Engine                           â”‚
â”‚  Rendering, Audio, Compute, Physics, I/O    â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

GONODES is built directly on Godot's native systems â€” SubViewports for texture processing, compute shaders for GPU particle work, GraphEdit for the node editor, Resource serialization for patches. No abstraction layers, no engine-agnostic wrappers. This keeps the codebase lean and ensures patches export cleanly to every platform Godot targets.

**Key design principles:**
- **Demand-driven flat-pass cooking** â€” achieves the same lazy evaluation as pull-based systems (Houdini, TouchDesigner) without recursive descent. Only dirty + active nodes cook each frame. Inactive subgraphs are skipped entirely via active-chain BFS from sinks. Single linear topo-sorted pass â€” no deep recursion, predictable timing, correct GPU render ordering.
- **Consolidate shared infrastructure in family base classes** â€” common members (`_viewport`, `_material`, `_cached_tex_data`, etc.) and lifecycle helpers live in `GNTopBase`, `GNChopBase`, `GNDatBase`, etc., not duplicated across operators.
- **Prefer Godot built-in classes** â€” `SubViewport`, `ShaderMaterial`, `ArrayMesh`, `RefCounted`, `Resource` â€” over custom abstractions.
- **Render only when needed** â€” SubViewports use `UPDATE_DISABLED` + `UPDATE_ONCE` per cook cycle, not `UPDATE_ALWAYS`.

For the full technical design document and coding guidelines, see [GONODES_CONTEXT.md](GONODES_CONTEXT.md).

---

## Project Structure

```
GONODES/
â”œâ”€â”€ project.godot                    # Godot project file
â”œâ”€â”€ README.md                        # This file
â”œâ”€â”€ GONODES_CONTEXT.md               # Full architecture & design doc
â”œâ”€â”€ addons/gonodes/
â”‚   â”œâ”€â”€ core/                        # Framework core (21 classes)
â”‚   â”‚   â”œâ”€â”€ gn_node.gd              # Base operator (extends Node) â€” type-agnostic
â”‚   â”‚   â”œâ”€â”€ gn_top_base.gd          # GNTopBase â€” TOP family base class
â”‚   â”‚   â”œâ”€â”€ gn_chop_base.gd         # GNChopBase â€” CHOP family base class
â”‚   â”‚   â”œâ”€â”€ gn_dat_base.gd          # GNDatBase â€” DAT family base class
â”‚   â”‚   â”œâ”€â”€ gn_sop_base.gd          # GNSopBase â€” SOP family base class
â”‚   â”‚   â”œâ”€â”€ gn_comp_base.gd         # GNCompBase â€” COMP family base class
â”‚   â”‚   â”œâ”€â”€ gn_mat_base.gd          # GNMatBase â€” MAT family base class
â”‚   â”‚   â”œâ”€â”€ gn_ui_base.gd           # GNUiBase  UI family base class
â”‚   â”‚   â”œâ”€â”€ gn_panel_source.gd      # GNPanelSource  panel input forwarding metadata
â”‚   â”‚   â”œâ”€â”€ gn_cook_engine.gd       # Frame-driven cook engine
â”‚   â”‚   â”œâ”€â”€ gn_network.gd           # Graph model (Resource)
â”‚   â”‚   â”œâ”€â”€ gn_parameter.gd         # Typed parameters with expressions
â”‚   â”‚   â”œâ”€â”€ gn_extension_registry.gd # Dynamic operator registry + extension loader
â”‚   â”‚   â”œâ”€â”€ gn_data.gd              # Base output data (RefCounted)
â”‚   â”‚   â”œâ”€â”€ gn_texture_data.gd      # TOP output data
â”‚   â”‚   â”œâ”€â”€ gn_channel_data.gd      # CHOP output data
â”‚   â”‚   â”œâ”€â”€ gn_table_data.gd        # DAT output data (table + text modes)
â”‚   â”‚   â”œâ”€â”€ gn_geo_data.gd          # SOP output data (ArrayMesh wrapper)
â”‚   â”‚   â”œâ”€â”€ gn_material_data.gd     # MAT output data (Material wrapper)
â”‚   â”‚   â”œâ”€â”€ gn_port.gd              # Port definition
â”‚   â”‚   â”œâ”€â”€ gn_connection.gd        # Wire connection
â”‚   â”‚   â”œâ”€â”€ gn_family.gd            # OP family enum
â”‚   â”‚   â””â”€â”€ gn_logger.gd            # Centralized logging
â”‚   â”œâ”€â”€ operators/                   # Built-in operators organized by family
â”‚   â”‚   â”œâ”€â”€ top/                     # 26 TOPs: Noise, Level, Composite, Blur, Ramp, Circle, Rectangle, Constant, Text, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Cross, Displace, Lookup, Null, Switch, CustomShader, Window, Render
â”‚   â”‚   â”œâ”€â”€ chop/                    # 22 CHOPs: LFO, Noise, Math, Constant, Wave, Pattern, Timer, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Logic, Merge, Cross, Null, Switch, DATtoCHOP, Ramp
â”‚   â”‚   â”œâ”€â”€ dat/                     # 12 DATs: Constant, Text, Null, Select, Merge, Transpose, Sort, Evaluate, Switch, CHOPtoDAT, InfoDAT, OscIn
â”‚   â”‚   â”œâ”€â”€ sop/                     # 14 SOPs: Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch
â”‚   â”‚   â”œâ”€â”€ mat/                     # 2 MATs: PBR, Shader
â”‚   â”‚   â”œâ”€â”€ comp/                    # 4 COMPs: Geometry, Camera, Light, Merge
â”‚   â”‚   â”œâ”€â”€ output/                  # WindowOUT (multi-display)
â”‚   â”‚   â””â”€â”€ ui/                      # 8 UIs: ButtonUI, SliderUI, ToggleUI, LabelUI, KnobUI, XYPadUI, DropdownUI, ContainerUI
â”‚   â”œâ”€â”€ ui/                          # Editor UI
â”‚   â”‚   â”œâ”€â”€ gn_graph_editor.gd      # GraphEdit canvas (bidirectional sync)
â”‚   â”‚   â”œâ”€â”€ gn_node_view.gd         # GraphNode per operator (family colors)
â”‚   â”‚   â”œâ”€â”€ gn_node_palette.gd      # Popup node picker (Tab/right-click)
â”‚   â”‚   â”œâ”€â”€ gn_param_inspector.gd   # Parameter inspector panel
â”‚   â”‚   â”œâ”€â”€ gn_param_row.gd         # Per-parameter widget (type-specific)
â”‚   â”‚   â””â”€â”€ gn_help_window.gd       # Floating help window (auto-docs + examples)
â”‚   â”œâ”€â”€ help/                        # Node documentation & example patches
â”‚   â”‚   â”œâ”€â”€ top/                     # TOP help files & examples
â”‚   â”‚   â”œâ”€â”€ chop/                    # CHOP help files & examples
â”‚   â”‚   â”œâ”€â”€ dat/                     # DAT help files & examples
â”‚   â”‚   â”œâ”€â”€ sop/                     # SOP help files & examples
â”‚   â”‚   â”œâ”€â”€ comp/                    # COMP help files & examples
â”‚   â”‚   â”œâ”€â”€ mat/                     # MAT help files & examples
â”‚   â”‚   â”œâ”€â”€ output/                  # OUT help files & examples
â”‚   â”‚   â””â”€â”€ ui/                      # UI help files & examples
â”‚   â””â”€â”€ shaders/                     # 17 shaders: noise_simplex, composite, levels, blur, ramp, circle, rectangle, transform2d, hsv_adjust, edge, threshold, displace, flip, tile, cross, crop, lookup, feedback
â”œâ”€â”€ scenes/
â”‚   â”œâ”€â”€ gn_editor.tscn               # Main editor scene (HSplit layout)
â”‚   â”œâ”€â”€ gn_editor.gd                 # Editor wiring script
â”‚   â”œâ”€â”€ test_phase2.tscn             # Phase 2 test scene (legacy)
â”‚   â””â”€â”€ test_phase2.gd               # Phase 2 test script
â””â”€â”€ tests/                           # Unit & integration tests (176 tests)
```

---

## Contributing

This project is in early development. If you're interested in contributing, start by reading [GONODES_CONTEXT.md](GONODES_CONTEXT.md) for the full architecture overview, then open an issue to discuss what you'd like to work on.

---

## License

TBD

---

## Acknowledgments

- [Derivative TouchDesigner](https://derivative.ca) â€” for pioneering the node-based real-time visual programming paradigm
- [Godot Engine](https://godotengine.org) â€” for being an incredible open-source foundation
- [VUO](https://vuo.org) â€” for proving that embeddable node-based compositions work in host apps
