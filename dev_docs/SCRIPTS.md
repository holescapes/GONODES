# Scripts Reference

All helper scripts live in `scripts/`.  They require **Python 3.10+** and no external packages (stdlib only).  Build scripts also require Godot on `PATH` or explicitly passed.

---

## Quick Reference

| Script | Purpose | Run after… |
|--------|---------|------------|
| `scan_operators.py` | Rebuild `operator_registry.json` | Adding/removing/editing any operator |
| `build_port_registry.py` | Rebuild `port_registry.json` + `operator_port_registry.py` | Adding/removing/editing operator ports |
| `generate_help_patches.py` | Auto-generate 3 `.gnpatch` help files per operator | Adding a new operator |
| `verify_new_operator.py` | Validate a new operator is fully integrated | Adding a new operator (final check) |
| `validate_all_patches.py` | Validate all `.gnpatch` files for structural errors | Editing patches or operator ports |
| `check_coverage.py` | Report operators with fewer than 3 help patches | Before release |
| `check_versions.py` | Verify CI workflows agree with `versions.env` | Bumping Godot or extension versions |
| `check_env.py` | Pre-flight build environment check (tools, SDKs) | Before first build or release |
| `check_builds.py` | Verify native extension build outputs exist | After building native extensions |
| `sync_gdextensions.py` | Activate/deactivate `.gdextension` files based on binary presence | After building (also runs automatically as SConstruct post-build) |
| `clean_builds.py` | Remove all compiled binaries and deactivate extensions | Before release tagging (clean source-only state) |
| `bundle_toolchain.py` | Bundle godot-cpp into user_native toolchain | Before packaging a release |
| `clone_native_help_patches.py` | Clone help patches to Native C++ variants | Adding a new native wrapper |
| `regen_broken_patches.py` | Regenerate structurally broken `.gnpatch` files | Patch validation failures |
| `gen_native_operators_md.py` | Generate native ops section of `OPERATORS.md` | Adding/removing native wrappers |
| `gen_all_core_patches.py` | Generate full manual QA test patches (all operators) | Before release QA |

---

## Registries

### `scan_operators.py`

Scans all `.gd` files under `addons/gonodes/operators/` and `addons/gn_ext_*/operators/`, extracts `class_name`, `node_type`, family, and parameters via regex.

```
python scripts/scan_operators.py
```

**Output:** `scripts/operator_registry.json` — the authoritative operator catalog (class name, family, params with types/defaults).

**Important:** The param scanner matches `create_float`, `create_int`, `create_bool`, `create_enum`, `create_string`, `create_color`, `create_vector2i`, `create_file`, `create_ramp`, `create_pulse`, etc.  If you introduce a new `create_*` factory, update the regex in this script.

### `build_port_registry.py`

Scans every operator for `add_input()` / `add_output()` / `_enable_dynamic_inputs()` calls, plus inherited base-class ports.

```
python scripts/build_port_registry.py
```

**Output:**
- `scripts/port_registry.json` — maps class_name → inputs, outputs, dynamic_inputs
- `scripts/operator_port_registry.py` — importable Python dict (used by other scripts)

### When to run

Both registries **must** be regenerated whenever you:
- Add a new operator
- Remove an operator
- Rename an operator class
- Change an operator's ports or parameters
- Change a parameter from `create_string` to `create_file` (or any type change)

---

## Help Patches

### `generate_help_patches.py`

Auto-generates 3 `.gnpatch` example files per operator using family-specific templates and data from `operator_registry.json`.

```
python scripts/generate_help_patches.py
python scripts/generate_help_patches.py --operator GlitchTOP     # single operator
python scripts/generate_help_patches.py --family top              # one family
python scripts/generate_help_patches.py --force                   # overwrite existing
```

Patches are placed in the appropriate `help/<family>/` directory.  Each patch ends with a `WindowOUT` sink for visual verification.

**Note:** This script does NOT auto-run when you regenerate registries.  You must run it separately after adding a new operator.

### `help_patch_engine.py`

