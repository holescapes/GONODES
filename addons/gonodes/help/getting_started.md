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
| **Output** | Final output sinks for rendering and display    |

---

## Your First Patch

1. Press **Alt+A** to open the Add Node palette
2. Type **Noise** and select **NoiseTOP**
3. Press **Alt+A** again and add an **OutputTOP**
4. Drag from NoiseTOP's output port to OutputTOP's input
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
sinks (OutputTOP, RenderTOP, WindowTOP) to find all nodes that feed them.
Only these "active" nodes are evaluated — disconnected nodes are skipped.

### Expressions

Any parameter can be driven by a GDScript expression instead of a static value.
Click the **C** button next to a parameter to switch to expression mode (the button
changes to **E**). Expressions have access to `time`, `frame`, `dt`, and `me`.

### Sub-Networks

Double-click a BaseCOMP node to dive inside its sub-network. Use **Backspace**
to navigate back up. The breadcrumb bar at the top shows your current location.

### Script Operators

Five script operator types let you write custom logic:

- **ScriptCHOP** — custom channel processing
- **ScriptDAT** — custom data table generation
- **ScriptSOP** — custom geometry generation
- **ScriptIMG** — custom image processing
- **GenericScriptNode** — multi-family output (CHOP + DAT + IMG)

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
