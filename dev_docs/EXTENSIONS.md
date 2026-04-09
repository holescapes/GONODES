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
10. [Writing a New Family Extension](#10-writing-a-new-family-extension)
11. [Shipped Extensions](#11-shipped-extensions)

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

1. **Plugin loads** — `addons/gonodes/plugin.gd` `_enter_tree()` calls
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
func handle_viewer_input(event: InputEvent, local_pos: Vector2) -> bool:
    # Process the event, return true to consume it (skips viewer pan/zoom)
    return false
```

This is a **generic virtual** on the base node class — the viewer panel
calls it without any knowledge of the specific operator. No viewer
branching or type checks. The operator decides whether to consume the
event. If it returns `false`, the viewer's default pan/zoom handling runs.

Example: WebRenderTOP overrides this to forward mouse clicks and
keyboard events to the Chromium browser.

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

## 6. UI Registries

Three static registries allow extensions to hook into core UI without
core code importing any extension module.

### 6.1 Viewer Display (render_for_viewer)

Extensions provide viewer rendering by overriding `render_for_viewer(viewer)`
on their family base class or individual operator.  The viewer parameter
provides these display modes:

```gdscript
## In your extension's base class or operator:
func render_for_viewer(viewer) -> void:
    viewer.set_info("My custom info", "info bar text")
    # or: viewer.set_texture(my_texture, "info bar text")
    # or: viewer.set_control(my_control, "info bar text")
    # or: var vp = viewer.get_3d_viewport()  # activates 3D mode
```

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
func handle_viewer_input(_event: InputEvent, _local_pos: Vector2) -> bool:
    return false  # Override in operator to consume events
```

Unlike the other hooks which use static registries, input forwarding uses
a **virtual method override** on the operator itself. The viewer panel calls
`handle_viewer_input()` on whichever node is currently displayed — without
knowing its type. If the method returns `true`, the event is consumed and
the viewer's default pan/zoom is skipped.

This pattern is used by WebRenderTOP to forward mouse/keyboard events to
the Chromium browser. Any operator can use it — no registration needed,
just override the virtual.

---

## 7. Platform, Architecture & Renderer Guards

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

## 8. Dependency Guards

The `dependencies` field is an array of ClassDB class names. This is
primarily used by native extensions that require GDExtension binaries:

```ini
[extension]
dependencies = ["FFmpegFrameDecoder", "FFmpegStreamPlayer"]
```

If `ClassDB.class_exists("FFmpegFrameDecoder")` returns false (binary not
loaded), the extension is skipped. This prevents script errors from
operators referencing unavailable native classes.

---

## 9. Extension Directory Layout

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
│   ├── src/
│   └── SConstruct            # 6-line shim delegating to build/gn_build.py
└── cef_artifacts/            # Third-party SDK artifacts (if applicable)
    └── gdcef.gdextension.disabled
```

**Key rule:** Everything lives inside the extension folder — including
third-party binary artifacts like CEF. Never place extension assets in
`addons/gonodes/` or the project root.

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

The test runner automatically discovers `test_*.gd` files under
`addons/gn_ext_*/tests/`.

---

## 10. Writing a New Family Extension

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

### Step 2: Declare the Family in the Manifest

```ini
[family.MYEXT]
color = "0.3,0.8,0.6"
data_script = "res://addons/gn_ext_myext/core/my_data.gd"
```

### Step 3: Write a Boot Script

```gdscript
# addons/gn_ext_myext/boot.gd
extends RefCounted

static func boot() -> void:
    # Boot scripts run at startup. Register runtime hooks here.
    # Viewer display is now handled by overriding render_for_viewer()
    # on your operator or family base class — no boot registration needed.
    pass
```

Viewer rendering example (in your operator):
```gdscript
func render_for_viewer(viewer) -> void:
    viewer.set_info(cached_output.get_preview_text(), "")
```

### Step 4: Write Operators

Operators in the new family extend `GNNode` directly (since there's no
built-in base class for custom families) and set `family` to the registered
family name string.

### Step 5: Add Help Patches & Tests

- Help patches go in `addons/gn_ext_myext/help/<family>/`
- Tests go in `addons/gn_ext_myext/tests/`

---

## 11. Shipped Extensions

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
