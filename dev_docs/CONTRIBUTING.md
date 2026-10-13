# Contributing to GONODES

> **Last updated:** 2026-03-27  
> **Godot version:** 4.7.2 stable  
> **GDScript only** — no C++/GDExtension contributions to core (extensions may use GDExtension)

---

## Table of Contents

1. [Before You Start](#1-before-you-start)
2. [Repository Structure](#2-repository-structure)
3. [Development Setup](#3-development-setup)
4. [Contributing a New Operator](#4-contributing-a-new-operator)
5. [Contributing an Extension](#5-contributing-an-extension)
6. [User Native C++ Nodes (gn_ext_user_native)](#6-user-native-c-nodes-gn_ext_user_native)
7. [Code Style & Conventions](#7-code-style--conventions)
8. [Documentation Requirements](#8-documentation-requirements)
9. [Help System Integration](#9-help-system-integration)
10. [Testing Requirements](#10-testing-requirements)
11. [Hard Rules — Non-Negotiable](#11-hard-rules--non-negotiable)
12. [Pull Request Checklist](#12-pull-request-checklist)
13. [Architecture Guidelines](#13-architecture-guidelines)
14. [Common Pitfalls](#14-common-pitfalls)

---

## 1. Before You Start

- Read `GONODES_CONTEXT.md` at the project root — it is the single source of truth for architecture, conventions, and hard rules.
- Skim the operator family you plan to work in (TOP, CHOP, DAT, SOP, COMP, MAT, IMG, OUT, UI, POP, VOL, SCRIPT) by reading 2–3 existing operators in `addons/gonodes/operators/<family>/`.
- Run the test suite to confirm a clean baseline (see [§9](#9-testing-requirements)).
- Check the roadmap section in `GONODES_CONTEXT.md` (§28.8) for planned work — avoid duplicating effort.

---

## 2. Repository Structure

```
addons/gonodes/
├── core/           # Engine: cook engine, network, data types, base classes, GNViewerRenderHelpers
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
│   ├── mat/        # MAT example patches
│   ├── script/     # SCRIPT example patches
│   └── output/     # OUT example patches
├── presets/        # Script/shader presets
└── shaders/        # Shared .gdshader files

addons/gn_ext_*/    # Extension plugins (SDF, ISF, Shadertoy, MIDI, Spout, NDI, etc.)
├── gn_extension.cfg  # Extension manifest
├── boot.gd           # Optional: runtime registration hooks for UI integration
├── operators/         # Extension operator scripts
└── help/              # Extension help patches

dev_docs/           # Developer documentation (this folder)
docs/               # Public-facing documentation (OPERATORS.md, etc.)
tests/              # Automated test suite
  ├── test_runner.gd
  ├── test_assert.gd
  ├── test_*.gd     # Unit tests
  ├── functional/   # Functional tests (multi-operator chains)
  ├── operators/    # Per-family operator tests
  └── integration/  # Integration tests
```

**Key rule:** `core/` and `operators/` must NEVER import from `ui/`. The engine runs headless. See [Hard Rule 25.20](#hard-rule-2520-editorengine-separation).

---

## 3. Development Setup

1. Clone the repository.
2. Run `python setup_deps.py` to fetch godot-cpp, Spout2 SDK, and extension SDKs.
   - Dependency versions (Godot, godot-cpp branch) are read from `versions.env` at the project root — the single source of truth.
   - Use `python setup_deps.py --core` for just godot-cpp and Spout2 (skip ONNX, Python SDKs).
   - Use `python setup_deps.py --list` to see what would be fetched.
   - Run `python scripts/check_versions.py` to verify CI workflows match `versions.env`.
3. Open the project in **Godot 4.7.2** (stable).
4. The editor scene is `scenes/gn_editor.tscn` — run it to launch the GONODES editor.
5. Run tests:
   ```powershell
   godot --headless --path "C:\MeOwn\Gonodes" -s tests/test_runner.gd
   ```
6. No external dependencies are required for core GDScript development. The setup script is only needed if you want to build native C++ extensions.

---

## 4. Contributing a New Operator

This is the most common contribution type. Every new operator **must** include all of the following.

> **Full checklist:** See [NEW_OPERATOR_CHECKLIST.md](NEW_OPERATOR_CHECKLIST.md) for the complete step-by-step with derived-artifact commands.
> **Automated verification:** Run `python scripts/verify_new_operator.py <ClassName>` to validate all touchpoints.

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
    # Description lives in gn_core.cfg, NOT here

func _init_ports() -> void:
    # Every port MUST have a description (last argument)
    add_input("geo", GNFamily.Type.SOP, true, "Input geometry to process")
    add_output("out", GNFamily.Type.SOP, "Processed geometry output")

func _init_parameters() -> void:
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

    var strength: float = get_param_value("strength")
    # ... processing logic ...

    return geo
```

**Mandatory elements in `_init()`:**
- `node_type` — lowercase string identifier (unique across all operators)
- `family` — `GNFamily.Type.<FAMILY>`
- `time_dependent = true` only if the operator genuinely changes every frame
- **Do NOT set `node_description` here** — the description is defined in the `.cfg` file and injected at runtime by `gn_extension_registry.gd`

**Mandatory elements in `_init_ports()`:**
- Every `add_input()` and `add_output()` call must include a description string as the last argument.

**Mandatory elements in `_init_parameters()`:**
- Every `GNParameter.create_*()` call must include a description string as the last argument.
- Use sensible defaults and ranges.

### 4.2 Registry Entry

Add an entry to `addons/gonodes/gn_core.cfg` (INI format, one section per operator):

```ini
[operator.MyNewSOP]

family="SOP"
script="res://addons/gonodes/operators/sop/my_new_sop.gd"
description="Short sentence describing what this operator does."
```

The section name must match the `class_name` in your GDScript file. Place it near related operators alphabetically.

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

### 4.5 Verification

Run the automated checker to confirm nothing was missed:

```bash
python scripts/verify_new_operator.py MyNewSOP
```

The script checks: `.gd` file exists, metadata (`node_type`/`family`/`description`), `.cfg` registration, help patches present, `operator_registry.json` entry, `port_registry.json` entry, `docs/OPERATORS.md` listing, and test coverage.

To verify doc counts are consistent across all files:

```bash
python scripts/verify_new_operator.py --counts
```

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
├── presets/                  # Code/param presets (self-contained)
│   └── <folder>/
│       └── my_preset.glsl
└── help/                     # Help patches (self-contained)
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
# platforms = ["windows", "macos", "linux"]   # Optional: restrict to specific OSes
# architectures = ["x86_64", "arm64"]           # Optional: restrict to specific CPU architectures
# renderers = ["forward_plus", "mobile"]         # Optional: restrict to specific renderers
# dependencies = ["SomeNativeClass"]             # Optional: required GDExtension classes

[operator.MyOperatorTOP]
family = "TOP"
script = "res://addons/gn_ext_myext/operators/top/my_operator.gd"
description = "What this operator does"
```

Extensions are auto-discovered by the registry during editor startup via `scan_extensions()`. The `section` field groups your operators under a labeled section in the palette.

#### Optional `[extension]` Keys

| Key | Purpose |
|-----|---------|
| `platforms` | Array of OS names (`"windows"`, `"macos"`, `"linux"`, `"android"`, `"ios"`, `"web"`). Extension is skipped on non-matching OSes. Omit to load everywhere. Detected via `OS.get_name().to_lower()`. |
| `architectures` | Array of CPU architecture names (`"x86_64"`, `"x86_32"`, `"arm64"`, `"arm32"`, etc.). Extension is skipped on non-matching architectures. Omit to load on all architectures. Detected via `Engine.get_architecture_name()`. |
| `renderers` | Array of Godot renderer names (`"forward_plus"`, `"mobile"`, `"gl_compatibility"`). Extension is skipped if the active renderer doesn't match. Omit to load on all renderers. Detected via `GNGpuContext.get_current_renderer()`. |
| `dependencies` | Array of GDExtension class names. Extension is skipped if any class is missing from `ClassDB`. |

Checks run in order: platform → architecture → renderer → dependency. If any check fails, the extension is silently skipped.

### Native Binary Auto-Activation

Godot auto-discovers `.gdextension` files at engine startup — before any GDScript runs. If a `.gdextension` references a library that doesn't exist on disk, Godot logs noisy `GDExtension dynamic library not found` errors every time the editor starts. This is a common situation during development: you may have the GDScript operators written but haven't compiled the C++ yet, or you're working on a machine without the SDK installed.

The extension registry solves this with **auto-activation**. On every editor launch, `GNExtensionRegistry.sync_native_extensions()` (called from the plugin's `_enter_tree()`) scans **every subdirectory** inside each `gn_ext_*` folder for `.gdextension` and `.gdextension.disabled` files:

| Condition | Action |
|-----------|--------|
| Binary exists on disk + file is `.gdextension.disabled` | Rename to `.gdextension` (activate) |
| Binary missing + file is `.gdextension` | Rename to `.gdextension.disabled` (silence) |
| Binary exists + file is already `.gdextension` | No change |
| Binary missing + file is already `.disabled` | No change |

Since Godot loads GDExtensions before plugins run, changes take effect on the **next** restart. The console will print `[ExtRegistry] Activated native extension: ...` or `[ExtRegistry] Deactivated native extension ...` when a rename occurs, along with a reminder to restart.

This means:
- **Developing operators before compiling C++?** The `.gdextension` file is automatically disabled — no errors.
- **Just compiled the native library?** Next launch detects the binary and re-enables the `.gdextension`. One more restart loads it.
- **Deleted a binary?** Next launch deactivates the `.gdextension` automatically.

No manual file management needed. The `dependencies` guard in `gn_extension.cfg` still prevents operators from registering when the native class is absent, so even if the `.gdextension` were somehow left active without a binary, operators won't appear in the palette.

All the same rules apply to extension operators: descriptions, help patches, parameter tooltips.

### Extension Self-Containment Rule

**An extension must be entirely self-contained inside its `addons/gn_ext_<name>/` folder. Never place extension assets in `addons/gonodes/` or the project root.**

| Asset type | Where it lives |
|---|---|
| Operator scripts | `operators/<family>/` |
| Raw shader/code presets | `presets/<folder>/` (e.g. `presets/shadertoy/`, `presets/isf/`) |
| Parameter presets | `presets/params/` |
| Help patches | `help/<family>/` |
| Shared helper scripts | Root of extension folder (e.g. `depth_sensor_helper.gd`) |
| Textures, data files | Anywhere inside the extension folder |
| Native C++ source | `native/` |
| Third-party SDK binaries | `cef_artifacts/`, `native/bin/`, or similar — inside the extension |

**Why:** Core never imports from extensions. All coupling is through generic
registries (dictionaries keyed by string). Deleting an extension folder removes
all traces — operators, presets, help patches, native binaries, and runtime
registrations — without any orphaned references or broken imports.

**Code editor customization** (syntax highlighting, preset folders, "Edit ↗"
buttons) lives entirely in the extension's `boot.gd`. Core provides the
registration API (`GNCodeEditor.register_code_language()`,
`GNParamRow.register_code_param()`); extensions call it. Remove the extension
and the customization disappears.

**Viewer behavior** follows the same rule. Custom data display is achieved by
overriding `render_for_viewer()` on the operator or family base class. Input
forwarding uses the `handle_viewer_input()` virtual on `GNNode` — the
operator overrides it, not the viewer. The viewer has zero knowledge of
extension-specific types.

The core discovery systems find these automatically — no registration is needed:
- `gn_script_helper.get_preset_list()` scans `gn_ext_*/presets/<folder>/` for all installed extensions.
- `gn_help_window._find_example_patches()` scans `<extension_dir>/help/<family>/` alongside the core help directory.

### Shared Helper Pattern (for native extensions)

Extensions with native (C++) dependencies often need shared state across multiple operators (device caches, singleton access, common parameter logic). The recommended pattern:

1. **Create a static helper class** in the extension root (e.g. `depth_sensor_helper.gd` with `class_name GNDepthSensorHelper`)
2. **Use static variables** for cached data (backend lists, device lists) — shared across all operator instances
3. **Use static methods** for common operations (`is_available()`, `get_backends()`, device enum building)
4. **Provide a `rescan()` method** to clear caches when hardware changes at runtime
5. **Use `rescan_and_update_param(node)`** to refresh enum dropdown options + emit `parameters_changed` for live inspector updates

This avoids each operator independently querying the native layer and keeps device discovery centralized. See `gn_ext_depth_sensor/depth_sensor_helper.gd` for the reference implementation.

### Dynamic Device Menus (Pulse + _pre_cook pattern)

For operators that enumerate hardware devices, use a pulse parameter + `_pre_cook()` to allow runtime rescanning:

```gdscript
# In _init_parameters():
add_parameter(GNParameter.create_pulse("rescan", "Rescan Devices",
    "Re-enumerate connected devices and refresh dropdown"))

# In _pre_cook():
func _pre_cook(_delta: float) -> void:
    if get_param_value("rescan"):
        set_param_value("rescan", false)
        MyHelper.rescan_and_update_param(self)
```

The helper's `rescan_and_update_param()` should: clear caches, rebuild the enum options, clamp the selected index, and emit `parameters_changed` to trigger an inspector rebuild.
- Both systems use the same matching rules as their core counterparts.

> **Why this matters:** Placing extension assets in `addons/gonodes/` couples the extension to the core, makes it impossible to distribute the extension independently, and pollutes the core tree for users who do not want the extension.

### Platform & Renderer Compatibility for Extensions

GONODES has two orthogonal compatibility axes that extension authors must consider. These are **independent** of the cfg-level `platforms` guard — cfg guards control whether the *entire extension loads*; the operator-level overrides control whether *individual operators cook* on a given platform or renderer.

#### When to use which guard

| Scenario | Mechanism | Example |
|----------|-----------|---------|
| Entire extension is OS-specific (native .dll/.dylib) | `platforms` in `gn_extension.cfg` | Spout (Windows), Syphon (macOS) |
| Entire extension needs a C++ class at runtime | `dependencies` in `gn_extension.cfg` | FFmpeg (`FFmpegVideoStream`), GPU Encode (`GNGpuEncoder`) |
| Individual operator needs GPU compute shaders | Override `supported_renderers()` in operator | Compute shader ops, particle systems |
| Individual operator needs local filesystem or CLI | Override `supported_platforms()` in operator | File I/O, FFmpeg CLI, video capture |
| Operator works everywhere but adapts behavior | No override — detect platform internally | WindowOUT (multi-window on desktop, single on mobile/web) |

#### Axis 1 — Renderer compatibility (`supported_renderers`)

Override this when your operator depends on **GPU capabilities** that aren't available on all renderers.

```gdscript
## Requires compute shaders (Vulkan / Metal only).
func supported_renderers() -> PackedStringArray:
    return PackedStringArray(["forward_plus", "mobile"])
```

When to override:
- Operator uses `RenderingDevice` API (compute shaders, SSBO, image load/store)
- Operator uses `RenderSceneBuffersRD` (depth/normal buffer access via compositor)
- Operator uses Vulkan-specific features not in OpenGL 3.3 / WebGL2

When **not** to override:
- `shader_type canvas_item` fragment shaders — these work on ALL renderers
- CPU-only processing (CHOP math, DAT parsing, SOP mesh ops)
- Godot scene tree features (Camera3D, Light3D, Control nodes)

The three possible values: `"forward_plus"`, `"mobile"`, `"gl_compatibility"`.

Default (no override) = all three renderers.

#### Axis 2 — Platform compatibility (`supported_platforms`)

Override this when your operator depends on **OS-level features** not available everywhere.

```gdscript
## Needs local filesystem — not available on web.
func supported_platforms() -> PackedStringArray:
    return PackedStringArray(["windows", "macos", "linux", "android", "ios"])
```

```gdscript
## Desktop-only — requires OS.execute() for CLI tools.
func supported_platforms() -> PackedStringArray:
    return PackedStringArray(["windows", "macos", "linux"])
```

Platform capabilities reference:

| Capability | Desktop | Android/iOS | Web |
|------------|---------|-------------|-----|
| Local filesystem (`FileAccess`) | ✓ | ✓ (scoped) | ✗ |
| CLI execution (`OS.execute()`) | ✓ | ✗ | ✗ |
| Multiple OS windows (`Window.new()`) | ✓ | ✗ | ✗ |
| Threads (`Thread.new()`) | ✓ | ✓ | ✗¹ |
| MIDI hardware | ✓ | ✓² | ✗ |
| Webcam/capture devices | ✓ | ✗³ | ✗ |
| UDP/TCP networking | ✓ | ✓ | ✗⁴ |

¹ Web supports threads only with SharedArrayBuffer + COOP/COEP headers.
² Android MIDI requires API 23+.
³ Possible via Android Camera2 API but not via current native libraries.
⁴ Web can use WebSocket but not raw UDP/TCP.

The six possible values: `"windows"`, `"macos"`, `"linux"`, `"android"`, `"ios"`, `"web"`.

Default (no override) = all six platforms.

#### How the cook engine handles incompatible nodes

When a node fails a renderer or platform check during `cook_frame()`:
1. `node_warning` is set (yellow WRN badge in editor)
2. `cook_valid = false`
3. `cook_time_ms = 0`
4. `cached_output` retains its last value (or null if never cooked)
5. Downstream nodes receive null — they handle this like a disconnected input
6. A warning is logged once (frame 0) and emitted via `cook_error`

The node is **not deleted** — it stays in the graph. If the user later exports to a compatible platform, it will cook normally.

> **For the full list of error vs warning triggers**, see the user-facing
> [Troubleshooting — Node Errors & Warnings](../addons/gonodes/help/troubleshooting.md#node-errors--warnings).

#### Platform-adaptive operators (preferred over restriction)

When possible, make your operator **adapt** to the platform rather than refusing to run. Example: WindowOUT works everywhere but changes its display strategy:

```gdscript
func _cook(inputs: Array[GNData]) -> GNData:
    var platform := GNGpuContext.get_current_platform()
    if platform in ["android", "ios", "web"]:
        _setup_main_viewport_display()   # Single-window fallback
    else:
        _setup_window_display()          # Full OS window
```

This keeps patches portable — the same `.gnpatch` works on every platform without rewiring.

#### Quick reference — existing operator overrides

| Operator | `supported_renderers()` | `supported_platforms()` | Reason |
|----------|------------------------|------------------------|--------|
| POP family (10) | `forward_plus`, `mobile` | all | GPU compute |
| VOL family (11) | `forward_plus`, `mobile` | all | GPU compute |
| ComputeShaderTOP | `forward_plus`, `mobile` | all | GPU compute |
| CompositorEffectTOP | `forward_plus` | all | RenderSceneBuffersRD |
| FFmpegOUT | all | `windows`, `macos`, `linux` | Needs `OS.execute()` |
| FFmpegInTOP | all | desktop + mobile | Needs file access |
| VideoDeviceInIMG | all | `windows`, `macos`, `linux` | Native capture APIs |
| RtMidiInCHOP | all | desktop + mobile | No MIDI on web |
| RtMidiOutCHOP | all | desktop + mobile | No MIDI on web |
| File I/O (11 ops) | all | desktop + mobile | No FileAccess on web |
| WindowOUT | all | all | Platform-adaptive (not restricted) |

---

### Active Input Indices — Selective Upstream Cooking

By default, the cook engine's active-set BFS follows **all** wire connections
upstream from a node. Some operators only read a subset of their inputs depending
on their current parameter state — Switch (only selected index), CubeMapIMG
(only input 0 in Extract/Equirect mode), MathCHOP (only input 0 for unary ops).

If you don't declare which inputs are active, the cook engine will cook **all**
upstream chains even if your operator ignores some inputs. This wastes CPU/GPU.

#### Override `get_active_input_indices()`

```gdscript
## Returns port indices that are consumed this cook.
## Empty array (default) = ALL connected inputs are active.
## PackedInt32Array([0]) = only input 0 is active.
## PackedInt32Array([-1]) = NO inputs are active (sentinel).
func get_active_input_indices() -> PackedInt32Array:
    var idx: int = get_param_value("index")
    return PackedInt32Array([idx])
```

The cook engine calls this during `_compute_active_set()` BFS and skips
connections to non-active ports. The result is that upstream chains only cook
when the operator actually reads from them.

#### When to override

- **Switch-type operators** — only the selected input feeds through
- **Mode-dependent operators** — e.g., CubeMapIMG in Extract mode only uses input 0
- **Unary/binary operators** — e.g., MathCHOP in unary mode only uses input 0
- **No-input modes** — e.g., JSONDAT in Parse mode ignores all wired inputs

#### Sentinel values

| Return value | Meaning |
|---|---|
| `PackedInt32Array()` (empty) | All inputs active (default) |
| `PackedInt32Array([0])` | Only input 0 active |
| `PackedInt32Array([0, 1])` | Inputs 0 and 1 active |
| `PackedInt32Array([-1])` | No inputs active (sentinel — node generates data internally) |

#### Parameter changes trigger recomputation

When any parameter changes, the cook engine marks `_active_set_dirty = true`
via `_on_node_param_changed`. This means switching a Switch node's `index`
parameter immediately recomputes which upstream chains are active — no manual
invalidation needed.

When the index is expression-driven, the engine uses the previous frame's
`resolved_value` for active-set BFS (since expressions are evaluated during
the cook loop, after active-set computation).  A routing snapshot in
`_cook_single_node` detects when the expression result changes and sets
`_active_set_dirty` for the next frame.  This introduces a **1-frame
latency** for expression-driven routing changes — matching TD/Houdini
behaviour.  During the transition frame, `_cook()` returns `cached_output`
(hold last frame) to avoid a flash.

#### Existing operator overrides

| Operator | Active behavior |
|----------|----------------|
| SwitchTOP/CHOP/SOP/DAT/COMP + IMG/POP/VOL/MAT/UI/SDF | `[selected_index]` |
| CubeMapIMG | Assemble=all, Extract/Equirect=`[0]` |
| MathCHOP | Unary ops=`[0]`, binary ops=all |
| JSONDAT | Parse mode=`[-1]` (none), Generate=all |

---

### Extension Capabilities — What Extensions Can Do

The extension system goes well beyond adding operators to existing families. Extensions can **define entirely new data families** — introducing new port types, wire colors, data classes, and palette sections without modifying any core code.

#### Defining a New Family

Add a `[family.<NAME>]` section to `gn_extension.cfg`:

```ini
[extension]
name = "My Custom Family"
section = "MyFamily"

[family.MYTYPE]
color = "0.2,0.8,0.4"
data_script = "res://addons/gn_ext_myext/core/my_data.gd"

[operator.GeneratorMYTYPE]
family = "MYTYPE"
script = "res://addons/gn_ext_myext/operators/generator.gd"
description = "Generates custom data"
```

The registry calls `GNFamily.register_family("MYTYPE", Color(0.2, 0.8, 0.4))` which:
- Assigns a runtime ID (≥ 1000) — interchangeable with core enum values throughout all APIs
- Stores the display name in `GNFamily.FAMILY_NAMES[id]` → `"MYTYPE"`
- Stores the wire color in `GNFamily.FAMILY_COLORS[id]`
- Loads `data_script` and registers a data factory via `GNFamily.register_data_factory()`
- Registers the name for `@input`/`@output` annotation parsing in script nodes via `GNScriptHelper.register_script_family()`

The **palette**, **wire colors**, **port compatibility**, **drop-wire-to-add-node filtering**, and **auto-connect** all work automatically for the new family. The SDF extension (`gn_ext_sdf/`) is the reference implementation — 40+ operators across a custom family with its own data type.

#### What Works Automatically for Extension Families

| Feature | Status | How |
|---------|--------|-----|
| Named family ID | ✅ | `GNFamily.FAMILY_NAMES[id]` returns the registered name |
| Wire color | ✅ | `GNFamily.get_color(id)` returns the registered color |
| Palette section | ✅ | Palette iterates `GNFamily.FAMILY_NAMES` dynamically |
| Port compatibility | ✅ | `port.family` is `int` — direct equality check |
| Drop-wire filtering | ✅ | `get_operators_accepting_family()` works with any int ID |
| Auto-connect | ✅ | Port matching is simple equality — no special handling |
| Custom data class | ✅ | `register_data_factory()` → used by script nodes for `# @output` |
| Script annotations | ✅ | `# @input mytype` / `# @output mytype` work after registration |
| Help patches | ✅ | Auto-discovered from `<ext_dir>/help/<family>/` |
| Presets | ✅ | Auto-discovered from `<ext_dir>/presets/<folder>/` |

#### Extension UI Integration Registries

Core UI components provide static registries so extensions can integrate without
modifying core code. Extensions register their hooks from a `boot_script` declared
in `gn_extension.cfg`, which the extension registry calls after loading operators.

**1. Viewer Panel** (`gn_viewer_panel.gd`)

Extensions customize viewer rendering by overriding `render_for_viewer(viewer)` on
their operator or family base class. The viewer provides `set_texture()`, `set_control()`,
`set_info()`, `get_3d_viewport()`, `set_info_bar()`, and `set_info_overlay()` as
display methods. No boot registration is needed for viewer display.

**2. Code Editor** (`gn_code_editor.gd`)

`GNCodeEditor.register_code_language(param_name, config)` — extensions register a
Dictionary with `"preset_folder"`, `"highlighter"` (Callable), and `"ref_text"` keys.
The code editor uses this to provide syntax highlighting, preset load/save, and
reference text for extension-defined code parameters.

**3. Param Row** (`gn_param_row.gd`)

`GNParamRow.register_code_param(param_name)` — extensions register parameter names
that should get the windowed code-editor "Edit" button in the inspector.

**Boot script example** (`gn_extension.cfg`):
```ini
[extension]
name="My Extension"
boot_script="res://addons/gn_ext_mine/boot.gd"
```

```gdscript
# boot.gd
extends RefCounted

static func boot() -> void:
    GNParamRow.register_code_param("my_code")
    GNCodeEditor.register_code_language("my_code", {
        "preset_folder": "my_ext",
        "highlighter": _apply_highlighter,
        "ref_text": "my_var, my_func()",
    })

static func _apply_highlighter(code_edit: CodeEdit) -> void:
    var h := CodeHighlighter.new()
    # ... configure highlighter ...
    code_edit.syntax_highlighter = h
```

> **Principle:** The goal is for extensions to be fully self-contained and able to extend even core UI capabilities. The palette, wire system, port system, and cook engine are already fully extensible. The viewer and code editor need the registry pattern applied to reach the same level.

---

## 6. User Native C++ Nodes (gn_ext_user_native)

GONODES ships a hot-reloadable C++ scripting system in `addons/gn_ext_user_native/` that lets end users write native-speed operators directly inside the editor. This section is for **contributors modifying the user_native infrastructure itself** — not for end users writing C++ nodes (see the in-editor help or `addons/gn_ext_user_native/README.md` for that).

### Architecture

```
User writes .h file (extending gn::GNUserNode)
        ↓
GNNativeCompiler (core/gn_native_compiler.gd)
  ├─ SCons build (primary) or direct compiler fallback (MSVC/GCC/Clang)
  ├─ Links against godot-cpp (cloned by `setup_deps.py` → GODOT_CPP_PATH env → gn_ext_native/)
  └─ Produces .dll/.so/.dylib
        ↓
GNNativeReloader (core/gn_native_reloader.gd)
  ├─ Unloads old GDExtension
  ├─ Loads new GDExtension via GDExtensionManager
  └─ ClassDB.instantiate(class_name) → new processor
        ↓
GDScript Wrapper (operators/sop/user_native_sop.gd etc.)
  ├─ Calls _processor.native_setup(context)   ← once after load
  ├─ Calls _processor.native_cook(params, inputs, context)   ← each dirty frame
  ├─ Calls _processor.get_port_definitions()   ← dynamic I/O
  └─ Calls _processor.get_param_definitions()  ← dynamic params
```

### Lifecycle methods

| Method | Signature | When called |
|--------|-----------|-------------|
| `native_setup(context)` | `void native_setup(const Dictionary &context)` | Once after instantiation + after each hot-reload |
| `native_cook(params, inputs, context)` | `Dictionary native_cook(const Dictionary &params, const Array &inputs, const Dictionary &context)` | Each frame the node is dirty |
| `get_port_definitions()` | `Array get_port_definitions()` | After setup, to define inputs/outputs |
| `get_param_definitions()` | `Array get_param_definitions()` | After setup, to define user parameters |

### SDK headers (in `sdk/`)

| Header | Purpose |
|--------|---------|
| `gn_user_node.h` | Base class + lifecycle + param reader helpers (`parf`, `pari`, `parb`, `pars`, `parc`, `parv3`) |
| `gn_user_types.h` | Type aliases + param definition factories (`gn::parf()`, `gn::pari()`, `gn::make_vector3()`, `gn::make_multi_output()`, etc.) |
| `gn_user_sop.h` | SOP output helpers (`make_sop_result()`, `make_point_cloud()`) |
| `gn_user_chop.h` | CHOP output helpers (`make_chop_single()`, `make_chop_result()`) |
| `gn_user_img.h` | IMG output helpers (`make_img_result()`, `get_input_image()`) |
| `gn_user_top.h` | TOP output helpers (`make_top_shader_result()`, `make_top_image_result()`) |
| `gn_user_dat.h` | DAT output helpers (`make_dat_table()`, `make_dat_text()`) |
| `gn_user_sdf.h` | SDF tree construction — primitives, booleans, modifiers, materials (extension SDK) |

### Multi-output support

C++ and Python script nodes support multi-output via a `{"outputs": [dict0, dict1, ...]}` return from `native_cook()` / `cook()`. The wrapper detects the `"outputs"` key and routes each element to `_build_output_for_port()`. Use `gn::make_multi_output()` (C++) or `make_multi_output()` (Python) to build the return dict. Per-port data is cached in `_output_data[]` and served via `get_output_data(port_index)`.

### Extension family SDK pattern

Extension families (SDF, etc.) can ship SDK headers/modules in the existing SDK directories:
- C++ headers in `addons/gn_ext_user_native/sdk/` (auto-included via `{sdk_path}`)
- Python modules in `addons/gn_ext_user_python/sdk/gonodes/` (auto-imported via `sys.path`)

The generic marshalling in `native_script.gd` and `python_script.gd` (`_marshal_extension()` / `_build_extension()`) handles serialization for any family registered with `GNFamily.register_data_factory()`.

### Vector3 parameter handling

GNParameter has **no `create_vector3()`**. Vector3 params must be split into 3 float params with `_x`/`_y`/`_z` suffixes. The wrapper operators handle this automatically via `_add_vector3_params()` (splitting) and `_gather_user_params()` (reassembling). If you add a new param type to the SDK, you must update **all 5 wrapper operators**.

### Modifying the build system

Two build paths exist:
1. **SCons** (primary) — uses godot-cpp's SConstruct
2. **Direct compiler** (fallback) — invokes MSVC/GCC/Clang directly with hardcoded flags

Both live in `gn_native_compiler.gd`. The CLI equivalent is `build_user_node.py`. Changes to compiler flags or godot-cpp discovery must be mirrored in both files.

### Release impact

Any changes to the SDK headers, build system, or wrapper operators affect the release process:
- SDK header changes → update `toolchain/README.md`, examples, templates
- Build system changes → update both `gn_native_compiler.gd` and `build_user_node.py`
- New param types → update all 5 wrappers + SDK `gn_user_types.h`
- godot-cpp version changes → update branch in `setup_deps.py` + re-run + re-bundle in `toolchain/godot-cpp/` (see `RELEASE_CHECKLIST.md` Phase 3)

---

## 7. Code Style & Conventions

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
var res := clampi(get_param_value("resolution"), 4, 128)

# Bad — restates the code
# Set res to the resolution parameter value
var res := get_param_value("resolution")
```

- Keep `_cook()` methods focused. Extract helper methods for complex algorithms.
- Use early returns for error/null-input cases at the top of `_cook()`.
- Prefer `var x: Type` explicit typing for function parameters and return types.
- Use `push_warning()` for recoverable issues, `push_error()` for bugs.

### Family Base Classes

Every operator must extend the correct family base class.
**Preview dispatch is handled by GNNode** — it detects the output data type
automatically, so family bases and individual operators do NOT need preview
overrides unless they have non-data state to display (COMP, UI, OUT).

| Family | Base Class | Output Type |
|--------|-----------|-------------|
| TOP | `GNTopBase` | `GNTextureData` |
| CHOP | `GNChopBase` | `GNChannelData` |
| DAT | `GNDatBase` | `GNTableData` |
| SOP | `GNSopBase` | `GNGeoData` |
| COMP | `GNCompBase` | `null` (Node3D via API) |
| MAT | `GNMatBase` | `GNMaterialData` |
| IMG | `GNImgBase` | `GNImageData` |
| UI | `GNUiBase` | `null` (Control via API) |

### Thread Safety

The cook engine supports optional parallel cooking (`GNNetwork.multithreading_enabled`).
By default, `GNNode.thread_safe = true`. Override it to `false` in `_init()` for operators
that use external I/O, hardware handles, or non-reentrant APIs:

```gdscript
func _init() -> void:
	thread_safe = false   # Uses hardware I/O — must cook on main thread
```

All I/O-bound operators (audio input, MIDI, serial, OSC, webcam, NDI, Spout, etc.)
should set `thread_safe = false`. The cook engine serialises these into a single-threaded
batch while still running safe operators in parallel.

---

## 8. Documentation Requirements

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

## 9. Help System Integration

The in-editor Help window discovers `.gnpatch` files by scanning `addons/gonodes/help/<family>/` (core) **and** each extension's `help/<family>/` directory at runtime. No manifest or registration is needed — just drop the file in the right folder (following the Extension Self-Containment Rule above).

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

## 10. Testing Requirements

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

## 11. Hard Rules -- Non-Negotiable

These rules are absolute constraints discovered during development. Violations will block acceptance.
The machine-readable terse form lives in `.github/copilot-instructions.md` §25.
**Rule 25.39:** Every rule in copilot-instructions.md must have a human-readable entry here.

---

### 25.1 -- No CPU Roundtrips for Real-Time Texture Data

**NEVER** call `Texture2D.get_image()` or `Image.get_data()` in a per-frame code path.
This triggers a GPU->CPU readback that stalls the render pipeline (5-15 ms per call).
Use `ViewportTexture` (live GPU reference) for all real-time texture routing.

**Why it matters:** A single `get_image()` call in a time-dependent node running at 60 fps
causes 300-900 ms of cumulative stalls per second.

---

### 25.2 -- Expression base_instance Architecture

Functions called inside a Godot `Expression` are method lookups on `base_instance`, not
input variables. Passing `Callable` objects as input variables silently fails.
Always implement expression-callable functions as real methods on the `base_instance` object.

---

### 25.3 -- GNFamily.get_name -> get_family_name

Never define a method called `get_name()` on any GNFamily subclass or related object.
`Object.get_name()` is a built-in that returns the Node's scene-tree name. Shadowing it
breaks all code that calls `node.get_name()`. Use `get_family_name(family)` instead.

---

### 25.4 -- WindowOUT Cook-Dirty vs Param-Dirty

Do NOT use `if dirty:` to gate window configuration code in WindowOUT. The `dirty` flag
is true every single frame when upstream is time-dependent. Use a dedicated
`_window_params_dirty` flag that is only set in `_on_parameter_changed()`.

---

### 25.5 -- Anchors: set_anchors_and_offsets_preset

`Control.anchors_preset = PRESET_FULL_RECT` only sets anchor ratios -- it does NOT update
the offsets. Result: the control stays 0x0 pixels. Always call
`set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER the control is added to
the scene tree.

---

### 25.6 -- embed_subwindows = false for Real OS Windows

`project.godot` must have `window/subwindows/embed_subwindows=false` for `WindowOUT` to
create real OS-level output windows. Without this setting, Godot embeds all sub-windows
inside the main window and WindowOUT cannot produce independent output displays.

---

### 25.7 -- DisplayServer API

Use `DisplayServer.screen_get_size()` / `DisplayServer.screen_get_position()`.
The legacy `get_screen_size()` method does not exist in Godot 4.6.
For per-window vsync: `DisplayServer.window_set_vsync_mode(mode, window_id)`.

---

### 25.8 -- GraphEdit Signal Naming

`GraphEdit` has built-in signals named `node_selected` and `selection_cleared`.
Custom signals with those names will conflict silently. Use distinct names
(`operator_selected`, `operator_deselected`, etc.) for any custom selection signals.

---

### 25.9 -- Inspector Per-Cook Updates

Never push text into a focused editor widget during cook -- it will clobber the user's
in-progress edits at 60 Hz. Use a lightweight `update_expression_status()` call that
only updates status indicators, and always check `_expr_edit.has_focus()` before
touching text content.

---

### 25.10 -- Dynamic Input Ports (Auto-Grow)

Variable-input operators (Merge*, Switch*, RenderTOP) must call `_enable_dynamic_inputs()`
in `_init_ports()`. The system then auto-adds a trailing empty slot on connect and
auto-removes it on disconnect. Operators must handle `null` inputs for disconnected ports.
Do NOT use the old `num_inputs` parameter pattern.

---

### 25.11 -- COMP Nodes: Scene-Node Ownership, Proxy Fan-Out

COMPs return `GNCompData` wrapping a reference to their singleton `_scene_node`.
Scene-node resolution always uses `cached_output as GNCompData` (data-type check,
never node-family check). When a COMP fans out to multiple consumers, the first adopts
the original node; subsequent consumers get proxies via `GNProxyTree` that share GPU
resources. See `COOK_ENGINE.md` for the proxy lifecycle.

---

### 25.12 -- SubViewport World3D Isolation

`RenderTOP` must assign `SubViewport.world_3d = World3D.new()` before adding the viewport
to the scene tree. Without this, 3D content bleeds into the Godot editor viewport.
Do NOT use `own_world_3d = true` -- it causes a duplicate-World3D crash with Jolt physics.

---

### 25.13 -- Lazy Cook / No Unnecessary Work

A node must not cook if nothing changed. Never set `time_dependent = true` unless the
operator's output genuinely differs every frame (clocks, random with per-frame seed, live
input). Unnecessary `time_dependent = true` forces every downstream node to cook every
frame regardless of whether anything is connected to a sink.

---

### 25.14 -- Descriptions and Labels Mandatory

Every operator needs:
1. `description=` in its `.cfg` entry (shown in the palette tooltip and help docs)
2. A description string on every `add_input()` / `add_output()` call
3. Non-empty label AND description on every `GNParameter.create_*()` call

Empty labels cause blank rows in the inspector. Empty descriptions leave tooltips and
generated help pages incomplete.

---

### 25.15 -- Dynamic Port Counts

Use `set_input_count(count, family, prefix, desc)` / `set_output_count(...)` to
programmatically change port counts. These methods rebuild port arrays and emit
`ports_changed(node_id)` so the graph editor prunes stale wires automatically.
Prefer `_enable_dynamic_inputs()` for Switch/Merge-style operators (auto-grow).

---

### 25.16 -- Canvas Anchoring in TOP SubViewports

After calling `add_child(_canvas)`, call
`_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.
In `_cook()`, only set `_viewport.size = res` -- the canvas follows via anchors.
Applies to all 21 SubViewport-based TOP operators.

---

### 25.17 -- Viewer Panel Sizing

Use `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` (value 1) and
`stretch_mode = KEEP_ASPECT_CENTERED` (value 5). Set `clip_contents = true` and a small
`custom_minimum_size.y` so the viewer does not collapse to zero height.

---

### 25.18 -- Node Renaming Full Chain

On rename: update the `nodes` dict key, `GNNode.id`, `GNNode.name`, all `GNConnection`
references, and all expression strings (regex path-segment replacement in params,
`component_expressions`, scripts, `CallbackDAT` slots). Emit `node_renamed` at the end.
Node IDs must match `^[a-zA-Z_][a-zA-Z0-9_]*$`.

---

### 25.19 -- GNNode Lifecycle

- `_init()` -- sets `node_type`, `family`, `node_description`. No ports, no parameters.
- `initialize(id)` -- calls `_init_ports()` + `_init_parameters()`, wires param signals.
  Use this for all live network nodes.
- For palette/introspection only: call `node._init_ports()` explicitly after `.new()`.
  Do NOT call `initialize()` for introspection nodes.
- When an operator script is deleted or renamed, also delete the orphaned `.gd.uid`
  sidecar file -- Godot does not clean these up.

---

### 25.20 -- Editor/Engine Separation

`core/` and `operators/` must NEVER import or reference `ui/`. The cook engine and all
operators must run headless. No `preload()` / `load()` of any `ui/` path from engine code.

---

### 25.21 -- Help Example Patches Required

Every operator must ship at least one `.gnpatch` in `help/<family>/`.
Naming: `<node_type>_<label>.gnpatch`. Must use `class_name` in the `type` field.
Keep patches to 1-4 nodes, max ~3 patches per operator.
See [HELP_PATCH_RULES.md](HELP_PATCH_RULES.md) for the complete format specification.

---

### 25.22 -- Help Patch Sink Rule (WindowOUT Chain by Family)

Every help patch must terminate at `WindowOUT` (512x512, `open: true`) via:

| Family | Chain to WindowOUT |
|--------|--------------------|
| TOP | direct |
| IMG | ImgToTOP -> WindowOUT |
| CHOP | CHOPtoTOP -> WindowOUT |
| SOP | GeometryCOMP + CameraCOMP -> RenderTOP -> WindowOUT |
| COMP (scene) | + CameraCOMP -> RenderTOP -> WindowOUT |
| DAT | TextTOP -> WindowOUT |
| MAT | GeometryCOMP (MAT port 1) + CameraCOMP -> RenderTOP -> WindowOUT |

---

### 25.23 -- UTF-8 Encoding: No PowerShell String Manipulation

All text files are UTF-8 without BOM. Never use PowerShell `Get-Content` / `Set-Content`
on files with non-ASCII characters without `-Encoding UTF8` on BOTH calls. PowerShell
defaults to Windows-1252, causing double-encoding corruption (`--` becomes `Ã¢â‚¬â€`).
**Prefer Python** for any text file manipulation involving non-ASCII characters.

---

### 25.24 -- Multi-Output Demand Gating

When an operator has 2+ output ports:
- **Shared core** (e.g., parsing, GPU dispatch) runs unconditionally.
- **Per-port work** (extraction, readback, mesh building) is guarded by `is_output_demanded(N)`.
- Override `get_output_data(port_index)` to route each port to its cached result.

Demand sources: wire connections, wireless Select operators, expression references.
No port is auto-demanded. Exceptions (comment with `# MULTI-OUTPUT EXCEPTION:`):
coupled physics sims, GPU MRT. See [COOK_ENGINE.md](COOK_ENGINE.md) for code examples.

---

### 25.25 -- Shared Logic in Base Classes, Not Subclasses

When 2+ operators share helper logic, move it to the family base class
(`GNCompBase`, `GNTopBase`, etc.) or to `GNNode`. Never duplicate utility methods across
operator subclasses. Check the base class first -- the method may already exist.

---

### 25.26 -- Check Data Types, Not Node Families

When consuming upstream output, check the **data type**:

```gdscript
# Correct
var tex: GNTextureData = inputs[0] as GNTextureData
var chop: GNChannelData = data as GNChannelData

# Wrong -- silently rejects valid data from SubNetworkNode, custom ops
if node.family == GNFamily.Type.TOP: ...
if node is GNTopBase: ...
```

Data-type checks work uniformly for `SubNetworkNode`, `GNCustomOperator`, and any future
node that outputs the right data type regardless of its family. See [DATA_TYPES.md](DATA_TYPES.md).

---

### 25.27 -- COMP Proxy Bookkeeping for New Node Types

When adding a new COMP that creates a visual `_scene_node`, check
`GNProxyTree._create_proxy_node()` to add a typed proxy factory for it. Unknown types
become plain `Node3D` placeholders. Currently proxied: MeshInstance3D, MultiMeshInstance3D,
Camera3D, DirectionalLight3D, OmniLight3D, SpotLight3D. New visual types (GPUParticles3D,
Decal, etc.) need a factory + sync method + test in `tests/unit/core/test_proxy_tree.gd`.

---

### 25.28 -- Family-Output Coherence (Port 0 = Family Identity)

An operator's family must match its primary output (port 0) data type. A CHOP emits
`GNChannelData`, a TOP emits `GNTextureData`, etc. If a node consumes family X but outputs
family Y, it belongs to family Y and should be named to indicate the conversion
(`CHOPtoTOP`, `MarchingCubesSOP`). Never embed a silent cross-family conversion in a
non-bridge operator.

Exceptions: explicit bridge operators, multi-output operators where only secondary ports
(1+) emit a different family (guarded by Rule 25.24), NET host-bridge operators.

---

### 25.29 -- Native Extension Graceful Degradation

Extensions with GDExtension binaries must degrade gracefully when binaries are missing:
1. Ship `.gdextension.disabled` at extension root -- activated by `sync_native_extensions()` when binary exists.
2. Declare `dependencies = ["MyNativeClass"]` in `gn_extension.cfg` -- registry skips if `ClassDB.class_exists()` fails.
3. Never reference native class names directly in GDScript -- use `ClassDB.class_exists()` + `ClassDB.instantiate()` + `.call()`. Declare variables as `Object`, not the native type.

See [EXTENSIONS.md](EXTENSIONS.md) and [BUILD.md](BUILD.md) for the full build system flow.

---

### 25.30 -- node_type Uniqueness

Every operator's `node_type` must be a unique lowercase string. Never reuse the family
name as the node_type. Collisions break operator registry keying, help patch generation,
`op()` expression lookups, and palette search. Run `python scripts/check_node_types.py`
to detect duplicates before submitting.

---

### 25.31 -- No Pre-Release Compatibility Code

Before v1.0 ships, never add migration paths, compat shims, or fallback code for
internal-only features. Backward compatibility is only meaningful after a public release.
Code that says "kept for API compatibility" during development is dead weight -- remove it.

---

### 25.32 -- Stub API Functions Must Report Errors

Any public API function -- GDScript or C -- that is declared but not yet implemented must
set an error or warning, never return null/zero silently:
- GDScript: `push_warning("not implemented")` or `node_warning = "..."`
- libgonodes C API: `gn_set_error(inst, "...")` + appropriate error code

Silent null returns trap integrators who test for success and never detect the failure.

---

### 25.33 -- Scripts Must Not Hardcode Family Lists

Python build and utility scripts must never hardcode family name lists like
`["chop", "top", "sop"]`. Always read families from `operator_registry.json` or parse
`[family.*]` sections from config files. Hardcoded lists silently omit extension families
(SDF, FIX, future user families). Affected scripts: `catalog_operators.py`,
`extract_ports.py`, `fix_help_patches.py`, `generate_operator_tests.py`,
`verify_new_operator.py`. See [SCRIPTS.md](SCRIPTS.md).

---

### 25.34 -- Runtime DLLs: gdignore and Pre-loading

The `native/` subdirectory inside each extension has `.gdignore`, making any `res://` path
inside it unresolvable by Godot. DLLs listed in `.gdextension [dependencies]` (Godot
pre-loads them) and the main library itself must live outside `native/`. Use
`runtime_dlls_dest` and `library_dest = ../bin` in `build.cfg` to copy them to a
non-ignored location. DLLs loaded by Windows via `LOAD_WITH_ALTERED_SEARCH_PATH` (same
directory as the loading DLL) do not need pre-loading and may stay in `native/bin/`.
See [BUILD.md](BUILD.md).

---

### 25.35 -- Wireless Referencing: Only Select Nodes

Only `Select*` operators (`SelectCHOP`, `SelectTOP`, etc.) do wireless node referencing
via `create_node_ref` parameters. All other operators must use wired inputs. Select nodes
return the source node's `cached_output` directly -- no filtering. For transformation after
a wireless reference, wire into the corresponding filter operator (`ChannelFilterCHOP`,
`SubsetDAT`, `FilterSOP`).

---

### 25.36 -- Every Extension Must Have a README

Every `gn_ext_*` folder must contain a `README.md` with at minimum:
1. **Overview** -- one-paragraph summary of what the extension does
2. **Operators** -- table of `node_type`, class name, one-line description
3. **Directory Layout** -- annotated file tree

`scripts/verify_new_operator.py` warns about missing READMEs.

---

### 25.37 -- ConfigFile Must Be Pure ASCII, No Comments

`gn_core.cfg` and all `gn_extension.cfg` files must contain only ASCII characters
(U+0000-U+007F) and no comment lines (`# ...`). Godot 4.6's ConfigFile parser has two
silent bugs:
1. Any non-ASCII character anywhere in the file causes subsequent `[section]` headers to
   be swallowed -- their keys merge into the previous section.
2. Comment lines between sections cause the next `[section]` header to be skipped entirely.

Use ASCII substitutes: `--` not `---`, `->` not an arrow character, `x` not a
multiplication sign. Never use comments for documentation inside `.cfg` files.

---

### 25.38 -- Sideband Metadata via GNData.metadata, Not Graph Walking

Never walk the scene tree or network connections during `_cook()` to find a specific
upstream node type. During cook, nodes are reparented under `CookEngine` -- `get_parent()`
returns `CookEngine`, not `GNNetwork` -- so any connection lookup will always return null.

Use `GNData.metadata` instead:

```gdscript
# Producer (in _cook):
_cached_tex_data.metadata["fixture_manifest"] = _fixture_manifest
return _cached_tex_data

# Consumer (in _cook):
var manifest: Array = tex_data.metadata.get("fixture_manifest", [])
if manifest.is_empty():
    node_warning = "No manifest in input data."
    return null
```

All `duplicate_data()` overrides copy `metadata.duplicate(true)`, so metadata flows
through intermediate nodes (LevelTOP, subnets, SelectTOP) transparently.
See [DATA_TYPES.md](DATA_TYPES.md) §Sideband Metadata.

---

### 25.39 -- Rules Must Be Reflected in CONTRIBUTING.md

Every rule in `.github/copilot-instructions.md §25` must have a corresponding
human-readable entry in this section (§11 of CONTRIBUTING.md). When adding a new rule:
1. Add the terse imperative version to `copilot-instructions.md`.
2. Add the human-readable entry here with rationale and, where helpful, a code example.
3. Link to the relevant `dev_docs/` file for deeper context if one exists.

The copilot file is the machine-readable contract; this section is the human-readable
explanation. Both must stay in sync.

---

### 25.40 -- Single Source of Operator Counts

Operator totals and per-family counts must come from `python scripts/scan_operators.py`
(and `scripts/operator_registry.json`). The root `README.md` does not publish those
totals. Do not add a count table back to it, and do not hand-edit totals in TESTING,
competitor audits, or the copilot header without re-running the scanner. After adding
or removing operators, update the catalog and the other count surfaces in one pass.
Canonical human-facing totals live in the `docs/OPERATORS.md` header.

---

### 25.41 -- Core Must Not Type `ui/` class_names

Rule 25.20 forbids importing `ui/` from `core/` / `operators/`. Godot `class_name`
globals can still couple layers when core scripts type `GNInteractivePanel` (defined
under `ui/`). Prefer a core-owned protocol or untyped `Control`, with the concrete
interactive Control living in `ui/`. See `GNTopInteractiveBase` and
[EDITOR.md](EDITOR.md) (Interactive Panel Export).

---

### 25.42 -- Interactive Panel Views (Params as Source of Truth)

Secondary `panel` UI outputs on TOPs must:
1. Be demand-gated with `is_output_demanded(panel_port)`.
2. Treat **node params** as the sole source of truth.
3. Give the viewer overlay and WindowOUT each their own `GNInteractivePanel`
   instance (N interactive views, one model) — do not reparent a single Control
   between hosts, and do not clear the viewer overlay just because the panel
   port is demanded.
4. On drag: write params from the interacting view, then refresh all live views
   from params.

Prefer `GNTopInteractiveBase` + `add_panel_output()` over hand-rolled panel ports.
See [EDITOR.md](EDITOR.md) and [EXTENSIONS.md](EXTENSIONS.md).

---

### 25.43 -- Extension README Operator Tables Match `gn_extension.cfg`

Each `gn_ext_*/README.md` Operators table must list exactly the operators in that
extension's `gn_extension.cfg` (same class names; no operators from other
extensions). The root `README.md` does not list extensions. Do not add that table back.

---

### 25.44 -- GPU/CPU Family Boundary (TOP vs IMG)

Operators that require GPU-to-CPU readback belong in **IMG**, never TOP. Cross
the boundary only with explicit bridges (`TOPtoIMG` / `ImgToTOP`). Never call
`Texture2D.get_image()` inside a TOP `_cook()` for algorithm work (also 25.1).

---

### 25.45 -- Docs Must Stay In Sync With Code

Changing an operator's parameters, ports, behavior, supported formats, or public
APIs is incomplete until the docs match — in the **same** change, not later.

**Update at least:**
1. `docs/OPERATORS.md` — parameter table, I/O, and "How it works" for that operator
2. The operator's `.cfg` `description=` if the summary is now wrong
3. `GONODES_CONTEXT.md` / `ai/MEMORY.md` when the change is architectural

This applies to **modifying** existing operators (e.g. adding `load_mode`), not
only creating new ones. Verify with:

```bash
python scripts/verify_new_operator.py AudioFileInCHOP
```

See also §4.4 Documentation Update and the PR checklist below.

### 25.46 -- Multi-Stage Work Must Be Resumable At Every Stage

Any task spanning more than one working session — audits, migrations, family-wide
refactors, build campaigns — carries a resume record. **A stage is not complete
until that record is written**, including when the stage fails or stops early.

**Each stage closes with three writes:**

1. **Findings** appended to the task's own doc, every claim citing a file path or
   command output.
2. **Progress table** row set to the honest status: `DONE`, `PARTIAL`, `BLOCKED`,
   or `UNVERIFIED`. Never `DONE` for a stage whose evidence is incomplete.
3. **`## Resume here`** block, overwritten each time, holding:
   - last completed stage, and next stage with its first concrete action
   - exact commands to run, with working directory and shell caveats
   - files created and modified so far
   - **environment state that cost real time to reach** — which extensions are
     built, which templates exist, any long-running process
   - open questions awaiting the user
   - any deviation from the plan, with the reason

Keep the log in the task doc. Put only a **one-line pointer** in `ai/MEMORY.md` —
that file loads into every future session and must stay compact, so duplicating
task detail there taxes every unrelated piece of work.

**Acceptance test:** a fresh agent given only the task doc and the repo must be
able to resume without re-deriving prior findings or repeating an expensive build.
If the resume block does not meet that bar, the stage is not finished.

Current instance: `PRE-BETA_AUDIT.md`.

### 25.47 -- `llms.txt` Stays True

`llms.txt` at the repo root is the brief other people's language models read to write a `.gnpatch`. It is plain Markdown so every model can use it. There is no Cursor, Copilot, or Claude copy of the same text.

Update it in the same change when a sentence in it would be wrong afterward: the patch JSON shape, which families can connect, expressions, script annotations, feedback, sinks, or an operator the file names. Do not paste new operators or the operator count into it. The catalog remains `docs/OPERATORS.md`. A new parameter is documented there; `llms.txt` already tells the model to look it up.

### 25.48 -- Build Scripts and Guides Stay in Step

Changing how a library is fetched, where a probe looks, a `setup` or `vendor_clone` line, or a GitHub Actions download step is incomplete until the script and the written guide match. Do that in the same change.

**Scripts:** `setup_deps.py`, `scripts/show_manual_sdks.py`, `scripts/clone_vendor_sdk.py`, the extension `setup_*.py`, `native/build.cfg`, and `.github/workflows/release.yml` plus `build-extensions.yml`.

**Guides:** `dev_docs/BUILD.md`, the extension README, and `dev_docs/EXTENSIONS_AND_LICENSING.md` when one of its sentences would become false.

The paths printed by `scripts/show_manual_sdks.py` must be the same files `build.cfg` probes. Local setup and GitHub Actions both read `setup` (or `vendor_setup` when that older key is set) and `vendor_clone`.

---

## 12. Pull Request Checklist

Before submitting, verify every item:

### New Operator PR

- [ ] Operator script in `addons/gonodes/operators/<family>/`
- [ ] Extends the correct family base class
- [ ] `node_type` and `family` set in `_init()`
- [ ] `description=` present in the `.cfg` entry
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
- [ ] Relevant docs updated if behavior changed (Rule 25.45)

### Operator Modify PR (params / ports / formats / behavior)

- [ ] `docs/OPERATORS.md` parameter table and "How it works" updated
- [ ] `.cfg` `description=` still accurate
- [ ] `llms.txt` updated if a sentence in it is now false (Rule 25.47)
- [ ] `python scripts/verify_new_operator.py <ClassName>` passes
- [ ] Help patches still valid if ports/params changed meaningfully

### Core Engine PR

- [ ] Unit tests covering the change
- [ ] No regressions in existing tests
- [ ] `GONODES_CONTEXT.md` updated if architecture changed
- [ ] `llms.txt` updated if a sentence in it is now false (Rule 25.47)
- [ ] Hard rules respected (especially 25.13 lazy cook, 25.20 separation, 25.38 no graph walking)
- [ ] If adding a new rule, CONTRIBUTING.md §11 updated with human-readable entry (Rule 25.39)

### Build or SDK PR

- [ ] Download script, `build.cfg` probe, and guide updated together (Rule 25.48)
- [ ] `scripts/show_manual_sdks.py` paths match `build.cfg` probes
- [ ] GitHub Actions still run the same `setup` / `vendor_clone` lines as `setup_deps.py`

---

## 13. Architecture Guidelines

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
2. Create your shader in `addons/gonodes/shaders/top/` or inline.
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

### Adding a GPU Compute Shader Operator

For pixel-parallel operations (blur, edge detect, color transforms), use `ComputeShaderTOP` or write a custom TOP extending `GNTopBase` with `GNGpuContext`. IMG operators must remain CPU-only (`Image`-based). See `help/top/compute_gaussian_blur.gnpatch` and `help/top/compute_edge_filter.gnpatch` for example compute shader code.

### Spare Parameters

Any node can have user-added "spare" parameters via right-click → "Add Spare Parameter…". Spare parameters:

- Are stored in `gn_node.gd` → `spare_parameters: Dictionary`, separate from `_init_parameters()`.
- Support types: Float, Int, Bool, String, Color, Vector2, Vector2i.
- Are accessible via the same `get_param_value()` / `set_param_value()` API as regular params.
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

## 14. Common Pitfalls

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
