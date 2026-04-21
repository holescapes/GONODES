# GONODES — Copilot Instructions

> Node-based visual programming framework on Godot 4.6 for real-time visual art.
> 574 operators, 14 families, GDScript + GDExtension C++.

## Architecture

- **Families:** TOP (GPU texture), IMG (CPU image), CHOP (channels), DAT (tables), SOP (geometry), POP (GPU particles), VOL (3D volumes), COMP (3D scene), MAT (materials), OUT (output sinks), UI (widgets), SDF (signed distance), SCRIPT (code), NET (subnets)
- **Cook engine:** Demand-driven DAG. Only nodes feeding active sinks cook. `time_dependent = true` means cook every frame.
- **Data flow:** Each family has a `GNData` subclass (`GNTextureData`, `GNChannelData`, `GNGeoData`, `GNTableData`, `GNImageData`, etc.)
- **Base classes:** `GNTopBase`, `GNImgBase`, `GNChopBase`, `GNDatBase`, `GNSopBase`, `GNCompBase`, `GNMatBase`, `GNPopBase`, `GNVolBase`, `GNUiBase`, `GNSdfBase`
- For full architecture, read `GONODES_CONTEXT.md` §1–§8.

## Hard Rules (violations break things)

### 25.1 — No CPU Roundtrips for Real-Time Texture Data
NEVER call `Texture2D.get_image()` or `Image.get_data()` in per-frame code. Use `ViewportTexture` for GPU routing.

### 25.13 — Lazy Cook / No Unnecessary Work
Never set `time_dependent = true` unless the operator genuinely changes every frame.

### 25.14 — Descriptions Mandatory
Every operator needs: (1) `description=` in its `.cfg` entry, (2) description on every `add_input()`/`add_output()`, (3) description on every `GNParameter.create_*()`.

### 25.20 — Editor/Engine Separation
`core/` and `operators/` must NEVER import `ui/`. All operators must run headless.

### 25.2 — Expression base_instance Architecture
Functions called inside an `Expression` are method lookups on `base_instance`, not input variables. Passing Callables as input variables silently fails. Always make expression-callable functions real methods on the base_instance object.

### 25.3 — GNFamily.get_name → get_family_name
Never shadow `Object.get_name()`. Use unique names like `get_family_name(family)` instead.

### 25.4 — WindowOUT Cook-Dirty vs Param-Dirty
Do NOT use `if dirty:` for window config — dirty is true every frame when upstream is time-dependent. Use a dedicated `_window_params_dirty` flag set only by `_on_parameter_changed()`.

### 25.5 — Anchors: set_anchors_and_offsets_preset
`Control.anchors_preset = PRESET_FULL_RECT` only sets anchors, NOT offsets → 0×0 size. Always use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER the control is in the tree.

### 25.6 — embed_subwindows
`project.godot` must have `window/subwindows/embed_subwindows=false` for WindowOUT to create real OS-level windows.

### 25.7 — DisplayServer API
Use `DisplayServer.screen_get_size()` / `screen_get_position()` (not `get_screen_size`). Use `window_set_vsync_mode(mode, window_id)` for per-window vsync.

### 25.8 — GraphEdit Signal Naming
`GraphEdit` has built-in `node_selected`/`selection_cleared`. Custom signals must use different names (e.g., `operator_selected`/`operator_deselected`).

### 25.9 — Inspector Per-Cook Updates
NEVER call `_update_mode_display()` per-cook — clobbers edits 60×/sec. Use lightweight `update_expression_status()` per-cook. Check `_expr_edit.has_focus()` before setting text.

### 25.10 — Dynamic Input Ports (Auto-Grow)
Variable-input operators use `_enable_dynamic_inputs()` in `_init_ports()`. Ports auto-grow on connect (trailing empty slot) and auto-shrink on disconnect. Used by: MergeSOP, MergeCOMP, RenderTOP, MergeCHOP, SwitchTOP, SwitchCHOP, SwitchSOP, SwitchDAT. Operators must handle null inputs for disconnected ports. Supersedes the old `num_inputs` parameter pattern.

### 25.11 — COMP Nodes: Scene-Node Ownership, Proxy Fan-Out
COMPs return `GNCompData` (via `_build_comp_data()`) wrapping a **reference** to their singleton `_scene_node` (MeshInstance3D, Camera3D, Light3D, etc.). All scene-node resolution uses `cached_output as GNCompData` (data-type check, not node-type check). When a COMP scene node fans out to multiple consumers (two RenderTOPs, or two MergeCOMPs), the first consumer adopts the original (zero overhead), subsequent consumers get visual proxies via `GNProxyTree`. Proxies share GPU resources (Mesh, Material, MultiMesh). Physics bodies become plain Node3D placeholders in proxies. Both RenderTOP and MergeCOMP use `_adopt_or_proxy()` / `_adopt_or_proxy_child()` respectively. EnvironmentCOMP returns GNCompData with the `environment` field set (no scene node); RenderTOP checks `comp_data.environment != null`.

