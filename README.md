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
| **COMP** | Containers and sub-networks | Panel, 3D Scene |

### How It Works

1. **Drop nodes** onto the canvas from the palette.
2. **Wire them together.** Data flows left to right. Connections are type-safe — you can only connect compatible ports.
3. **Tweak parameters** in the inspector. Every parameter can be a constant value, a live expression, or bound to another node's output.
4. **See results instantly.** TOP outputs show live texture previews. The viewer panel shows full-resolution output.
5. **Export.** Package your patch as a standalone app for any platform.

### Parameter Referencing

Any parameter on any node can reference data from other nodes:

```
chop("lfo1", "out") * 10.0           # Drive a value with an LFO
op("noise1", "scale")                # Read another node's parameter
sin(time * 2.0) + 0.5                # Math expressions with time
```

You can also **bind** parameters directly (zero-overhead link) or use **CHOP export** to push one signal to many parameters at once.

---

## Project Status

**Phase 6 In Progress — DAT, SOP, and COMP families implemented. 3D scene pipeline (SOP→COMP→RenderTOP) live. ~75 operators across 5 families. Phases 1–5 complete.**

### Completed

- **Phase 1: Core Framework** — GNNode, GNNetwork, GNCookEngine, GNParameter, GNData, GNPort, GNConnection, GNFamily (11 core classes)
- **Phase 2: First Operators** — NoiseTOP, LevelTOP, CompositeTOP, LFO_CHOP, NoiseCHOP, MathCHOP, WindowTOP (7 operators + 3 shaders + test scene)
- **Phase 3: Node Graph UI** — GNGraphEditor (GraphEdit canvas), GNNodeView (family-colored GraphNodes), GNNodePalette (Tab to open, search + family grouping), bidirectional network sync, editor scene with HSplit layout
- **Phase 4: Parameters & Inspector** — GNParamInspector (live parameter panel), GNParamRow (type-specific controls: sliders, spinboxes, color pickers, enums, checkboxes), expression inline editor with mode toggle (C/E), live cook time display, NoiseTOP 4-algorithm shader
- **Phase 5: Operator Expansion** — 20 new TOPs + 17 new CHOPs + 14 new GPU shaders + CustomShaderTOP. Total at end of phase: 46 operators (26 TOPs + 20 CHOPs).
- **Phase 5.5: DAT, SOP, COMP & 3D Pipeline** — 12 DAT operators + 14 SOP operators + 3 COMP operators + RenderTOP. GNTableData and GNGeoData data types. Full 3D scene rendering pipeline using Godot's native scene graph. Total: ~75 operators across 5 families.
- **Architecture: Node/RefCounted migration** — GNNode extends Node (scene tree), GNData extends RefCounted (lightweight)
- **Multi-window output** — WindowTOP creates OS windows for VJ output on any connected display (zero-copy GPU texture routing)
- **Logging system** — GNLogger with level filtering, per-category muting, and runtime toggle button
- **Expression system** — `chop("lfo1", "out") * 5.0` drives parameters across node families in real time
- **Cook engine optimization** — Cached adjacency maps, upfront dirty propagation, zero-alloc input gathering, multi-input port support

### Known Bugs

- **WindowTOP ESC key:** Cannot ESC out of Fullscreen/Borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector panel.

### Operator Library

| Family | Count | Operators |
|--------|-------|-----------|
| **TOP** | 26 | Noise, Composite, Level, Blur, Ramp, Circle, Rectangle, Constant, Text, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Cross, Displace, Lookup, Null, Switch, CustomShader, Window, Render |
| **CHOP** | 21 | LFO, Noise, Math, Constant, Wave, Pattern, Timer, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Logic, Merge, Cross, Null, Switch, DATtoCHOP |
| **DAT** | 12 | Constant, Text, Null, Select, Merge, Transpose, Sort, Evaluate, Switch, CHOPtoDAT, InfoDAT, OscIn (stub) |
| **SOP** | 14 | Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch |
| **COMP** | 3 | Geometry, Camera, Light |

### 3D Scene Pipeline

SOPs produce geometry → COMPs wrap Godot's native 3D nodes → RenderTOP renders through an isolated SubViewport back into the TOP texture pipeline:

```
GridSOP → TransformSOP → GeometryCOMP (MeshInstance3D) ─┐
                         CameraCOMP   (Camera3D)        ├─→ RenderTOP → texture output
                         LightCOMP    (Light3D)         ─┘
```

