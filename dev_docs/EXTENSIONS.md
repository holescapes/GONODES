# GONODES Extension System — Internals

> **Audience:** Extension authors, core developers.
> **User-facing version:** `addons/gonodes/help/extensions.md` (accessible via in-editor Help window)
> **Authoring quick-start:** `dev_docs/CONTRIBUTING.md` §5

This document covers the full extension architecture: manifest loading,
operator registration, family registration, boot scripts, UI registry hooks,
platform/architecture/renderer guards, and the dependency system.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Manifest Format (gn_extension.cfg)](#2-manifest-format)
3. [Loading Pipeline](#3-loading-pipeline)
4. [Family Registration](#4-family-registration)
5. [Boot Scripts](#5-boot-scripts)
6. [UI Registries](#6-ui-registries)
7. [Platform, Architecture & Renderer Guards](#7-platform-architecture--renderer-guards)
8. [Dependency Guards](#8-dependency-guards)
9. [Extension Directory Layout](#9-extension-directory-layout)
10. [Extension Directory Layout](#10-extension-directory-layout)
11. [Writing a New Family Extension](#11-writing-a-new-family-extension)
12. [Shipped Extensions](#12-shipped-extensions)
13. [Extension SDKs for Script Nodes](#13-extension-sdks-for-script-nodes)
14. [Multi-Output for Script Nodes](#14-multi-output-for-script-nodes)
15. [Extension Presets for Code Editors](#15-extension-presets-for-code-editors)
16. [Extension-Shipped Assets (.gnasset)](#16-extension-shipped-assets-gnasset)

---

## 1. Architecture Overview

Extensions are self-contained Godot addon folders under `res://addons/gn_ext_*/`.
Core GONODES code has **zero** hardcoded references to any extension — all
coupling flows through registration mechanisms that extensions call from
their boot scripts or declare in their manifest.

### Design Philosophy: Self-Containment

The core principle is that **deleting an extension folder removes all traces
of that extension** from the editor. No orphaned references, no broken
imports, no palette entries left behind. This is enforced by two rules:

1. **Core never imports from extensions.** No `preload()`, no `class_name`
   references, no hardcoded checks for extension-specific types. All
   coupling flows through generic registries (dictionaries keyed by string).
2. **Extensions own all their assets.** Operators, presets, help patches,
   native binaries, and even third-party SDK artifacts (like CEF) live
   inside the extension folder. Nothing goes in `addons/gonodes/` or the
   project root.

### Registration Flow

```
gn_extension.cfg (declarative manifest)
       │
       ├─→ GNExtensionRegistry.register_operator()   ← operators
       ├─→ GNFamily.register_family()                 ← new families
       └─→ boot.gd::boot()                           ← runtime hooks
              │
              ├─→ Override render_for_viewer() on base class  ← viewer display
              ├─→ GNCodeEditor.register_code_language()      ← code editor
              ├─→ GNParamRow.register_code_param()           ← param inspector
              └─→ GNNode.handle_viewer_input()               ← input forwarding (virtual override)
```

This means you can delete any `gn_ext_*` folder and GONODES continues to
function — only the operators from that extension disappear from the palette.

---

## 2. Manifest Format

Each extension declares a `gn_extension.cfg` (Godot ConfigFile format):

```ini
[extension]
name = "My Extension"
version = "1.0.0"
author = "Your Name"
description = "One-line description."
boot_script = "res://addons/gn_ext_myext/boot.gd"
section = "MySection"

# Platform/arch/renderer filters (all optional — omit to run everywhere)
platforms = ["windows", "macos", "linux"]
architectures = ["x86_64", "arm64"]
renderers = ["forward_plus", "mobile"]

# ClassDB dependency guard (optional)
dependencies = ["SomeNativeClass"]

# External runtime DLLs that must be on the system PATH (optional).
# sync_native_extensions() keeps the .gdextension disabled if these
# are not found via `where.exe` (Windows) / `which` (Linux/macOS).
# runtime_dlls = {"windows": ["vendor_runtime.dll"], "linux": ["libvendor.so"]}

# Register a new family (optional — only for family-defining extensions)
[family.SDF]
color = "0.95,0.65,0.15"
data_script = "res://addons/gn_ext_sdf/core/gn_sdf_data.gd"

# Operator entries (one section per operator)
[operator.SphereSDF]
family = "SDF"
script = "res://addons/gn_ext_sdf/operators/sdf/sphere_sdf.gd"
description = "SDF sphere primitive with radius and position."
requires_compute = false
requires_renderers = ["forward_plus"]
```

### Extension-Level Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name (shown in palette section headers) |
| `version` | No | Semantic version string |
| `author` | No | Author name |
| `description` | No | Brief description |
| `boot_script` | No | Resource path to a GDScript with a static `boot()` method |
| `section` | No | Palette sub-heading (defaults to `name`) |
| `platforms` | No | Array of OS names — extension skipped on unlisted platforms |
| `architectures` | No | Array of CPU architectures (`x86_64`, `arm64`) |
| `renderers` | No | Array of rendering methods (`forward_plus`, `mobile`, `gl_compatibility`) |
| `dependencies` | No | Array of ClassDB class names that must exist at runtime |

### Family Fields (`[family.NAME]`)

| Field | Required | Description |
|-------|----------|-------------|
| `color` | Yes | Wire/node color as `"R,G,B"` floats (0.0–1.0) |
| `data_script` | No | Resource path to data class (must extend `GNData`) |
| `renderer_script` | No | Resource path to viewer renderer (must extend `GNDataRenderer`) |
| `expression_func` | No | Expression function name (e.g. `"sdf"`). Registers a `sdf("node", "key")` expression function on CookEngine. See [Extending the Expression System](#extending-the-expression-system) below. |

### Operator Fields (`[operator.ClassName]`)

| Field | Required | Description |
|-------|----------|-------------|
| `family` | Yes | Family name (core: TOP, CHOP, SOP, DAT, IMG, MAT, COMP, UI, OUT, POP, VOL, SCRIPT; or extension-registered) |
| `script` | Yes | Resource path to operator GDScript |
| `description` | No | Palette tooltip text |
| `section` | No | Override extension-level section for this operator |
| `requires_compute` | No | If `true`, operator is skipped on non-compute renderers |
| `requires_renderers` | No | Array of renderer names this operator needs |

---

## 3. Loading Pipeline

### Startup Sequence

1. **Plugin loads** — `addons/gonodes/gonodes_plugin.gd` `_enter_tree()` calls
   `GNExtensionRegistry.instance()`.
2. **Core operators registered** — `_register_core_operators()` registers all
   built-in operators from `addons/gonodes/operators/`.
3. **Extension scan** — `scan_extensions()` iterates `res://addons/` looking
   for directories matching `gn_ext_*`.
4. **Per-extension load** — for each found directory, `_load_extension()`:
   a. Parses `gn_extension.cfg`
   b. Checks platform/arch/renderer/dependency guards — skips extension if any fail
   c. Registers any `[family.*]` sections via `GNFamily.register_family()`
   d. Registers each `[operator.*]` section via `register_operator()`
   e. Executes the `boot_script` if declared

### Registry API

```gdscript
# Singleton access
static func instance() -> GNExtensionRegistry

# Operator management
func register_operator(class_name_key: String, family: String,
    op_script: GDScript, description: String,
    source: String = "core", section: String = "",
    extension_dir: String = "") -> OperatorEntry

func unregister_operator(class_name_key: String) -> void
func create_instance(class_name_key: String) -> GNNode

# Queries
func get_operator_registry() -> Dictionary      # { "TOP": ["NoiseTOP", ...] }
func get_operator_registry_sectioned() -> Dictionary
func get_all_operator_names() -> PackedStringArray
func get_operator_entry(name: String) -> OperatorEntry
```

### OperatorEntry Record

```gdscript
class OperatorEntry:
    var family: String
    var op_script: GDScript
    var description: String
    var source: String              # "core" or extension name
    var section: String
    var extension_dir: String
    var requires_compute: bool
    var requires_renderers: PackedStringArray
```

---

## 4. Family Registration

Extensions can define entirely new data families. The `GNFamily` system
assigns integer IDs — core families use the enum (`TOP=0`, `IMG=1`, etc.),
extension families get IDs starting at **1000**.

```gdscript
# Core enum (addons/gonodes/core/gn_family.gd)
enum Type {
    TOP, IMG, CHOP, SOP, POP, DAT, MAT, COMP, VOL, UI, OUT, SCRIPT
}

# Extension registration
static var _next_ext_id: int = 1000
static var FAMILY_NAMES: Dictionary    # family_id → display name
static var FAMILY_COLORS: Dictionary   # family_id → Color

static func register_family(family_name: String, color: Color) -> int
    # Returns existing ID if already registered, else assigns _next_ext_id++

static func register_data_factory(family_id: int, factory: Callable) -> void
    # factory: func() -> GNData subclass instance

static func create_data_for_family(family_id: int) -> RefCounted
static func get_family_name(family: int) -> String
static func get_color(family: int) -> Color
static func string_to_type(family_str: String, fallback: int = Type.COMP) -> int
```

The palette, wire coloring, and node headers all read from `FAMILY_NAMES`
and `FAMILY_COLORS` — so a newly registered family automatically gets
correct visual treatment across the entire editor.

---

## 5. Boot Scripts

A boot script is a GDScript file with a static `boot()` method, executed
during extension loading **after** operators have been registered. This is
the hook for runtime registrations that can't be expressed declaratively.

### Execution

```gdscript
# In GNExtensionRegistry._load_extension():
var boot_path: String = cfg.get_value("extension", "boot_script", "")
if not boot_path.is_empty():
    var boot_scr: GDScript = load(boot_path) as GDScript
    if boot_scr != null and boot_scr.has_method("boot"):
        boot_scr.boot()
```

### Pattern

```gdscript
extends RefCounted

static func boot() -> void:
    # Guard against headless mode (UI classes unavailable)
    if DisplayServer.get_name() == "headless":
        return

    # Register UI hooks...
```

### What Boot Scripts Typically Do

| Hook | What It Registers | Example |
|------|-------------------|---------|
| Override `render_for_viewer()` | Custom viewer rendering for new data types | SDF extension shows SDF tree text |
| `GNNode.handle_viewer_input()` | Viewer input forwarding (virtual override) | WebRender forwards mouse/keyboard to CEF |
| `GNCodeEditor.register_code_language()` | Syntax highlighting + presets | ISF extension registers `.fs` highlighting |
| `GNParamRow.register_code_param()` | "Edit ↗" button on specific params | Shadertoy registers `shader_code` param |
| `GNScriptHelper.register_script_family()` | Script annotation families | Extension adds `"sdf"` to `@output` options |

### Viewer Input Forwarding

Operators that need to receive mouse/keyboard events from the viewer
(e.g. interactive web pages, touchable UI widgets) override `GNNode`'s
virtual method:

```gdscript
func handle_viewer_input(event: InputEvent, local_pos: Vector2,
                         viewer = null, port_index: int = 0) -> bool:
    # Process the event, return true to consume it (skips renderer + pan/zoom)
    return false
```

This is a **generic virtual** on the base node class — the viewer panel
calls it with `(event, local_pos, self, selected_port)`.  The operator
decides whether to consume the event.  If it returns `false`, the base
implementation dispatches to the family's `GNDataRenderer` for default
interaction (orbit drag, scroll-to-slice).  If that also returns `false`,
the viewer's built-in pan/zoom handling runs.

The `viewer` parameter gives direct access to the viewer panel (UV helpers,
orbit state, etc.) — no need to cache a `WeakRef` from `render_for_viewer`.

Example: WebRenderTOP overrides this to forward mouse clicks and
keyboard events to the Chromium browser.

### Texture Overlay

TOPs that need interactive handles use `GNInteractivePanel` via
`GNTopInteractiveBase`. **Params are the source of truth.** The viewer and
WindowOUT each get their own panel instance; both stay interactive and synced.
Wire the node's **panel** UI output to WindowOUT — the viewer Out overlay is
not cleared when that port is demanded.

```gdscript
# GNTopInteractiveBase provides panel port + dual-view sync automatically.
func _create_interactive_panel() -> GNInteractivePanel:
    return MapperOverlay.new()
```

Use `viewer.local_pos_to_uv(local_pos)` for manual UV conversion when not
using `GNInteractivePanel`. QuadMapTOP, StonerTOP, BezierMapTOP, GridWarpTOP,
and FixtureSamplerTOP use this framework.

### Headless Guard

Boot scripts that touch UI classes (`GNViewerPanel`, `GNCodeEditor`,
`GNParamRow`) **must** check for headless mode. In exported Player builds
running with `--headless`, these UI singletons don't exist. The pattern:

```gdscript
static func boot() -> void:
    if DisplayServer.get_name() == "headless":
        return
    # Safe to access UI singletons here
```

---

## 6. Extending the Expression System

Extensions can add new callable functions to the GONODES expression engine
using two complementary mechanisms.

### Architecture Constraint

Godot's `Expression` class resolves function calls as **method lookups on
`base_instance`** — the `GNCookEngine` instance passed to `execute()`.
You cannot inject arbitrary top-level functions; only methods on the cook
engine (or functions registered through the two hooks below) are callable.

The cook engine's expression methods are **thin routing stubs** — the actual
logic lives on `GNData` subclasses. The call chain for e.g. `chop("lfo1", "out")`:

```
Expression.execute() → CookEngine.chop("lfo1", "out")   ← method on base_instance
  → _make_data_proxy("lfo1", CHOP, "out")               ← generic router
    → node.cached_output.get_expression_value("out", -1) ← polymorphic, on GNChannelData
```

The cook engine does **zero** family-specific processing.

### 6.1 Family Expression Functions (top-level syntax)

When an extension defines a new operator family with property-accessible
data, it can register a top-level expression function via config:

```ini
[family.SDF]
color = "0.95,0.65,0.15"
data_script = "res://addons/gn_ext_sdf/core/gn_sdf_data.gd"
expression_func = "sdf"
```

This registers `sdf("node_id", "key")` as a first-class expression function.
The cook engine automatically generates the routing stub and variant suffixes
(`sdff`, `sdfi`, `sdfs`, `sdfp`, `sdfpf`).

**Data class requirements:**

```gdscript
## gn_sdf_data.gd
extends GNData

func get_expression_value(key: String, index: int = -1) -> Variant:
    match key:
        "distance": return distance
        "gradient": return gradient
    return 0.0

func get_expression_info() -> Dictionary:
    return { "distance": distance, "gradient": gradient }

func get_completions() -> Array[Dictionary]:
    return [
        {"label": "distance", "kind": "member"},
        {"label": "gradient", "kind": "member"},
    ]
```

**What you get automatically:**
- `sdf("node", "key")` top-level syntax in expressions
- Autocomplete: `sdf("` filters to SDF nodes; `sdf("node", "` shows completions
- Typed variants: `sdff()`, `sdfi()`, `sdfs()` with guaranteed return types
- Port-aware variants: `sdfp()`, `sdfpf()` for multi-output nodes
- Demand mapping: the cook engine tracks `sdf()` references for active-set pruning

### 6.2 Custom Utility Functions (via `fn()`)

For pure utility functions that don't need cook-engine context (math
helpers, lookup tables, format converters), use `GNExpressionFunctions`:

```gdscript
# In your extension's boot script:
static func boot() -> void:
    GNExpressionFunctions.register(
        "midi_to_freq",
        func(note: float) -> float: return 440.0 * pow(2.0, (note - 69.0) / 12.0),
        "Convert MIDI note to frequency (Hz)",
        ["note"]
    )
```

Users call: `fn("midi_to_freq", 60)`.

| API | Description |
|-----|-------------|
| `GNExpressionFunctions.register(name, callable, desc, arg_names)` | Register a custom function |
| `GNExpressionFunctions.unregister(name)` | Remove a custom function (built-ins cannot be removed) |
| `GNExpressionFunctions.register_builtin(name, callable, desc, arg_names)` | Register a non-removable function |

Custom functions appear in autocomplete when typing `fn("` in both the
inline LineEdit and the popup expression editor.

Up to 6 arguments are supported via `fn()`. For more complex APIs,
consider returning a Dictionary from a single `fn()` call.

### Why Not Move Built-in Expressions to `fn()`?

The built-in `chop()`, `top()`, etc. must remain as methods on the cook
engine because Godot's `Expression.execute()` resolves them via method
lookup. Moving them to `GNExpressionFunctions` would change the syntax from
`chop("lfo1", "out")` to `fn("chop", "lfo1", "out")` — a significant UX
regression for every expression in every project.

---

## 7. UI Registries

Three static registries allow extensions to hook into core UI without
core code importing any extension module.

### 6.1 Viewer Display (GNDataRenderer & render_for_viewer)

The default viewer rendering for each data type is handled by `GNDataRenderer`
subclasses registered in config via `renderer_script` under `[family.*]`.
Extensions that define custom families should provide a renderer:

```ini
[family.MyFamily]
color="0.8,0.4,0.2"
data_script="res://addons/my_ext/my_data.gd"
renderer_script="res://addons/my_ext/my_renderer.gd"
```

```gdscript
## my_renderer.gd
class_name MyRenderer extends GNDataRenderer

func render_for_viewer(data: GNData, viewer) -> void:
    viewer.set_info(data.get_preview_text(), "info bar text")
    # or: viewer.set_texture(my_texture, "info bar text")
    # or: viewer.set_control(my_control, "info bar text")
    # or: var vp = viewer.get_3d_viewport()  # activates 3D mode

func handle_viewer_input(data: GNData, event: InputEvent, viewer) -> bool:
    return false  # return true to consume
```

Individual operators can still override `render_for_viewer(viewer, port_index)`
on `GNNode` directly — the operator override takes precedence over the
renderer dispatch.

**Viewer API available to nodes:**
- `set_texture(tex: Texture2D, info_bar: String)` — display a texture with pan/zoom
- `set_control(control: Control, info_bar: String)` — display any Control widget
- `set_info(text: String, info_bar: String)` — display centered text
- `get_3d_viewport() -> SubViewport` — get/activate lazy 3D SubViewport
- `set_info_bar(text: String)` — set the bottom info bar
- `set_info_overlay(text: String)` — semi-transparent overlay text
- `get_content_size() -> Vector2i` — snapped content area size
- `hide_all_displays()` — clear all display modes

### 6.2 Code Editor Language

**File:** `addons/gonodes/ui/gn_code_editor.gd`

```gdscript
static var _ext_languages: Dictionary = {}

static func register_code_language(param_name: String, config: Dictionary) -> void
```

Config dictionary keys:

| Key | Type | Description |
|-----|------|-------------|
| `preset_folder` | String | Folder name under `user://gonodes_presets/` |
| `highlighter` | Callable | `func(code_edit: CodeEdit)` — applies syntax highlighting |
| `ref_text` | String | Shown in editor toolbar as quick reference |
| `file_ext` | String | File extension for save/load (e.g. `.fs`, `.glsl`) |

### 6.3 Param Row Code Button

**File:** `addons/gonodes/ui/gn_param_row.gd`

```gdscript
static var _ext_code_params: Dictionary = {}

static func register_code_param(param_name: String) -> void
```

When a parameter with a registered name appears in the inspector, an
"Edit ↗" button appears that opens the windowed code editor for that
parameter. Core code uses this for `code`, `shader_code`, etc. Extensions
register their own parameter names (e.g. `isf_code`, `shader_code`).

### 6.4 Viewer Input Forwarding

**File:** `addons/gonodes/core/gn_node.gd`

```gdscript
func handle_viewer_input(_event: InputEvent, _local_pos: Vector2,
                         viewer = null, port_index: int = 0) -> bool:
    # Base: dispatches to GNDataRenderer for the output data's family.
    # Override in operator to consume events before the renderer sees them.
    return false
```

Unlike the other hooks which use static registries, input forwarding uses
a **virtual method override** on the operator itself. The viewer panel calls
`handle_viewer_input(event, local_pos, self, port)` on whichever node is
currently displayed. If the operator override returns `true`, the event is
consumed. Otherwise, the base dispatches to the family renderer, and if
that also returns `false`, the viewer's default pan/zoom runs.

This pattern is used by WebRenderTOP to forward mouse/keyboard events to
the Chromium browser. Any operator can use it — no registration needed,
just override the virtual.

---

## 8. Platform, Architecture & Renderer Guards

Extensions can restrict themselves to specific environments:

```ini
[extension]
platforms = ["windows", "macos"]       # OS.get_name().to_lower()
architectures = ["x86_64"]            # Engine.get_architecture_name()
renderers = ["forward_plus", "mobile"] # RenderingServer method name
dependencies = ["FFmpegFrameDecoder"]  # ClassDB.class_exists()
```

The registry checks these **before** registering any operators. If a guard
fails, the entire extension is silently skipped — no error, no operators,
no boot script execution.

**Order of checks:**
1. `platforms` — `OS.get_name().to_lower()` must be in the list
2. `architectures` — `Engine.get_architecture_name()` must be in the list
3. `renderers` — current rendering method must be in the list
4. `dependencies` — every class name must exist in `ClassDB`

---

## 9. Dependency Guards (Hard Rule 25.29)

The `dependencies` field is an array of ClassDB class names. This is
primarily used by native extensions that require GDExtension binaries.
**This is mandatory for all native extensions — see hard rule 25.29.**

```ini
[extension]
dependencies = ["FFmpegFrameDecoder", "FFmpegStreamPlayer"]
```

If `ClassDB.class_exists("FFmpegFrameDecoder")` returns false (binary not
loaded), the extension is skipped. This prevents script errors from
operators referencing unavailable native classes.

### GDScript Pattern for Native Classes

Operator scripts MUST NOT reference native class names directly — this
causes parse errors when the `.gdextension` is disabled. Instead:

```gdscript
var _native: Object = null   # NOT: var _native: MyNativeClass

func _init() -> void:
    if ClassDB.class_exists(&"MyNativeClass"):
        _native = ClassDB.instantiate(&"MyNativeClass")

func _cook(inputs: Array[GNData]) -> GNData:
    if _native == null:
        node_warning = "Requires gn_ext_myext native library."
        return null
    var result = _native.call(&"process", input_data)
    # ...
```

**Rules:**
- Declare natives as `Object`, `RefCounted`, or `Node` — never the native type
- Guard instantiation with `ClassDB.class_exists()`
- Call methods via `.call(&"method_name", args)`
- Show `node_warning` when native is unavailable

---

## 10. Extension Directory Layout

```
addons/gn_ext_myext/
├── gn_extension.cfg          # Manifest (required)
├── boot.gd                   # Boot script (optional)
├── README.md                 # Extension documentation
├── operators/                # Operator scripts
│   └── top/
│       └── my_custom_top.gd
├── presets/                  # Code/shader presets (auto-discovered)
│   └── myformat/
├── help/                     # Help patches (.gnpatch)
│   └── top/
│       └── my_custom_top_basic.gnpatch
├── tests/                    # Extension tests
│   └── test_myext_operators.gd
├── native/                   # C++ source (if GDExtension-based)
│   ├── build.cfg             # Build manifest for gn_build.py
│   ├── src/                  #   vendor_setup / vendor_clone keys enable
│   └── SConstruct            #   zero-config CI for new SDK-dependent extensions
└── cef_artifacts/            # Third-party SDK artifacts (if applicable)
    └── gdcef.gdextension.disabled
```

**Key rule (Rule 25.36):** Everything lives inside the extension folder — including
third-party binary artifacts like CEF. Never place extension assets in
`addons/gonodes/` or the project root.

**README required (Rule 25.36):** Every `gn_ext_*` folder must contain a
`README.md` with at minimum: Overview, Operators table, Directory Layout.
This is the first document a contributor reads before touching any code.

### `.gdignore` Requirements

Certain extension subdirectories contain non-GDScript files (C++ headers,
Python modules, ISF shaders, CEF binaries) that Godot should **not** scan.
Without a `.gdignore` marker, Godot tries to parse these files as resources,
causing import errors and slowing down project scans.

**Place an empty `.gdignore` file** in each of these directories if they exist:

| Directory | Contents to hide from Godot |
|-----------|---------------------------|
| `native/` | C++ source, `godot-cpp/`, build outputs (`bin/`) |
| `presets/` | C++ snippets, Python scripts, ISF shaders, GLSL |
| `sdk/` | C/C++ headers, Python SDK modules |
| `cef_artifacts/` | CEF browser binaries and support files |

The `.gitignore` already uses wildcard patterns (`addons/gn_ext_*/native/bin/`,
`addons/gn_ext_*/native/godot-cpp/`) for build outputs, but `.gdignore` is a
separate Godot-level concern — it prevents the editor from scanning those
directories at all.

**Checklist for new extensions:** After creating the extension folder, add an
empty `.gdignore` to every subdirectory that contains non-GDScript/non-resource
files.

### Native Binary Auto-Activation

`.gdextension` files ship as `.gdextension.disabled` by default.
`GNExtensionRegistry.sync_native_extensions()` (called from the plugin's
`_enter_tree()`) scans **every subdirectory** within each `gn_ext_*`
folder for `.gdextension` files. If the platform binary exists on disk, the
file is renamed to `.gdextension` (activated). If the binary is missing,
it's renamed to `.gdextension.disabled` (silenced). Changes take effect
on the next Godot restart.

This means:
- **Extension installed without binaries?** No startup warnings.
- **Binaries compiled or downloaded?** Auto-activated on next launch.
- **Binaries deleted?** Auto-deactivated on next launch.

#### CLI sync (eliminates two-restart problem)

Since Godot loads GDExtensions **before** plugins, the in-editor activation
takes effect on the _next_ restart — meaning two restarts total. To avoid
this, run the Python equivalent after building:

```bash
python scripts/sync_gdextensions.py            # auto-detect platform
python scripts/sync_gdextensions.py --dry-run   # preview only
```

The SConstruct post-build step runs this automatically after `scons`.

#### `.gdextension` library key format

Godot resolves `[libraries]` keys as **`platform.arch.target`** — not
`platform.target.arch`. Getting this wrong silently prevents binary discovery.

```ini
# CORRECT — Godot format:
[libraries]
windows.x86_64.debug   = "res://addons/gn_ext_foo/cef/windows/libfoo.dll"
windows.x86_64.release = "res://addons/gn_ext_foo/cef/windows/libfoo.dll"
linux.x86_64.release   = "res://addons/gn_ext_foo/cef/linux/libfoo.so"
macos.release          = "res://addons/gn_ext_foo/cef/macos/libfoo.dylib"

# WRONG — arch and target swapped (Godot ignores these):
windows.debug.x86_64 = "..."
```

`sync_gdextensions.py` probes keys in Godot's resolution order:
`{plat}.{arch}.debug` → `{plat}.{arch}.release` → `{plat}.debug` →
`{plat}.release` → `{plat}.{arch}` → `{plat}`.

The test runner automatically discovers `test_*.gd` files under
`addons/gn_ext_*/tests/`.

---

## 11. Writing a New Family Extension

To add a completely new data family (like SDF did):

### Step 1: Create the Data Class

```gdscript
# addons/gn_ext_myext/core/my_data.gd
class_name MyExtData
extends GNData

var my_payload: Dictionary = {}

func duplicate_data() -> GNData:
    var copy := MyExtData.new()
    copy.valid = valid
    copy.timestamp = timestamp
    copy.my_payload = my_payload.duplicate(true)
    return copy

func get_preview_text() -> String:
    return "MyExt: %d items" % my_payload.size()
```

### Step 2: Create a Renderer (Optional)

```gdscript
# addons/gn_ext_myext/ui/my_renderer.gd
class_name MyExtRenderer
extends GNDataRenderer

func render_for_viewer(data: GNData, viewer) -> void:
    viewer.set_info(data.get_preview_text(), "")

func render_for_preview(data: GNData, host: Control) -> void:
    host.set_text(data.get_preview_text())
```

### Step 3: Declare the Family in the Manifest

```ini
[family.MYEXT]
color = "0.3,0.8,0.6"
data_script = "res://addons/gn_ext_myext/core/my_data.gd"
renderer_script = "res://addons/gn_ext_myext/ui/my_renderer.gd"
```

### Step 4: Write a Boot Script

```gdscript
# addons/gn_ext_myext/boot.gd
extends RefCounted

static func boot() -> void:
    # Boot scripts run at startup. Register runtime hooks here.
    # Viewer display is handled automatically by renderer_script in the manifest.
    # Override render_for_viewer() on individual operators for custom display.
    pass
```

### Step 5: Write Operators

Operators in the new family extend `GNNode` directly (since there's no
built-in base class for custom families) and set `family` to the registered
family name string.

### Step 5: Add Help Patches & Tests

- Help patches go in `addons/gn_ext_myext/help/<family>/`
- Tests go in `addons/gn_ext_myext/tests/`

---

## 12. Shipped Extensions

| Extension | Boot Script | Registers | Operators |
|-----------|-------------|-----------|-----------|
| `gn_ext_shadertoy` | Yes | Code param (`shader_code`), code language (GLSL), display handler | 1 TOP + 10 presets |
| `gn_ext_isf` | Yes | Code param (`isf_code`), code language (ISF/GLSL) | 1 TOP |
| `gn_ext_sdf` | Yes | New SDF family, display handler, script family | 26 operators |
| `gn_ext_user_python` | Yes | Code param, code language (Python) | 1 SCRIPT |
| `gn_ext_user_native` | Yes | Code param, code language (C++) | 1 SCRIPT |
| `gn_ext_native` | No | — | 92 native C++ operators |
| `gn_ext_ffmpeg` | No | — | FFmpeg-based operators |
| `gn_ext_hap` | No | — | HAP codec operators |
| `gn_ext_spout` | No | — | Spout texture sharing |
| `gn_ext_syphon` | No | — | Syphon texture sharing |
| `gn_ext_video_capture` | No | — | Webcam input |
| `gn_ext_midi` | No | — | MIDI I/O |
| `gn_ext_gpu_encode` | No | — | Hardware video encoding |
| `gn_ext_mapper` | No | — | Projection mapping |
| `gn_ext_ndi` | No | — | NDI network video |
| `gn_ext_ml` | No | — | ML inference (ONNX) |
| `gn_ext_depth_sensor` | No | — | Depth cameras |
| `gn_ext_blackmagic` | No | — | Blackmagic capture |
| `gn_ext_serial` | No | — | Serial port I/O |
| `gn_ext_webrender` | Yes | Code params (`html`, `javascript`), code languages (HTML, JS), input handler | 1 TOP — Web page to texture via CEF |

---

## 13. Extension SDKs for Script Nodes

Extensions can ship SDK headers (C++) and Python modules that become
available to UserNative and UserPython script operators. This lets
extension families participate in the script-node ecosystem without
modifying core code.

### How It Works

The UserNative C++ compiler automatically adds `{sdk_path}` (i.e.
`addons/gn_ext_user_native/sdk/`) to the compiler's include path. Any
`.h` file placed in that directory is `#include`-able from user C++ code.

The UserPython runtime puts `addons/gn_ext_user_python/sdk/` on
`sys.path`. Any Python package under that directory is `import`-able from
user Python code.

Extensions that define new families should ship SDK files in the
**core SDK directories** — not inside their own extension folder — so that
user scripts can include/import them without path manipulation.

### C++ SDK Headers

| Header | Provided By | Purpose |
|--------|-------------|---------|
| `gn_user_node.h` | Core | Base class + lifecycle + param helpers |
| `gn_user_types.h` | Core | Type aliases, param factories, `make_multi_output()` |
| `gn_user_sop.h` | Core | SOP output helpers |
| `gn_user_chop.h` | Core | CHOP output helpers |
| `gn_user_img.h` | Core | IMG output helpers |
| `gn_user_top.h` | Core | TOP output helpers |
| `gn_user_dat.h` | Core | DAT output helpers |
| `gn_user_sdf.h` | SDF extension | SDF tree construction (primitives, booleans, modifiers, materials) |

Extension authors adding a new family should create a corresponding
`gn_user_<family>.h` in the SDK directory with result builders and input
helpers matching the patterns in the existing headers.

### Python SDK Modules

| Module | Provided By | Purpose |
|--------|-------------|---------|
| `gonodes.sop` | Core | SOP result builders |
| `gonodes.chop` | Core | CHOP result builders |
| `gonodes.img` | Core | IMG result builders |
| `gonodes.top` | Core | TOP result builders |
| `gonodes.dat` | Core | DAT result builders |
| `gonodes.params` | Core | Port + parameter definition helpers |
| `gonodes` (init) | Core | Common helpers, `make_multi_output()` |
| `gonodes.sdf` | SDF extension | SDF tree construction (mirrors C++ API) |

### Adding an SDK for a New Extension Family

1. Create `gn_user_<family>.h` in `addons/gn_ext_user_native/sdk/`
2. Create `gonodes/<family>.py` in `addons/gn_ext_user_python/sdk/gonodes/`
3. Both should provide:
   - Result builder (e.g. `make_<family>_result()`)
   - Input reader (e.g. `get_input_<family>()`, `has_input_<family>()`)
   - Domain-specific helpers (e.g. SDF primitives, boolean ops)
4. The generic extension marshalling in `native_script.gd` and
   `python_script.gd` handles serialization/deserialization automatically
   for any family registered via `GNFamily.register_data_factory()`

### Generic Extension Data Marshalling

The UserNative and UserPython wrapper operators include generic marshalling
for extension data types. When a script's input or output belongs to an
extension family (e.g. SDF), the wrappers:

- **Marshal input:** Convert the `GNData` subclass to a plain Dictionary
  by checking for known properties (e.g. `"sdf_tree" in data` for SDF).
  The `_marshal_extension()` method handles this.
- **Build output:** Create a fresh `GNData` instance via
  `GNFamily.create_data_for_family(family_id)` and populate its properties
  from the cook result Dictionary. The `_build_extension()` method handles
  this.

This means extension family SDKs only need to produce/consume plain
Dictionaries — no special bridging code is required per extension.

---

## 14. Multi-Output for Script Nodes

All three script node types support multi-output:

| Script Type | Multi-Output Mechanism |
|-------------|----------------------|
| GDScriptSCRIPT | `# @output` annotations + `outputs[]` array |
| UserNative (C++) | `get_port_definitions()` with multiple outputs + `{"outputs": [...]}` return |
| UserPython | `get_port_definitions()` with multiple outputs + `{"outputs": [...]}` return |

### GDScript Multi-Output

Uses `# @output <family>` annotations. Each annotation creates a typed
output port with a pre-prepared `GNData` subclass in the `outputs[]` array:

```gdscript
# @output chop  Channel data
# @output dat   Statistics table

func cook():
    outputs[0].add_channel("lfo", PackedFloat32Array([sin(time)]))
    outputs[1].set_headers(["stat", "value"])
    outputs[1].append_row(["mean", "0.5"])
```

### C++ Multi-Output

Define multiple output ports in `get_port_definitions()` and return a
Dictionary with an `"outputs"` key containing an Array of per-port results:

```cpp
#include "gn_user_types.h"
#include "gn_user_chop.h"
#include "gn_user_dat.h"

Array get_port_definitions() override {
    return Array::make(
        gn::output_port("channels", "CHOP", "Channel data"),
        gn::output_port("stats", "DAT", "Statistics")
    );
}

Dictionary native_cook(const Dictionary &params,
                       const Array &inputs,
                       const Dictionary &ctx) override {
    Dictionary chop_result = gn::make_chop_single("lfo", arr);
    Dictionary dat_result = gn::make_dat_table(headers, rows);
    return gn::make_multi_output({chop_result, dat_result});
}
```

### Python Multi-Output

Same pattern — multiple output ports and an `"outputs"` return:

```python
from gonodes import make_multi_output
from gonodes.chop import make_chop_result
from gonodes.dat import make_dat_result
from gonodes.params import output_port

def get_port_definitions():
    return {"ports": [
        output_port("channels", "CHOP", label="Channel data"),
        output_port("stats", "DAT", label="Statistics"),
    ]}

def cook(me, params, inputs, context):
    chop = make_chop_result({"lfo": [math.sin(me["time"])]})
    dat = make_dat_result([["mean", "0.5"]], header=["stat", "value"])
    return make_multi_output(chop, dat)
```

### Protocol Details

- Single-output (backwards-compatible): cook returns a flat Dictionary
  (e.g. `{"positions": [...]}`)
- Multi-output: cook returns `{"outputs": [dict0, dict1, ...]}`
  where each element is the result for the corresponding output port index
- The wrapper detects the `"outputs"` key and routes each element to
  `_build_output_for_port(result, port_index, inputs)`
- `get_output_data(port_index)` override returns per-port cached data

---

## 15. Extension Presets for Code Editors

Extensions can contribute presets to the code editors (C++, Python,
GDScript) by placing files in a `presets/` directory inside the extension
folder. The `GNPresetPaths` system auto-discovers them.

### Discovery Path

`GNPresetPaths.get_code_preset_dirs(folder)` scans:
1. `res://addons/gonodes/presets/<folder>/` — core factory presets
2. `res://addons/gn_ext_*/presets/<folder>/` — extension presets
3. `user://gonodes_presets/<folder>/` — user-saved presets

### Folder Names

| Language | Folder | Extension Example |
|----------|--------|-------------------|
| GDScript | `script` | `addons/gn_ext_sdf/presets/script/sdf_sphere.gd` |
| C++ | `cpp` | `addons/gn_ext_sdf/presets/cpp/sdf_sphere.h` |
| Python | `python` | `addons/gn_ext_sdf/presets/python/sdf_sphere.py` |

### What Extensions Should Ship

Extensions defining a new family should include presets demonstrating
their SDK in all three languages (GDScript, C++, Python). These appear
in the code editor's **Presets** dropdown alongside core presets,
grouped by source.

### Example: SDF Extension Presets

```
addons/gn_ext_sdf/presets/
    script/                   # GDScript presets
        sdf_sphere.gd
        sdf_smooth_bool.gd
        sdf_procedural_scene.gd
    cpp/                      # C++ presets
        sdf_sphere.h
        sdf_smooth_bool.h
        sdf_procedural_scene.h
    python/                   # Python presets
        sdf_sphere.py
        sdf_smooth_bool.py
        sdf_procedural_scene.py
```

No registration code is needed — placing files in the correct directory
is sufficient. The preset menus pick them up automatically.

---

## 16. Extension-Shipped Assets (.gnasset)

Extensions can ship reusable custom operator assets (`.gnasset` files) that
appear in the palette under the extension's display name. These are
**read-only** — users cannot edit them in-place, but can "Make Editable" to
copy and break the link.

### Directory Layout

Place `.gnasset` files in an `assets/` directory inside the extension:

```
addons/gn_ext_myext/
    gn_extension.cfg
    assets/
        MyCustomBlur.gnasset
        MySpecialFilter.gnasset
    operators/
    ...
```

### Scanning

`GNExtensionRegistry._scan_extension_assets()` runs during
`scan_custom_assets()` and iterates every `gn_ext_*/assets/` directory.
For each `.gnasset` file found:

1. Reads the extension's `gn_extension.cfg` to extract the `display_name`.
2. Parses the `.gnasset` JSON.
3. Registers the operator via `_register_custom_asset()` with
   `p_read_only = true` and `p_section` set to the extension display name.

### Palette Appearance

Extension assets appear in the palette under:

```
Custom → <Family> → <Extension Display Name> → <Asset Name>
```

They are colored gold like user assets but show a tooltip:
*"(read-only — from extension)"*. The "Edit Asset" and "Re-promote" context
menu items are disabled for these entries.

### Priority

Extension assets are scanned **first** (priority 1). If a user asset has the
same `op_name` + `family` as an extension asset, the **user asset wins** — this
lets users override extension-shipped assets with their own versions.

### Design Rule

Extension assets follow the same self-containment rule as all extension
resources: **deleting the extension folder removes the assets from the
palette**. No orphaned entries, no registration debris.