### 25.12 — SubViewport World3D Isolation
RenderTOP assigns `SubViewport.world_3d = World3D.new()` before tree entry. Without this, 3D content bleeds into the editor viewport. Do NOT use `own_world_3d = true` (causes duplicate World3D bug with Jolt).

### 25.15 — Dynamic Port Counts
`set_input_count(count, family, prefix, desc)` / `set_output_count(...)` rebuild port arrays and emit `ports_changed(node_id)`. Graph editor prunes stale wires automatically. For Switch/Merge ops, prefer `_enable_dynamic_inputs()` (auto-grow) over parameter-driven counts.

### 25.16 — Canvas Anchoring in TOP SubViewports
Use `_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER `add_child(_canvas)`. In `_cook()`, only set `_viewport.size = res` — the canvas follows via anchors. Applies to all 21 SubViewport-based TOPs.

### 25.17 — Viewer Panel Sizing
Use `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` (value 1) + `stretch_mode = KEEP_ASPECT_CENTERED` (value 5). Set `clip_contents = true` and small `custom_minimum_size.y`.

### 25.18 — Node Renaming Full Chain
On rename: update `nodes` dict key → `GNNode.id` + `.name` → all `GNConnection` refs → expression strings (regex path-segment replacement in params, component_expressions, scripts, CallbackDAT slots) → emit `node_renamed`. IDs must match `^[a-zA-Z_][a-zA-Z0-9_]*$`.

### 25.19 — GNNode Lifecycle
- `.new()` / `_init()` — sets `node_type`, `family`, `node_description`. **No ports, no parameters.**
- `initialize(id)` — calls `_init_ports()` + `_init_parameters()`, wires param signals. Full lifecycle for network nodes.
- For introspection only (palette cache): call `node._init_ports()` explicitly after `.new()`. Do NOT call `initialize()`.

### 25.21 — Help Example Patches Required
Every operator MUST ship with at least one `.gnpatch` in `help/<family>/`. Naming: `<node_type>_<label>.gnpatch`. Must use `class_name` in the `type` field. Keep patches to 1–4 nodes. Max ~3 patches per operator.

### 25.22 — Help Patch Sink Rule (WindowOUT Chain by Family)
Every help `.gnpatch` must terminate at `WindowOUT` (512×512, `open: true`) via a family-appropriate chain:
| Family | Chain to WindowOUT |
|--------|-------------------|
| TOP | direct |
| IMG | → ImgToTOP → WindowOUT |
| CHOP | → CHOPtoTOP → WindowOUT |
| SOP | → GeometryCOMP + CameraCOMP → RenderTOP → WindowOUT |
| COMP (scene) | + CameraCOMP → RenderTOP → WindowOUT |
| COMP (pass-through) | route data *through* it (never bypass) → RenderTOP → WindowOUT |
| DAT | → TextTOP → WindowOUT |
| MAT | → GeometryCOMP (MAT port 1, SOP port 0) + CameraCOMP → RenderTOP → WindowOUT |

### 25.24 — Multi-Output Demand Gating
Multi-output nodes: shared core runs unconditionally; per-port work MUST be guarded by `is_output_demanded(N)`. Override `get_output_data(port_index)` for routing. Exceptions (must comment `# MULTI-OUTPUT EXCEPTION:` in code): coupled physics sims, GPU MRT.

### 25.25 — Shared Logic in Base Classes, Not Subclasses
When 2+ operators share the same helper logic, move it to the family base class (`GNCompBase`, `GNTopBase`, etc.) or to `GNNode`. Never duplicate utility methods across subclasses. Check the base class before writing a helper — it may already exist.

### 25.26 — Check Data Types, Not Node Families
When consuming upstream output, check the **data type** (`cached_output as GNTextureData`, `data is GNChannelData`), NOT the node's family (`node.family == GNFamily.Type.TOP`, `node is GNTopBase`). Data-type checks work uniformly for `GNCompBase`, `SubNetworkNode`, `GNCustomOperator`, and any future node type. Node-family checks silently reject valid data from nodes with a different family (e.g., a SubNetworkNode outputting `GNChannelData` has family NET, not CHOP).

### 25.27 — COMP Proxy Bookkeeping for New Node Types
When adding a new COMP that creates a `_scene_node`, check `GNProxyTree._create_proxy_node()` for its type. Currently proxied: MeshInstance3D, MultiMeshInstance3D, Camera3D, DirectionalLight3D, OmniLight3D, SpotLight3D. Unknown types become plain Node3D placeholders. If the new COMP creates a NEW visual node type (e.g., GPUParticles3D, Decal), add a typed proxy factory + sync method to GNProxyTree and a test in `tests/unit/core/test_proxy_tree.gd`.

