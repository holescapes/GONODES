# Contributing to GONODES

> **Last updated:** 2026-03-10  
> **Godot version:** 4.6.1 stable  
> **GDScript only** — no C++/GDExtension contributions to core (extensions may use GDExtension)

---

## Table of Contents

1. [Before You Start](#1-before-you-start)
2. [Repository Structure](#2-repository-structure)
3. [Development Setup](#3-development-setup)
4. [Contributing a New Operator](#4-contributing-a-new-operator)
5. [Contributing an Extension](#5-contributing-an-extension)
6. [Code Style & Conventions](#6-code-style--conventions)
7. [Documentation Requirements](#7-documentation-requirements)
8. [Help System Integration](#8-help-system-integration)
9. [Testing Requirements](#9-testing-requirements)
10. [Hard Rules — Non-Negotiable](#10-hard-rules--non-negotiable)
11. [Pull Request Checklist](#11-pull-request-checklist)
12. [Architecture Guidelines](#12-architecture-guidelines)
13. [Common Pitfalls](#13-common-pitfalls)

---

## 1. Before You Start

- Read `GONODES_CONTEXT.md` at the project root — it is the single source of truth for architecture, conventions, and hard rules.
- Skim the operator family you plan to work in (TOP, CHOP, DAT, SOP, COMP, MAT, IMG, OUT, UI) by reading 2–3 existing operators in `addons/gonodes/operators/<family>/`.
- Run the test suite to confirm a clean baseline (see [§9](#9-testing-requirements)).
- Check the roadmap section in `GONODES_CONTEXT.md` (§28.8) for planned work — avoid duplicating effort.

---

## 2. Repository Structure

```
addons/gonodes/
├── core/           # Engine: cook engine, network, data types, base classes
├── operators/      # All operator scripts, organized by family
│   ├── top/        # Texture operators (GPU)
│   ├── chop/       # Channel operators
│   ├── dat/        # Data/table operators
│   ├── sop/        # Surface/geometry operators
│   ├── comp/       # Component operators (3D scene)
│   ├── mat/        # Material operators
│   └── img/        # CPU image operators
├── ui/             # Editor GUI (graph, inspector, palette, viewer, debug panel/overlay)
├── help/           # User-facing help — .md guides + .gnpatch examples
│   ├── chop/       # CHOP example patches
│   ├── top/        # TOP example patches
│   ├── sop/        # SOP example patches
│   ├── comp/       # COMP example patches
│   ├── dat/        # DAT example patches
│   └── mat/        # MAT example patches
├── presets/        # Script/shader presets
└── shaders/        # Shared .gdshader files

dev_docs/           # Developer documentation (this folder)
docs/               # Public-facing documentation (OPERATORS.md, etc.)
tests/              # Automated test suite
  ├── test_runner.gd
  ├── test_assert.gd
  ├── test_*.gd     # Unit tests
  └── integration/  # Integration tests
```

**Key rule:** `core/` and `operators/` must NEVER import from `ui/`. The engine runs headless. See [Hard Rule 25.20](#hard-rule-2520-editorengine-separation).

---

## 3. Development Setup

1. Clone the repository.
2. Open the project in **Godot 4.6.1** (stable).
3. The editor scene is `scenes/gn_editor.tscn` — run it to launch the GONODES editor.
4. Run tests:
   ```powershell
   godot --headless --path "C:\MeOwn\Gonodes" -s tests/test_runner.gd
   ```
5. No external dependencies are required for core development.

---

## 4. Contributing a New Operator

This is the most common contribution type. Every new operator **must** include all of the following:

### 4.1 The Operator Script

Create `addons/gonodes/operators/<family>/<node_type>_<family>.gd`.

**Naming:** Lowercase snake_case filename. Class name is PascalCase + family suffix (e.g., `MyNodeSOP`, `CoolEffectTOP`).

**Required structure:**

```gdscript
class_name MyNewSOP
extends GNSopBase

func _init() -> void:
    node_type = "mynew"
    family = GNFamily.Type.SOP
    node_description = "Short sentence describing what this operator does."

func _init_ports() -> void:
    # Every port MUST have a description (last argument)
    add_input("geo", GNFamily.Type.SOP, true, "Input geometry to process")
    add_output("out", GNFamily.Type.SOP, "Processed geometry output")

func _setup_parameters() -> void:
    # Every parameter MUST have a description (last argument)
    var p := GNParameter
    add_parameter(p.create_float("strength", 1.0, 0.0, 10.0, 0.1, "Strength", "How much effect to apply"))
    add_parameter(p.create_int("iterations", 3, 1, 20, "Iterations", "Number of processing passes"))
    add_parameter(p.create_bool("normalize", true, "Normalize", "Normalize output values"))
    add_parameter(p.create_enum("mode", 0, ["Fast", "Quality"], "Mode", "Processing quality mode"))

func _cook(inputs: Array) -> GNGeoData:
    var geo: GNGeoData = _require_input_geo(inputs)
    if geo == null:
        return null

    var strength: float = get_parameter_value("strength")
    # ... processing logic ...

    return geo
```

**Mandatory elements in `_init()`:**
- `node_type` — lowercase string identifier (unique across all operators)
- `family` — `GNFamily.Type.<FAMILY>`
- `node_description` — one-sentence purpose description (shown in palette tooltips)
- `time_dependent = true` only if the operator genuinely changes every frame

**Mandatory elements in `_init_ports()`:**
- Every `add_input()` and `add_output()` call must include a description string as the last argument.

**Mandatory elements in `_setup_parameters()`:**
- Every `GNParameter.create_*()` call must include a description string as the last argument.
- Use sensible defaults and ranges.

### 4.2 Registry Entry

Register your operator in `addons/gonodes/core/gn_extension_registry.gd` inside `_register_core_operators()`:

```gdscript
_reg("MyNewSOP", "sop", MyNewSOP, "Short sentence describing what this operator does.")
```

The four arguments are: registry key (must match `class_name`), family string, class reference, description.

If your operator belongs to a logical sub-section, place it near related operators with a comment header.

### 4.3 Help Example Patch (REQUIRED — Hard Rule 25.21)

Create at least one `.gnpatch` file in `addons/gonodes/help/<family>/`:

**Naming:** `<node_type>_<descriptive_label>.gnpatch`
- `node_type` is the lowercase type string from your operator's `_init()`
- `label` is a short slug: `basic`, `advanced`, `color`, `animated`, etc.
- Examples: `mynew_basic.gnpatch`, `particle_emitter.gnpatch`, `lsystem_basic.gnpatch`

**Format (JSON):**

```json
{
    "version": "1.0.0",
    "generator": "GONODES",
    "nodes": {
        "mynew1": {
            "type": "MyNewSOP",
            "position": [100, 100],
            "parameters": {
                "strength": {"value": 2.5},
                "iterations": {"value": 5}
            }
        },
        "null1": {
            "type": "NullSOP",
            "position": [400, 100],
            "parameters": {}
        }
    },
    "connections": [
        {"from": "mynew1", "from_port": 0, "to": "null1", "to_port": 0}
    ],
    "annotations": [
        {
            "id": "ann_1",
            "type": "note",
            "text": "MyNew SOP — Basic Usage\n\nDescribe what this demo shows in 2-3 lines.\nMention key parameters and what to try changing.",
            "position": [-100.0, -150.0],
            "size": [400.0, 100.0],
            "color": [1.0, 1.0, 1.0, 0.8]
        }
    ]
}
```

**Content rules:**
- The `type` field must use the operator's `class_name` (e.g., `"MyNewSOP"`, not `"mynew"`).
- Use **non-default** parameter values that produce a visually interesting or demonstrative result.
- Keep it self-contained — no external file dependencies (unless the operator is a file-input operator).
- Patch complexity: 1–4 nodes. Users should understand the operator at a glance.
- Include an annotation (sticky note) explaining what the patch demonstrates.
- For operators with distinct modes, create 2–3 patches (e.g., `blur_basic.gnpatch` + `blur_heavy.gnpatch`).

### 4.4 Documentation Update

Update `docs/OPERATORS.md`:
- Add a full entry in the appropriate family section with parameter table, input/output descriptions, and a "How it works" paragraph.
- Update the family operator count.
- Update the Quick Reference table at the bottom (count + operator name).
- Update the header total count.

---

## 5. Contributing an Extension

Extensions are separate addons in `addons/gn_ext_<name>/` that register operators with the core registry without modifying core code.

### Extension Structure

```
addons/gn_ext_myext/
├── gn_extension.cfg          # Extension descriptor (INI format)
├── README.md                 # Extension documentation
├── operators/
│   └── <family>/
│       └── my_operator.gd    # Operator scripts
└── help/                     # Extension help patches
    └── <family>/
        └── myop_basic.gnpatch
```

### gn_extension.cfg Format

```ini
[extension]
name = "My Extension"
version = "1.0.0"
author = "Your Name"
description = "What this extension adds"
section = "My Extension"

[operators]
my_operator = "res://addons/gn_ext_myext/operators/top/my_operator.gd"
```

Extensions are auto-discovered by the registry during editor startup via `scan_extensions()`. The `section` field groups your operators under a labeled section in the palette.

All the same rules apply to extension operators: descriptions, help patches, parameter tooltips.

---

## 6. Code Style & Conventions

### General

- **Language:** GDScript only for core and operators.
- **Indentation:** Tabs (Godot default).
- **Line length:** Keep reasonable (~100 chars). No strict limit.
- **Naming:**
  - Classes: `PascalCase` with family suffix (`NoiseTOP`, `LFOCHOP`, `BoxSOP`)
  - Functions: `snake_case`
  - Private functions: `_underscore_prefix`
  - Parameters/variables: `snake_case`
  - Constants: `UPPER_SNAKE_CASE`
  - Signals: `snake_case` (e.g., `node_cooked`, `parameter_changed`)
- **Comments:** Use them. Every non-trivial block of logic should have a brief comment explaining *why*, not just *what*.

### Operator-Specific Style

```gdscript
# Good — explains the non-obvious
# Clamp resolution to prevent GPU memory explosion on high-iteration L-systems
var res := clampi(get_parameter_value("resolution"), 4, 128)

# Bad — restates the code
# Set res to the resolution parameter value
var res := get_parameter_value("resolution")
```

- Keep `_cook()` methods focused. Extract helper methods for complex algorithms.
- Use early returns for error/null-input cases at the top of `_cook()`.
- Prefer `var x: Type` explicit typing for function parameters and return types.
- Use `push_warning()` for recoverable issues, `push_error()` for bugs.

### Family Base Classes

Every operator must extend the correct family base class:

| Family | Base Class | Output Type |
|--------|-----------|-------------|
| TOP | `GNTopBase` | `GNTextureData` |
| CHOP | `GNChopBase` | `GNChannelData` |
| DAT | `GNDatBase` | `GNTableData` |
| SOP | `GNSopBase` | `GNGeoData` |
| COMP | `GNCompBase` | `null` (Node3D via API) |
| MAT | `GNMatBase` | `GNMaterialData` |
| IMG | `GNImgBase` | `GNImageData` |
| IMG (GPU compute) | `GNImgComputeBase` | `GNImageData` |
| UI | `GNUiBase` | `null` (Control via API) |

---

## 7. Documentation Requirements

### What to Update

When you add or modify operators, update **all** of the following:

| File | What to update |
|------|---------------|
| `docs/OPERATORS.md` | Full parameter table, description, "How it works" paragraph, family count, Quick Reference |
| `GONODES_CONTEXT.md` | Status paragraph (operator count), relevant architecture sections if applicable |
| `dev_docs/README.md` | Only if adding new dev doc files |

### OPERATORS.md Entry Template

```markdown
#### MyNewSOP

One-sentence description of the operator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.0–10.0 | How much effect to apply |
| iterations | Int | 3 | 1–20 | Number of processing passes |

**Input:** `geo` (SOP — geometry to process).

**How it works:** 2–4 sentences explaining the algorithm, Godot APIs used, and any important implementation details. Mention edge cases or limitations.
```

---

## 8. Help System Integration

The in-editor Help window discovers `.gnpatch` files by scanning `addons/gonodes/help/<family>/` directories at runtime. No manifest or registration is needed — just drop the file in the right folder.

### Help Patch Discovery

- Files are matched to operators by the `<node_type>` prefix in the filename.
- Multiple patches per operator are fine (and encouraged for multi-mode operators).
- The annotation sticky note is displayed in the help window as the patch description.

### Verifying Help Coverage

Compare operator names from the registry against filenames in `help/<family>/`. Every operator should have at least one matching `.gnpatch` file. To check:

```gdscript
# In a Script operator or the console:
var reg = GNExtensionRegistry.instance()
var operators = reg.get_all_operators()
# Cross-reference against files in help/ directories
```

### Help Markdown Guides

User-facing guides live in `addons/gonodes/help/*.md`. These are rendered in the Help window sidebar. If your contribution adds a major new concept or workflow, consider adding or updating a help guide.

---

## 9. Testing Requirements

### Running the Suite

```bash
godot --headless --path /path/to/Gonodes -s tests/test_runner.gd
```

All tests must pass before submitting a contribution. The framework is zero-dependency (no GUT/GdUnit4) — pure GDScript running in `--headless` mode.

### What to Test

| Contribution Type | Required Tests |
|-------------------|---------------|
| New CPU operator (CHOP, DAT, SOP) | Integration test in `tests/integration/` exercising cook with representative inputs |
| New GPU operator (TOP) | Manual test via help patch (GPU tests can't run headless) |
| Core engine change | Unit test in `tests/` covering the modified logic |
| Bug fix | Regression test proving the fix holds |

### Writing a Test

```gdscript
# tests/test_my_feature.gd
extends Node

func test_my_operator_basic_cook():
    var network := GNNetwork.new()
    add_child(network)
    var engine := GNCookEngine.new()
    engine.network = network

    var node = network.add_operator("MyNewSOP", "mynew1")
    node.set_parameter_value("strength", 2.5)

    engine.cook_frame(0.016)

    var output = node.get_output()
    GNTestAssert.assert_not_null(output, "Output should not be null")
    # ... additional assertions ...

    network.queue_free()
```

### Test File Naming

- `test_<feature>.gd` in `tests/` for unit tests
- `test_<feature>.gd` in `tests/integration/` for integration tests
- All files matching `test_*.gd` under `tests/` are auto-discovered by the runner.

---

## 10. Hard Rules — Non-Negotiable

These rules are absolute constraints discovered during development. Violations will block acceptance. Full details in `GONODES_CONTEXT.md` §25.

### Hard Rule 25.1: No CPU Roundtrips for Real-Time Texture Data

**NEVER** call `Texture2D.get_image()` or `Image.get_data()` in a per-frame code path. This triggers a GPU→CPU readback stalling the pipeline (5–15ms). Use `ViewportTexture` (live GPU reference) for all real-time texture routing.

### Hard Rule 25.11: COMP Nodes Return Null Output

COMPs return `null` from `_cook()`. Their output is a Godot `Node3D` accessed via API methods (`get_mesh_instance()`, `get_camera()`, etc.). The cook engine suppresses null-output warnings for COMP nodes.

### Hard Rule 25.13: Lazy Cook / No Unnecessary Work

A node must NOT cook if nothing changed. Only cook when: `time_dependent = true`, a parameter changed, or upstream input changed. Never set `time_dependent = true` unless the operator genuinely changes every frame.

### Hard Rule 25.14: Tooltip Descriptions Mandatory

Every operator must provide: (1) `node_description` in `_init()`, (2) description string on every `add_input()`/`add_output()` call, (3) description string on every `GNParameter.create_*()` call.

### Hard Rule 25.20: Editor/Engine Separation

`core/` and `operators/` must NEVER import or reference `ui/`. The cook engine and all operators must run headless without any editor present. No `preload()`/`load()` of any `ui/` path from engine code.

### Hard Rule 25.21: Help Example Patches Required

Every new operator must ship with at least one `.gnpatch` example file in `addons/gonodes/help/<family>/`. See [§4.3](#43-help-example-patch-required--hard-rule-2521) for format details.

### Hard Rule 25.23: UTF-8 Encoding — No PowerShell String Manipulation

All text files (`.md`, `.gd`, `.cfg`, `.tscn`, `.gnpatch`) are UTF-8 without BOM. **NEVER** use PowerShell `Get-Content` / `Set-Content` on files with non-ASCII characters without `-Encoding UTF8` on **both** calls. PowerShell defaults to Windows-1252, causing compounding corruption. **Prefer Python** for text manipulation involving non-ASCII. Corruption signature: `Ã¢â‚¬â€` instead of `—`. See `GONODES_CONTEXT.md` §25.23 and `BUILD.md` → UTF-8 Encoding Safeguards for full details.

---

## 11. Pull Request Checklist

Before submitting, verify every item:

### New Operator PR

- [ ] Operator script in `addons/gonodes/operators/<family>/`
- [ ] Extends the correct family base class
- [ ] `node_type`, `family`, and `node_description` set in `_init()`
- [ ] All ports have description strings
- [ ] All parameters have description strings, labels, sensible defaults and ranges
- [ ] Registered in `gn_extension_registry.gd` → `_register_core_operators()`
- [ ] At least one `.gnpatch` help example patch in `addons/gonodes/help/<family>/`
- [ ] Help patch uses `class_name` in the `type` field (not the `node_type` string)
- [ ] Help patch has non-default params producing a visually interesting result
- [ ] Help patch has an annotation sticky note explaining the demo
- [ ] `docs/OPERATORS.md` updated (entry + counts + Quick Reference)
- [ ] `GONODES_CONTEXT.md` status paragraph updated with new operator count
- [ ] Test suite passes: `godot --headless -s tests/test_runner.gd`
- [ ] Integration test added (for CPU-side operators)
- [ ] No imports from `ui/` in operator or core code

### Bug Fix PR

- [ ] Regression test added proving the fix
- [ ] Test suite passes
- [ ] Relevant docs updated if behavior changed

### Core Engine PR

- [ ] Unit tests covering the change
- [ ] No regressions in existing tests
- [ ] `GONODES_CONTEXT.md` updated if architecture changed
- [ ] Hard rules respected (especially 25.13 lazy cook, 25.20 separation)

---

## 12. Architecture Guidelines

### Cook Engine Flow

```
Parameter change / Frame tick
  → Mark node dirty
    → GNCookEngine.cook_frame()
      → Topological sort of dirty nodes
        → For each dirty node: _cook(inputs) → output
          → Downstream nodes marked dirty
```

- Operators receive their inputs as an `Array` in `_cook(inputs)`. Each element corresponds to an input port (may be `null` if disconnected).
- Return the appropriate `GNData` subclass (or `null` for COMP family).
- Never store references to other operators. Access upstream data only through the `inputs` array.

### Data Types

| Type | Family | Description |
|------|--------|-------------|
| `GNTextureData` | TOP | Wraps `ViewportTexture` (GPU reference) |
| `GNChannelData` | CHOP | Named float arrays (`PackedFloat32Array`) |
| `GNTableData` | DAT | 2D string table or plain text |
| `GNGeoData` | SOP | Wraps `ArrayMesh` |
| `GNMaterialData` | MAT | Wraps Godot `Material` |
| `GNImageData` | IMG | Wraps CPU-side `Image` |

### Adding a TOP (GPU Operator)

TOPs use an isolated `SubViewport` + `ShaderMaterial` pattern:

1. Extend `GNTopBase` — provides `_viewport`, `_material`, `_canvas`, `_cached_tex_data`.
2. Create your shader in `addons/gonodes/shaders/` or inline.
3. In `_cook()`: set shader uniforms, assign input textures, set `_viewport.size`, let `_ensure_viewport()` handle rendering.
4. Return `_cached_tex_data` (the base class manages the `ViewportTexture` lifecycle).
5. All texture passing stays on GPU — zero CPU readback.

### Adding a SOP (Geometry Operator)

1. Extend `GNSopBase`.
2. Use `SurfaceTool` for procedural mesh generation.
3. Use `_require_input_geo(inputs)` to get input geometry (takes **1 argument only** — always reads port 0).
4. Use `_get_input_sop(inputs, port_index)` for multi-input operators (2 arguments).
5. Return `GNGeoData` wrapping the generated `ArrayMesh`.

### Adding a COMP (3D Scene Component)

1. Extend `GNCompBase`.
2. Create Godot `Node3D` subclass (MeshInstance3D, etc.) in `_cook()`.
3. Return `null` from `_cook()` — provide access via getter methods (e.g., `get_mesh_instance()`).
4. RenderTOP discovers COMPs by walking the network graph.

### Adding a GPU Compute IMG Operator

For pixel-parallel operations (blur, edge detect, color transforms), use the GPU compute path instead of CPU loops:

1. Extend `GNImgComputeBase` (not `GNImgBase`).
2. Write a GLSL compute shader in `addons/gonodes/shaders/img/`.
3. Override `_dispatch_compute()` — set uniforms, dispatch workgroups.
4. Override `_cook_cpu()` — provide a CPU fallback for when compute is unavailable.
5. The base class handles: Image ↔ GPU upload/download, shader compilation caching, fallback detection, GPU texture lifecycle.

See `gpu_blur_img.gd` and `gpu_edge_detect_img.gd` for reference implementations.

### Spare Parameters

Any node can have user-added "spare" parameters via right-click → "Add Spare Parameter…". Spare parameters:

- Are stored in `gn_node.gd` → `spare_parameters: Dictionary`, separate from `_init_parameters()`.
- Support types: Float, Int, Bool, String, Color, Vector2, Vector2i.
- Are accessible via the same `get_parameter_value()` / `set_parameter_value()` API as regular params.
- Serialize in `.gnpatch` files under a `"spare_parameters"` key per node.
- Render in the inspector under a collapsible "Spare Parameters" section.

### Debug System Architecture

The debug system provides cook engine visibility without violating
editor/engine separation (Hard Rule 25.20).  Two UI-only files:

- `gn_debug_panel.gd` — 3-tab docked panel (Cook Chain, Active Chains, Param Refs)
- `gn_debug_overlay.gd` — 5-layer canvas overlay (cook order, dimming, dirty flash, sinks, data flow)

Both live in `ui/` and receive `GNCookEngine` / `GNNetwork` references at
runtime from `gn_editor.gd`.  They **read** engine properties
(`last_topo_order`, `_active_set`, `active_sinks`, connections, parameters)
but **never modify** engine state.  The only engine-side addition was
`GNCookEngine.last_topo_order` — a cached copy of the topological sort
result exposed for debug consumers.

If you add new engine telemetry, expose it as a read-only property on the
engine class and consume it from the debug UI.  Never add UI imports to
`core/` or `operators/`.

### Custom Operator Assets (.gnasset)

SubNetworks can be promoted to reusable custom operators via right-click → "Promote to Custom Asset…":

1. `GNCustomOperator` (extends SubNetworkNode) loads from a `.gnasset` JSON file.
2. The promotion dialog lets users select which inner parameters to promote (expose externally).
3. `.gnasset` files are scanned from 3 directories: `res://addons/gonodes/assets/`, `res://custom_operators/`, `user://gonodes_assets/`.
4. Custom assets appear in the palette under a "Custom" section per family.

---

## 13. Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| `_require_input_geo(inputs, 0)` — 2 args | `_require_input_geo(inputs)` — takes 1 arg only (always port 0). Use `_get_input_sop(inputs, port_index)` for specific ports. |
| `get_cook_dt()` not found | Use `current_delta` property on `GNNode` instead. |
| Operator works in editor but fails headless | You imported from `ui/`. Check for `preload("res://addons/gonodes/ui/...")`. |
| Help patch `type` field mismatch | Use `class_name` (e.g., `"NoiseTOP"`), not `node_type` (e.g., `"noise"`). |
| SubViewport renders every frame | Set `time_dependent = false` unless the operator genuinely needs per-frame updates. Use `UPDATE_ONCE` pattern. |
| Inspector clobbers user edits | Never set parameter UI text per-cook. Check `has_focus()` before updating any editable field. |
| Canvas appears as 0×0 in TOP | Use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` AFTER `add_child()`. Never use `set_anchors_preset()` alone. |
| Vector3 pass-by-value in loops | GDScript Vector3 is copied on assignment. Use Dictionary for mutable state passed between functions. |
| Dynamic ports not updating UI | Always emit `ports_changed(node_id)` signal after modifying port arrays. |
| Node has empty ports after `.new()` | `_init_ports()` is not called in constructor. Call it explicitly after `.new()` if you need port info, or use full `initialize(id)`. |

---

## Questions?

Open a discussion or issue on the repository. For architecture questions, reference the specific section number in `GONODES_CONTEXT.md` — it is the authoritative document.