SOP generators use Godot's built-in mesh types (BoxMesh, SphereMesh, etc.) and SurfaceTool for procedural generation. NoiseSOP uses FastNoiseLite for vertex displacement.

### Next Up (Phase 6)

- ScriptCHOP (user GDScript for custom channel processing)
- Code editor UI (CodeEdit-based multi-line editing in inspector)
- Node copy/paste
- Undo/redo
- Mini preview thumbnails on TOP nodes
- Right-click context menu on graph canvas
- Save/load patches (.tres resources)

### Planned (Post-MVP)

- POP, MAT families
- GPU particle system (millions of points via compute shaders)
- Renderer switching (Forward+, Mobile, Compatibility) for target platform preview
- Patch export as standalone apps (desktop, mobile, web)
- LibGodot embedding for host applications (VDMX, Resolume)
- Syphon / Spout texture sharing
- OSC, MIDI, NDI input/output
- Scriptable operators: ScriptCHOP, ScriptDAT, ScriptTOP, ScriptSOP, ComputeShaderTOP
- Sub-networks (COMPs) with hierarchical paths

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
┌─────────────────────────────────────────────┐
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

GONODES is built directly on Godot's native systems — SubViewports for texture processing, compute shaders for GPU particle work, GraphEdit for the node editor, Resource serialization for patches. No abstraction layers, no engine-agnostic wrappers. This keeps the codebase lean and ensures patches export cleanly to every platform Godot targets.

For the full technical design document, see [GONODES_CONTEXT.md](GONODES_CONTEXT.md).

---

## Project Structure

```
GONODES/
├── project.godot                    # Godot project file
├── README.md                        # This file
├── GONODES_CONTEXT.md               # Full architecture & design doc
├── addons/gonodes/
│   ├── core/                        # Framework core (13 classes)
│   │   ├── gn_node.gd              # Base operator (extends Node)
│   │   ├── gn_cook_engine.gd       # Frame-driven cook engine
│   │   ├── gn_network.gd           # Graph model (Resource)
│   │   ├── gn_parameter.gd         # Typed parameters with expressions
│   │   ├── gn_data.gd              # Base output data (RefCounted)
│   │   ├── gn_texture_data.gd      # TOP output data
│   │   ├── gn_channel_data.gd      # CHOP output data
│   │   ├── gn_table_data.gd        # DAT output data (table + text modes)
│   │   ├── gn_geo_data.gd          # SOP output data (ArrayMesh wrapper)
│   │   ├── gn_port.gd              # Port definition
│   │   ├── gn_connection.gd        # Wire connection
│   │   ├── gn_family.gd            # OP family enum
│   │   └── gn_logger.gd            # Centralized logging
│   ├── operators/                   # Built-in operators organized by family
│   │   ├── top/                     # 26 TOPs: Noise, Level, Composite, Blur, Ramp, Circle, Rectangle, Constant, Text, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Cross, Displace, Lookup, Null, Switch, CustomShader, Window, Render
│   │   ├── chop/                    # 21 CHOPs: LFO, Noise, Math, Constant, Wave, Pattern, Timer, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Logic, Merge, Cross, Null, Switch, DATtoCHOP
│   │   ├── dat/                     # 12 DATs: Constant, Text, Null, Select, Merge, Transpose, Sort, Evaluate, Switch, CHOPtoDAT, InfoDAT, OscIn
│   │   ├── sop/                     # 14 SOPs: Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch
│   │   ├── comp/                    # 3 COMPs: Geometry, Camera, Light
│   │   └── output/                  # WindowTOP (multi-display)
│   ├── ui/                          # Editor UI
│   │   ├── gn_graph_editor.gd      # GraphEdit canvas (bidirectional sync)
│   │   ├── gn_node_view.gd         # GraphNode per operator (family colors)
│   │   ├── gn_node_palette.gd      # Popup node picker (Tab/right-click)
│   │   ├── gn_param_inspector.gd   # Parameter inspector panel
│   │   └── gn_param_row.gd         # Per-parameter widget (type-specific)
│   └── shaders/                     # 17 shaders: noise_simplex, composite, levels, blur, ramp, circle, rectangle, transform2d, hsv_adjust, edge, threshold, displace, flip, tile, cross, crop, lookup, feedback
├── scenes/
│   ├── gn_editor.tscn               # Main editor scene (HSplit layout)
│   ├── gn_editor.gd                 # Editor wiring script
│   ├── test_phase2.tscn             # Phase 2 test scene (legacy)
│   └── test_phase2.gd               # Phase 2 test script
└── tests/                           # Unit tests (future)
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
