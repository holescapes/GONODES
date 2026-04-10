# Help Patch Quality Rules

This document defines the hard rules for what makes a **meaningful** help patch in GONODES. Every help patch must pass these rules or it gets rewritten.

## Core Principle

> A help patch must teach the user something specific about the operator's behavior. "Default settings" is **never** an acceptable annotation. Every patch must have a clear purpose that a user can understand from the annotation alone.

## Universal Rules (All Families)

### Structure
1. **Every patch must end in a visible output** — WindowOUT (for TOP/SOP/COMP/MAT/VOL/POP), or CHOPtoTOP→WindowOUT (for CHOP), or TextTOP→WindowOUT (for DAT), or WindowOUT port 1 (for UI).
2. **Annotation is mandatory** — every patch must have at least one annotation explaining:
   - What the patch demonstrates (one clear sentence)
   - Which parameters are highlighted and why
   - What the user should observe in the output
3. **The focus node's name must be the operator's node_type + a number** — e.g., `blur1`, `noise1`, `wave1`. Not `src_blur` or `my_blur`.
4. **Node IDs must be lowercase with underscores** — no camelCase.

### Parameters
5. **"Basic" patches use static, sensible defaults** — no expressions, no `mode: EXPRESSION`. The purpose is to show what the node does in its simplest form.
6. **"Feature" patches (middle patch) isolate ONE specific parameter or feature** — name the patch after that parameter (e.g., `blur_size`, `blur_method`). Set the featured parameter to a non-default, clearly demonstrative value. Other params stay at defaults.
7. **"Advanced" patches show a more complex or combined use** — may include expressions, multi-input wiring, chains with other operators, or feedback loops.
8. **Never put expressions on enum/menu parameters** — a float expression on a menu cycles through modes nonsensically. Instead, set the menu to a specific integer value and mention the mode name in the annotation.
9. **Never put expressions on the _source_ node in a "basic" patch** — the source should be static so the focus node's behavior is clearly visible.
10. **Parameter values must be demonstrative** — if showing "blur size", use a clearly visible value (e.g., 20.0, not 2.5). If showing "quality", compare low vs high.

### Naming Convention
11. **Filename format:** `{node_type}_{purpose}.gnpatch`
    - `{node_type}_basic.gnpatch` — simplest useful demo
    - `{node_type}_{param_name}.gnpatch` — isolates one parameter
    - `{node_type}_{use_case}.gnpatch` — demonstrates a real-world scenario
12. **No duplicate purposes** — if `blur_size` and `blur_variation` both just change blur size, one must be removed or repurposed.

### Annotation Format
13. **Title line:** `{ClassName} — {Purpose}`
14. **Body:** 1–3 sentences explaining what's happening and what to look at.
15. **Color coding:**
    - White (1,1,1,0.8) — standard
    - Green (0.5,0.8,0.5,0.8) — recommended/good practice
    - Orange (1.0,0.7,0.3,0.8) — caution/performance note
    - Blue (0.4,0.6,1.0,0.8) — integration/cross-family

---

## Coverage Rules (How Many Patches Per Operator)

### Minimum Coverage
- **Simple operators** (≤2 params, single function): 2 patches minimum
  - `_basic` + one feature or use-case patch
- **Standard operators** (3–6 params): 3 patches minimum
  - `_basic` + 1 specific feature + 1 advanced/combined
- **Complex operators** (7+ params or multiple modes): 4+ patches
  - `_basic` + one per major mode/feature + 1 advanced chain
- **Null/Select/Switch/DotNode**: 2 patches
  - `_basic` (show pass-through purpose) + one practical use (e.g., feedback, expression reference)

### What Counts as "Meaningful"
A patch is meaningful if and only if:
- It demonstrates a **specific, observable behavior** that differs from other patches of the same operator
- The annotation **accurately describes what the patch shows**
- A user opening this patch for the first time can **learn something** about the operator

### What Is NOT Meaningful
- "Default settings" with no explanation of what the default produces
- Two patches that produce visually identical results with trivially different param values
- A patch whose annotation says "Showcases: size, quality, method" but doesn't explain what each does
- A patch that puts expressions on the source node but leaves the focus node at defaults

---

## Per-Family Rules

### TOP (Texture Operators)
- **Source nodes:** Use NoiseTOP, RampTOP, CircleTOP, or PatternTOP as input — pick the one that best shows the effect (e.g., CircleTOP for blur glow, NoiseTOP for edge detect).
- **Generators** (Noise, Ramp, Circle, etc.): Don't need a source — show the generator directly.
- **Resolution:** Always set explicitly (default 512×512 for demos).
- **Feature patches should show before/after** if possible — use a SwitchTOP or side-by-side Composite2TOP to compare.
- **Expressions are welcome in advanced patches** — e.g., `time`-driven animation to show a parameter's range dynamically.

