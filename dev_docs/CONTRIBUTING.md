# Contributing to GONODES

> **Last updated:** 2026-03-27  
> **Godot version:** 4.6.1 stable  
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
├── core/           # Engine: cook engine, network, data types, base classes, GNViewerRenderer
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
3. Open the project in **Godot 4.6.1** (stable).
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
- `time_dependent = true` only if the operator genuinely changes every frame
- **Do NOT set `node_description` here** — the description is defined in the `.cfg` file and injected at runtime by `gn_extension_registry.gd`

**Mandatory elements in `_init_ports()`:**
- Every `add_input()` and `add_output()` call must include a description string as the last argument.

**Mandatory elements in `_setup_parameters()`:**
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

**Viewer behavior** follows the same rule. Custom data display goes through
`GNViewerPanel.register_display_handler()` in the boot script. Input
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
on their current parameter state — Switch (only selected index), CubeMapTOP
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
    var idx: int = get_parameter_value("index")
    return PackedInt32Array([idx])
```

The cook engine calls this during `_compute_active_set()` BFS and skips
connections to non-active ports. The result is that upstream chains only cook
when the operator actually reads from them.

#### When to override

- **Switch-type operators** — only the selected input feeds through
- **Mode-dependent operators** — e.g., CubeMapTOP in Extract mode only uses input 0
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
| SwitchTOP/CHOP/SOP/DAT/COMP | `[selected_index]` (blend mode: all) |
| CubeMapTOP | Assemble=all, Extract/Equirect=`[0]` |
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

`GNViewerPanel.register_display_handler(data_class_name, handler_callable)` — extensions
register a `Callable(output: GNData, viewer: GNViewerPanel)` that the viewer calls
when the pinned node's output matches the registered class name. Handlers use
`viewer.show_info()` or `viewer.show_texture()` to display content.

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
| `gn_user_types.h` | Type aliases + param definition factories (`gn::parf()`, `gn::pari()`, `gn::make_vector3()`, etc.) |
| `gn_user_sop.h` | SOP output helpers (`make_sop_result()`, `make_point_cloud()`) |
| `gn_user_chop.h` | CHOP output helpers (`make_chop_single()`, `make_chop_result()`) |
| `gn_user_img.h` | IMG output helpers (`make_img_result()`, `get_input_image()`) |
| `gn_user_top.h` | TOP output helpers (`make_top_shader_result()`, `make_top_image_result()`) |
| `gn_user_dat.h` | DAT output helpers (`make_dat_table()`, `make_dat_text()`) |

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

Every operator must provide: (1) a `description=` field in its `.cfg` entry (single source of truth, injected at runtime), (2) description string on every `add_input()`/`add_output()` call, (3) description string on every `GNParameter.create_*()` call.

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