Shared library used by `generate_help_patches.py` and family-specific patch modules (`patches_chop.py`, etc.).  Provides template builders, node placement helpers, and registry loading.  Not run standalone.

### `patches_chop.py`

Hand-crafted CHOP family patch definitions (3 per operator: basic, feature, advanced).  Imported by `generate_help_patches.py`.

### `check_coverage.py` / `check_coverage_fast.py`

Reports which operators have fewer than 3 help patches.

```
python scripts/check_coverage.py        # full registry-aware matching
python scripts/check_coverage_fast.py   # fast filename-based fuzzy match
```

### `count_patches.py`

Counts `.gnpatch` files per family across all `help/` directories.

```
python scripts/count_patches.py
```

### `clone_native_help_patches.py`

Clones help patches from GDScript operators to their Native C++ wrapper variants (e.g., CopyCHOP patches are duplicated for CopyCHOPNative). Reads class mappings from `operator_registry.json`.

```
python scripts/clone_native_help_patches.py
```

### `regen_broken_patches.py`

Regenerates `.gnpatch` files whose focus operator node is missing or structurally invalid. Uses `help_patch_engine.py` for generation.

```
python scripts/regen_broken_patches.py
```

---

## Validation & Auditing

### `verify_new_operator.py`

**Run this after adding any new operator.**  Checks all integration touchpoints:

1. Operator `.gd` file exists with correct structure
2. Registration in `gn_core.cfg` or `gn_extension.cfg`
3. Help patches exist (minimum 1, target 3)
4. `operator_registry.json` is up to date
5. `port_registry.json` is up to date
6. `docs/OPERATORS.md` lists the operator
7. Operator count in docs is consistent
8. Test file covers the operator's family

```
python scripts/verify_new_operator.py FilterTOP        # single operator
python scripts/verify_new_operator.py --all            # check every operator
python scripts/verify_new_operator.py --recent         # find operators missing from registries
python scripts/verify_new_operator.py FilterTOP --auto-register  # register in gn_core.cfg + verify
```

The `--auto-register` flag reads the operator's `##` docstring and `extends` base class to
automatically append an `[operator.ClassName]` section to `gn_core.cfg` with the correct family,
script path, and description.  Skips if already registered.

### `validate_all_patches.py`

Comprehensive `.gnpatch` structural validator — checks port type mismatches, index out-of-range, orphan nodes, missing sinks, unknown class names.

```
python scripts/validate_all_patches.py
python scripts/validate_all_patches.py --path tests/SmokeTestEditor/
```

### `audit_labels.py`

Reports multi-port operators that lack descriptive labels on `add_input()` / `add_output()` calls.

```
python scripts/audit_labels.py
```

### `check_node_types.py`

Lists every `node_type` string across all operator files.  Useful for spotting duplicates or typos.

```
python scripts/check_node_types.py
```

---

## Operator Metadata

### `catalog_operators.py`

Full metadata extraction (class_name, node_type, ports, parameters) — similar to `scan_operators.py` but includes port data.

```
python scripts/catalog_operators.py
```

### `extract_ports.py`

Extracts raw `add_input()` / `add_output()` calls from every operator's `_init_ports()`.

```
python scripts/extract_ports.py
```

### `list_ops.py`

Pretty-prints all operators grouped by family from `operator_registry.json`.

```
python scripts/list_ops.py
```

### `gen_native_operators_md.py`

Auto-generates the Native Acceleration Extension section of `docs/OPERATORS.md` by scanning native wrapper descriptions from `gn_extension.cfg`.

```
python scripts/gen_native_operators_md.py
```

---

## Refactoring

### `rename_node.py`

Renames an operator class across the entire workspace: `.gd` files, `.cfg` registration, `.gnpatch` files, tests, docs, registries.

```
python scripts/rename_node.py OldClassName NewClassName
python scripts/rename_node.py OldClassName NewClassName --dry-run
```

Always use `--dry-run` first to review changes.

---

## Build & Release

### `build_templates.ps1` / `build_templates.sh`

Build GONODES Player (and optionally Editor) export binaries for all platforms.  See [BUILD.md](BUILD.md) for full usage.