### CHOP (Channel Operators)
- **Visualization:** Always end with CHOPtoTOP→WindowOUT so the waveform is visible.
- **Source nodes:** Use LFO_CHOP, WaveCHOP, NoiseCHOP, or ConstantCHOP as input.
- **Generators** (Wave, LFO, Noise, etc.): Show the generated waveform directly.
- **Feature patches for time-based CHOPs** (Timer, Trail, Trigger): Use meaningful time values that show behavior in the first few seconds of the patch running.
- **Multi-channel demos** should use `channels` parameter to show 2–4 channels with phase offsets for visual clarity.
- **AudioIn/AudioFileIn:** Can't demo without hardware — annotation must explain what the user would see with audio input.

### SOP (Surface Operators)
- **Visualization:** End with SOP→GeometryCOMP→RenderTOP→WindowOUT (the standard SOP render chain).
- **Camera setup:** Camera at (0, 0.5, 3) looking at origin for small objects; (0, 2, 8) for larger scenes.
- **Generators** (Grid, Box, Sphere, etc.): Feature patches should show parameter effects (e.g., grid rows/cols, sphere frequency).
- **Filters** (Transform, Noise, Subdivide, etc.): Basic patch uses a simple mesh input (grid or sphere), feature patches show the most impactful parameter.
- **Material:** Add a PbrMAT or WireframeMAT to GeometryCOMP when surface detail matters (e.g., NormalSOP, SubdivideSOP).

### DAT (Data Operators)
- **Visualization:** End with DAT→TextTOP→WindowOUT (TextTOP auto-renders table content).
- **Table generators** (ConstantDAT, TableDAT): Show actual data in the table cells.
- **Network operators** (WebSocket, OSC, MQTT, Serial): Can't demo without live connections — annotation must explain what happens with a running server/device.
- **Feature patches:** Show specific modes (Table vs Text), filtering, sorting, column operations.
- **JSON/XML:** Show actual parsing of realistic data.

### IMG (Image Operators)
- **Visualization:** End with IMG→ImgToTOP→WindowOUT.
- **CPU-based:** Note in annotation that IMG operates on CPU (vs GPU for TOP).
- **File-based** (ImageFileInIMG): Use a path that makes sense or explain that the user needs to supply their own image.

### MAT (Material Operators)
- **Visualization:** End with SOP→GeometryCOMP(+MAT)→RenderTOP→WindowOUT.
- **Always include lighting** — a LightCOMP in the scene so materials are visible.
- **Use appropriate geometry** — SphereSOP for reflective materials (PBR), TorusSOP for materials with clear surface normals, GridSOP for UV-dependent materials.
- **Feature patches:** PBR should show metallic, roughness, emission modes separately. Shader materials should show uniform access.

### COMP (Component Operators)
- **Scene COMPs** (Camera, Light, Environment, Geometry): Must include a complete renderable scene (SOP + GeoCOMP + Camera + Render + Window).
- **Physics COMPs** (RigidBody, SoftBody, etc.): Note that physics requires running _process, show initial configuration.
- **Organizational COMPs** (Null, Switch, Merge, SubNetwork): Show practical use in a chain, not just pass-through.

### VOL (Volume Operators)
- **Visualization:** End with VOL→RaymarchVOL→WindowOUT (raymarch produces a TOP).
- **Generators** (NoiseVOL): Show resolution and channel count effects.
- **Simulation** (FluidVOL, PyroVOL): Show initial conditions and what the first few frames look like.

### POP (Particle Operators)
- **Visualization:** End with POP→RenderPOP→RenderTOP←CameraCOMP→WindowOUT.
- **Always include SourcePOP** — particles need a source.
- **Feature patches:** Show emission rate, force fields (turbulence, gravity), state modifications (color by age, scale by life).

### UI (User Interface Operators)
- **Visualization:** End with UI→WindowOUT (port 1 for panel input).
- **Interactive controls** (Button, Slider, Knob): Should wire output CHOP to something visible (e.g., control a parameter via expression).
- **Layout containers:** Show nested children.

### OUT (Output Operators)
- **Sink nodes** (SinkOUT, HostOut*): Show upstream chain keeping alive.
- **WindowOUT:** Show resolution, fullscreen, multi-monitor setups.

---

## Audit Checklist

When auditing an existing help patch, verify:

- [ ] Annotation exists and is non-trivial (not "Default settings")
- [ ] Annotation title follows `{ClassName} — {Purpose}` format
- [ ] Focus node uses demonstrative parameter values
- [ ] No expressions on enum/menu parameters
- [ ] "Basic" patches have no expressions on source or focus node
- [ ] Feature patches isolate a single parameter or behavior
- [ ] The patch produces a visible, meaningful result in the output window
- [ ] No duplicate purpose with another patch for the same operator
- [ ] Filename matches the `{node_type}_{purpose}.gnpatch` convention
