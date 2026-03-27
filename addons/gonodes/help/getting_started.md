# Getting Started with GONODES

GONODES is a node-based visual programming environment for Godot,
inspired by TouchDesigner. Build real-time graphics, audio processing,
and data-driven applications by connecting operators in a graph.

---

## Operator Families

GONODES organizes operators into families based on the type of data they process:

| Family   | Purpose                                           |
|----------|--------------------------------------------------|
| **TOP**  | Texture operators — shader-based image generation and compositing |
| **IMG**  | Image operators — CPU-side image processing       |
| **CHOP** | Channel operators — time-based data and animation |
| **DAT**  | Data operators — tables, text, and structured data |
| **SOP**  | Surface operators — 3D geometry generation        |
| **MAT**  | Material operators — shader materials for 3D      |
| **COMP** | Component operators — 3D scene objects and sub-networks |
| **UI**   | User interface operators — interactive 2D widgets for control panels |
| **OUT**  | Final output sinks for rendering and display    |
| **POP**  | GPU particle operators — compute shader particle systems |
| **VOL**  | Volumetric operators — 3D texture volumes, fluid sim, marching cubes |
| **SDF**  | Signed distance field operators — primitives, booleans, modifiers |
| **SCRIPT** | User scripting operators — GDScript, Python, C++ |

---

## Your First Patch

1. Press **Alt+A** to open the Add Node palette
2. Type **Noise** and select **NoiseTOP**
3. Press **Alt+A** again and add a **WindowOUT**
4. Drag from NoiseTOP's output port to WindowOUT's input
5. The viewer shows animated Perlin noise!

Try adjusting parameters in the inspector panel on the right. Click a node
to select it and see its parameters.

---

## Key Concepts

### Cooking

Every frame, the cook engine evaluates dirty nodes in the active chain.
A node becomes "dirty" when its parameters change, its inputs update, or
time advances (for time-dependent operators).

### Active Chain

Not every node cooks every frame. The engine traces backward from output
sinks (WindowOUT, RenderTOP) to find all nodes that feed them.
Only these "active" nodes are evaluated — disconnected nodes are skipped.

### Expressions

Any parameter can be driven by a GDScript expression instead of a static value.
Click the **C** button next to a parameter to switch to expression mode (the button
changes to **E**). Expressions have access to `time`, `frame`, `dt`, and `me`.

### Sub-Networks

Double-click a BaseCOMP node to dive inside its sub-network. Use **Backspace**
to navigate back up. The breadcrumb bar at the top shows your current location.

### Script Operators

Three consolidated SCRIPT family operators let you write custom logic:

- **GDScriptSCRIPT** — GDScript scripting with template dropdown (CHOP, SOP, DAT, IMG, TOP, Generic)
- **PythonSCRIPT** — Python scripting with NumPy (CHOP, SOP, DAT, IMG, TOP)
- **NativeSCRIPT** — hot-reloadable C++ scripting (CHOP, SOP, DAT, IMG, TOP)

All three use `par("name")` / `params.get("name")` to read custom parameters
declared via annotations. Wire a Null of the target family to view output.

Each has a code editor with presets accessible from the inspector.

### Save & Load

Patches are saved as `.gnpatch` JSON files. Use **Ctrl+S** to save,
**Ctrl+O** to open, and **Ctrl+N** to create a new patch.

---

## Tips

- Press **F1** anytime to open this help window
- Right-click any node and choose "Help" for node-specific documentation
- Enable **Perf** overlay to see per-node cook times
- Use **B** to bypass nodes for A/B testing
- Use **F** to fit the view to selected nodes (or the entire graph)
- Check the Expressions section for cross-node references (`chop()`, `top()`, etc.)
