# GONODES — Copilot Instructions

> Node-based visual programming framework on Godot 4.6 for real-time visual art.
> 536 operators, 14 families, GDScript + GDExtension C++.

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

### 25.24 — Multi-Output Demand Gating
Multi-output nodes: shared core runs unconditionally; per-port work MUST be guarded by `is_output_demanded(N)`. Override `get_output_data(port_index)` for routing. Exceptions (must comment `# MULTI-OUTPUT EXCEPTION:` in code): coupled physics sims, GPU MRT, SubNetworkNode.

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

## .gnpatch Connection Format

- Keys: `"from"`, `"to"` (NOT `"from_node"`, `"to_node"`)
- Port indices: integers (`0`, `1`) — NOT string names
- Vector2i values: `{"_type": "Vector2i", "x": 1024, "y": 768}`

## After Adding/Modifying an Operator

1. Register in `.cfg` file (`[operator.ClassName]` with family, script, description)
2. Run `python scripts/scan_operators.py` and `python scripts/build_port_registry.py`
3. Run `python scripts/generate_help_patches.py --operator <node_type>`
4. Add entry in `docs/OPERATORS.md`
5. Update operator counts in: README.md, docs/OPERATORS.md, dev_docs/TESTING.md, dev_docs/GONODES_VS_OTHERS_ALPHA.md
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