```powershell
# Windows
.\scripts\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"
```
```bash
# Linux / macOS
./scripts/build_templates.sh --godot /path/to/godot
```

### `check_versions.py`

Validates that all CI workflows, `setup_deps.py`, and `project.godot` agree on versions defined in `versions.env`.

```
python scripts/check_versions.py
```

### `check_env.py`

Pre-flight check for the entire build environment. Verifies required tools (Python, SCons, C++ compiler, Godot editor), godot-cpp clone and built libraries, and all extension SDK dependencies.

SDK requirements are discovered **programmatically** from each extension's `native/build.cfg` — no hardcoded SDK list.

```
python scripts/check_env.py           # full report
python scripts/check_env.py --strict   # treat warnings as errors (CI)
```

### `check_builds.py`

Verifies that all native extensions have the expected shared libraries (`.dll`, `.so`, `.dylib`) in their `bin/` directories. Extensions are discovered programmatically from `build.cfg` files.

```
python scripts/check_builds.py              # current platform
python scripts/check_builds.py --all        # all platforms
python scripts/check_builds.py --platform linux   # specific platform
```

### `bundle_toolchain.py`

Copies built godot-cpp headers and release static libraries into `addons/gn_ext_user_native/toolchain/godot-cpp/` so end-users can compile custom C++ operators without installing Godot or cloning repos.

```
python scripts/bundle_toolchain.py              # current platform
python scripts/bundle_toolchain.py --all        # all shipping platforms
python scripts/bundle_toolchain.py --verify     # check without copying
```

### `sync_gdextensions.py`

Activates or deactivates `.gdextension` files based on whether the referenced
platform binary exists on disk. Mirrors the GDScript
`GNExtensionRegistry.sync_native_extensions()` logic but runs outside Godot,
eliminating the two-restart problem after building.

Also runs automatically as a post-build step in `build/SConstruct`.

```
python scripts/sync_gdextensions.py                      # auto-detect platform
python scripts/sync_gdextensions.py --dry-run             # preview only
python scripts/sync_gdextensions.py --platform linux      # cross-platform check
```

### `clean_builds.py`

Removes all compiled native extension binaries (`native/bin/` directories),
deactivates all `.gdextension` files, and cleans bundled toolchains. Used
before release tagging to return the repository to source-only state.

```
python scripts/clean_builds.py              # remove + deactivate
python scripts/clean_builds.py --dry-run    # preview only
```

After a fresh clone and build, `sync_gdextensions.py` (or the SConstruct
post-build hook) re-activates extensions whose binaries exist.

### `gen_manual_test_patches.py`

Generates one-per-operator manual test `.gnpatch` files for GPU/visual families that need human review (TOP, SOP, COMP).

```
python scripts/gen_manual_test_patches.py
```

Output goes to `tests/manual/<family>/`.

### `gen_all_core_patches.py`

Generates comprehensive `ALL_CORE_*.gnpatch` test patches covering every registered operator, organized by family into SwitchTOP/SwitchCHOP/SwitchSOP chains. Used for full manual QA sweeps before release.

```
python scripts/gen_all_core_patches.py
```

Output goes to `tests/manual/`. Required before release QA (see RELEASE_CHECKLIST.md).

---

## New Operator Checklist (script sequence)

After creating a new operator `.gd` file:

```bash
# 1. Register in gn_core.cfg (auto-populates from ## docstring)
python scripts/verify_new_operator.py MyNewTOP --auto-register

# 2. Regenerate registries
python scripts/scan_operators.py
python scripts/build_port_registry.py

# 3. Generate help patches
python scripts/generate_help_patches.py --operator my_new

# 4. Final verification
python scripts/verify_new_operator.py MyNewTOP

# 5. (If needed) Validate all patches are structurally sound
python scripts/validate_all_patches.py
```

Don't forget to also:
- Add the operator to `docs/OPERATORS.md`
- Update operator counts in README.md, TESTING.md, GONODES_VS_THE_REST.md, release.yml