### 25.28 — Family-Output Coherence (No Hidden Conversions)
Every operator MUST output data matching its declared family. A CHOP outputs `GNChannelData`, a DAT outputs `GNTableData`, a TOP outputs `GNTextureData`, an IMG outputs `GNImageData`, a SOP outputs `GNGeoData`, etc. **Never embed a silent cross-family conversion inside a non-bridge operator.** If a node works with float/channel data, it belongs in CHOP — not DAT. If it processes CPU images, it belongs in IMG — not TOP. Users convert between families explicitly via bridge operators (`CHOPtoTOP`, `ImgToTOP`, `SOPtoDAT`, etc.). The only exceptions are: (1) explicit bridge operators whose name declares the conversion, (2) multi-output operators that emit secondary ports of a different family (rule 25.24 demand-gated), and (3) NET family host-bridge operators that output typed data matching their specific bridge target.

### 25.29 — Native Extension Graceful Degradation
Extensions with GDExtension native binaries MUST degrade gracefully when binaries are missing. Three mandatory layers: (1) Ship `.gdextension` as `.gdextension.disabled` — auto-activated by `sync_native_extensions()` when binary exists. (2) Declare `dependencies = ["MyNativeClass"]` in `gn_extension.cfg` — registry skips the extension if `ClassDB.class_exists()` fails. (3) NEVER reference native class names directly in GDScript — use `ClassDB.class_exists(&"...")` + `ClassDB.instantiate(&"...")` + `.call(&"method", args)`. Declare variables as `Object`/`RefCounted`/`Node`, not the native type. Show `node_warning` when the native instance is null.

### File Encoding
All text files are UTF-8 without BOM. NEVER use PowerShell `Get-Content`/`Set-Content` without `-Encoding UTF8` on BOTH calls. Prefer Python for non-ASCII text manipulation.

### .uid Files
Do NOT generate `.uid` sidecar files. Godot creates them on project scan.

## Operator Structure

```gdscript
class_name MyOperatorTOP
extends GNTopBase

func _init() -> void:
    node_type = "myoperator"
    # time_dependent = true  # Only if needed

func _init_ports() -> void:
    add_input("in", GNFamily.Type.TOP, false, "Input texture")
    add_output("out", GNFamily.Type.TOP, "Output texture")

func _init_parameters() -> void:
    add_parameter(GNParameter.create_float("amount", 1.0, 0.0, 10.0, 0.01,
        "Amount", "Controls the effect intensity"))

func _cook(inputs: Array[GNData]) -> GNData:
    # Implementation
    return _cached_tex_data
```

## dynamic_enum_callback — Live Hardware Enum Parameters

For ENUM parameters whose options depend on runtime state (connected devices, available modes), set `dynamic_enum_callback` on the parameter to a `Callable` returning `PackedStringArray`. The inspector calls this before opening the dropdown, so the list always reflects current hardware.

```gdscript
func _init_parameters() -> void:
    var device_param := GNParameter.create_enum("device", 0, ["None"],
        "Device", "Select capture device")
    device_param.dynamic_enum_callback = Callable(MyHelper, "get_device_menu")
    add_parameter(device_param)
```

Signature: `func get_device_menu() -> PackedStringArray`. Used by: BlackmagicInIMG, BlackmagicOutIMG, DepthSensorIMG.

## .gnpatch Connection Format

- Keys: `"from"`, `"to"` (NOT `"from_node"`, `"to_node"`)
- Port indices: integers (`0`, `1`) — NOT string names
- Vector2i values: `{"_type": "Vector2i", "x": 1024, "y": 768}`

## After Adding/Modifying an Operator

1. Register in `.cfg` file (`[operator.ClassName]` with family, script, description)
2. Run `python scripts/scan_operators.py` and `python scripts/build_port_registry.py`
3. Run `python scripts/generate_help_patches.py --operator <node_type>`
4. Add entry in `docs/OPERATORS.md`
5. Update operator counts in: README.md, docs/OPERATORS.md, dev_docs/TESTING.md, dev_docs/GONODES_VS_THE_REST.md
6. Run `python scripts/verify_new_operator.py <ClassName>`

## Key File Locations

| What | Where |
|------|-------|
| Core engine | `addons/gonodes/core/` |
| Operators | `addons/gonodes/operators/<family>/` |
| Extensions | `addons/gn_ext_<name>/` |
| Extension configs | `addons/gn_ext_<name>/gn_extension.cfg` |
| Core config | `addons/gonodes/gn_core.cfg` |
| Help patches | `addons/gonodes/help/<family>/` or `addons/gn_ext_<name>/help/<family>/` |
| Scripts | `scripts/` |
| Dev docs | `dev_docs/` |
| Context file | `GONODES_CONTEXT.md` (5000+ lines — read specific sections on demand) |

## Deep Context (read on demand, not always)

- Cook engine internals: `GONODES_CONTEXT.md` §8
- Expression system: `GONODES_CONTEXT.md` §16
- All hard rules: `GONODES_CONTEXT.md` §25
- Extension system: `dev_docs/EXTENSIONS.md`
- Build system: `dev_docs/BUILD.md`
- Testing: `dev_docs/TESTING.md`
- Contributing: `dev_docs/CONTRIBUTING.md`
- New operator checklist: `dev_docs/NEW_OPERATOR_CHECKLIST.md`
- Script reference: `dev_docs/SCRIPTS.md`
- Host data formats: `dev_docs/HOST_DATA_GUIDE.md`
