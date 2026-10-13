# New Operator Checklist

Every file and system that must be touched when adding a new operator to
GONODES.  Run `python scripts/verify_new_operator.py <ClassName>` to
validate automatically.

---

## Quick Reference

```
python scripts/verify_new_operator.py SinkOUT     # Check one operator
python scripts/verify_new_operator.py --all       # Check every operator
python scripts/verify_new_operator.py --recent    # Find unregistered ops
python scripts/verify_new_operator.py --counts    # Verify doc counts match
```

---

## Mandatory Steps (will break things if skipped)

### 1. Operator Script

- [ ] Create `addons/gonodes/operators/<family>/<node_type>_<family>.gd`
  - Or for extensions: `addons/gn_ext_<name>/operators/<family>/...`
- [ ] `class_name` — PascalCase + family suffix (e.g., `SinkOUT`, `BlurTOP`)
- [ ] `node_type` — unique lowercase slug (e.g., `"sink"`, `"blur"`)
- [ ] `family = GNFamily.Type.<FAMILY>`
- [ ] `_init_ports()` — all ports have description strings
- [ ] `_init_parameters()` — all params have description strings
- [ ] `_cook()` — functional implementation
- [ ] **Do NOT set `node_description` in the script** — descriptions live in the `.cfg` file
- [ ] If the operator uses only a subset of its inputs depending on mode/parameter (like Switch), override `get_active_input_indices()` — see [CONTRIBUTING.md](CONTRIBUTING.md#active-input-indices--selective-upstream-cooking)
- [ ] If the operator is a routing node (Switch-style), `_cook()` should return `cached_output` when the requested input is not yet available — this prevents a flash during the 1-frame expression-driven routing transition
- [ ] **Multi-output operators:** If the node has 2+ output ports, structure `_cook()` as **shared core** (unconditional) plus **per-port guards** using `is_output_demanded(N)`. Split expensive per-port logic into separate helper methods and call them conditionally.

  **Demand is detected from three sources** (not just wires):
  1. Wire connections to active downstream nodes
  2. Wireless Select operators (SelectCHOP, SelectTOP, etc.) referencing this node by name
  3. Expression references (`chop()`, `top()`, `dat()`, etc.) in other nodes' parameters

  No port is auto-demanded — each port is independently stamped by the cook
  engine based on actual consumers.  The `_cook()` method decides which work
  is shared (unconditional) and which is per-port (guarded).

  **Pattern A — Independent post-processing** (e.g., OpenCV operators):
  The shared detection always runs.  Overlay conversion and data extraction
  are independent post-processing steps, each guarded:
  ```gdscript
  func _cook(inputs: Array[GNData]) -> GNData:
      var out := _prepare_output()
      _run_shared_detection(inputs)            # Shared core — always
      if is_output_demanded(0):
          _build_overlay(out)                  # Port 0 — only if demanded
      if is_output_demanded(1):
          _extract_tracking_data()             # Port 1 — only if demanded
      return out
  ```

  **Pattern B — Directional dependency** (e.g., MovieFileInTOP):
  Audio (port 1) depends on video decode, but video (port 0) doesn’t need
  audio.  Video decode is the shared core; only audio capture is guarded:
  ```gdscript
  func _cook(inputs: Array[GNData]) -> GNData:
      var result := _decode_video(inputs)      # Shared core (audio needs this)
      if is_output_demanded(1):
          _pull_audio()                        # Port 1 — only if demanded
      return result
  ```

  Override `get_output_data(port_index)` to route each port to its cached data. See `MovieFileInTOP` (directional dependency) or any OpenCV IMG operator (independent post-processing) for canonical patterns.

### 2. Register in Config

- [ ] **Core operator:** Add `[operator.ClassName]` section to `addons/gonodes/gn_core.cfg`
- [ ] **Extension operator:** Add `[operator.ClassName]` section to `addons/gn_ext_<name>/gn_extension.cfg`
- [ ] Fields: `family`, `script` (res:// path), `description` (one-line purpose string — this is the single source of truth for the operator description, injected at runtime)

### 3. Help Patches (minimum 1, target 3)

- [ ] Create `addons/gonodes/help/<family>/<node_type>_basic.gnpatch`
  - Or for extensions: `addons/gn_ext_<name>/help/<family>/...`
- [ ] Patch uses the new operator with non-default params
- [ ] Ends with WindowOUT (512×512, open=true) via family-appropriate chain
- [ ] Includes an annotation describing the demo
- [ ] (Target) Create `_<feature>.gnpatch` and `_<advanced>.gnpatch` variants

> **Family-to-directory mapping:**
> TOP→`top/`, CHOP→`chop/`, SOP→`sop/`, DAT→`dat/`, COMP→`comp/`,
> MAT→`mat/`, IMG→`img/`, OUT→`output/`, UI→`ui/`, POP→`pop/`,
> VOL→`vol/`, SDF→`sdf/`, SCRIPT→`script/`

---

## Derived Artifacts (regenerate or update)

### 4. Operator Registry

- [ ] Run `python scripts/scan_operators.py` → updates `scripts/operator_registry.json`

### 5. Port Registry

- [ ] Run `python scripts/build_port_registry.py` → updates `scripts/port_registry.json`
  - Also regenerates `scripts/operator_port_registry.py`

### 6. Documentation

- [ ] `docs/OPERATORS.md` — Add full entry in the family section:
  - Heading with operator name
  - Parameter table (Name, Type, Default, Range, Description)
  - Input/output descriptions
  - "How it works" paragraph
  - Update family operator count in the section header
  - Update total operator count in the file header

- [ ] Root `README.md` does not list operator totals. Do not add a count or a family table back.

- [ ] Other docs that state the operator count:
  - `dev_docs/TESTING.md` — "All N operators"
  - `dev_docs/GONODES_VS_THE_REST.md` — "N operators across 13 families"
  - `.github/workflows/release.yml` — release description operator count
  - `CHANGELOG.md` — new entry with operator count

### 7. Test Coverage

- [ ] Add the new operator's class_name to the family test file:
  - `tests/operators/<family>/test_<family>_operators.gd`
  - Minimum: instantiation + default param check + cook-without-crash
- [ ] For extension operators the test goes in `addons/gn_ext_<name>/tests/`

### 8. CHANGELOG

- [ ] Add a dated entry in `CHANGELOG.md` listing the new operator

---

## What Each Step Prevents

| Step | What breaks if skipped |
|------|------------------------|
| Operator script | Nothing works — no operator exists |
| Config registration | Operator won't appear in the palette or be loadable from patches |
| Help patches | No `?` help available; `check_coverage.py` flags missing coverage |
| operator_registry.json | `list_ops.py`, help generators, and coverage scripts can't find it |
| port_registry.json | Patch validator reports unknown operator type |
| docs/OPERATORS.md | Users can't find documentation for the operator |
| Doc counts | Stale numbers cause confusion in README, release notes, comparisons |
| Test coverage | Regressions go undetected; test suite reports incomplete coverage |
| CHANGELOG | Users don't know the operator was added |

---

## Full Command Sequence

After creating the operator and its help patches, run this sequence:

```bash
# 1. Regenerate registries
python scripts/scan_operators.py
python scripts/build_port_registry.py

# 2. Verify the new operator
python scripts/verify_new_operator.py MyNewSOP

# 3. Check all doc counts are consistent
python scripts/verify_new_operator.py --counts

# 4. Run the test suite (if Godot available)
godot --headless -s tests/test_runner.gd

# 5. Validate all help patches parse correctly
python scripts/validate_all_patches.py
```
