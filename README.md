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
chop("lfo1").value("out") * 10.0     # Drive a value with an LFO
op("noise1").par.scale                # Read another node's parameter
sin(time * 2.0) + 0.5                # Math expressions with time
```

You can also **bind** parameters directly (zero-overhead link) or use **CHOP export** to push one signal to many parameters at once.

---

## Project Status

**Pre-implementation.** Architecture and planning are complete. Implementation is starting.

### MVP Target (4–6 weeks)

- Node graph editor with drag-and-drop wiring
- LFO CHOP driving a Noise TOP (demonstrating cross-family data flow)
- Composite TOP, Level TOP
- Parameter inspector with expression support
- Real-time texture viewer
- Save/load patches

### Planned (Post-MVP)

- SOP, POP, DAT, MAT, COMP families
- GPU particle system (millions of points via compute shaders)
- Renderer switching (Forward+, Mobile, Compatibility) for target platform preview
- Patch export as standalone apps (desktop, mobile, web)
- LibGodot embedding for host applications (VDMX, Resolume)
- Syphon / Spout texture sharing
- OSC, MIDI, NDI input/output
- Custom GLSL shader operators
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
│   ├── core/                        # Framework core (data types, cook engine, network model)
│   ├── operators/                   # Built-in operators organized by family
│   │   ├── top/                     # Texture operators
│   │   ├── chop/                    # Channel operators
│   │   └── ...
│   ├── ui/                          # Editor UI (graph editor, inspector, viewer)
│   └── shaders/                     # GLSL shaders for TOP/POP processing
├── scenes/                          # Application scenes
└── tests/                           # Unit tests
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
