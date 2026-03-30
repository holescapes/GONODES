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
- [ ] `_setup_parameters()` — all params have description strings
- [ ] `_cook()` — functional implementation
- [ ] **Do NOT set `node_description` in the script** — descriptions live in the `.cfg` file

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

- [ ] `README.md` — Update:
  - Header operator count (`**N operators**`)
  - Family count in the table if the family total changed (e.g., `OUT (14)`)

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
