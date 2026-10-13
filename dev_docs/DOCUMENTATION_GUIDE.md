# GONODES Documentation Guide

This document describes every documentation file in the project, what it covers,
and the rules contributors must follow when making changes that affect docs.

---

## Documentation Map

### Root Files

| File | Purpose |
|------|---------|
| `README.md` | Public page — what GONODES is, how to start, links onward. No operator or extension tables |
| `ai/README.md` | Shared brief for any language model, including the setup prompt |
| `ai/RULES.md` | Hard rules. The only full copy |
| `llms.txt` | Patch-writing brief for any model. Stays at the repo root |
| `GONODES_CONTEXT.md` | Comprehensive architecture reference — every class, file, pattern, and design decision |
| `CHANGELOG.md` | Release-level change log (user-facing) |
| `LICENSE` | Project license |

### `docs/` — User Documentation

| File | Purpose |
|------|---------|
| `docs/OPERATORS.md` | Operator reference — every operator listed by family with port/parameter tables, quick reference counts |

### `dev_docs/` — Developer Documentation

| File | Purpose |
|------|---------|
| `dev_docs/README.md` | Index of developer docs |
| `dev_docs/BUILD.md` | Build instructions (Godot, SConstruct, CI) |
| `dev_docs/CONTRIBUTING.md` | Contributor guide — coding style, method names, PR workflow |
| `dev_docs/COOK_ENGINE.md` | Cook engine architecture — frame loop, topo sort, expression eval |
| `dev_docs/DATA_TYPES.md` | GNData subclasses — GNTextureData, GNChannelData, GNTableData, etc. |
| `dev_docs/EDITOR.md` | Editor UI architecture — panels, toolbar, viewer, inspector, shortcuts |
| `dev_docs/EXTENSIONS.md` | Extension system — gn_extension.cfg, registration, lifecycle |
| `dev_docs/GPU_ARCHITECTURE.md` | GPU pipeline — SubViewport lifecycle, compute shaders, VRAM management |
| `dev_docs/INTEGRATION.md` | Host integration — LibGONODES C API, embedding in other apps |
| `dev_docs/NATIVE_AUDIT.md` | Native C++ operator audit — which ops have native versions, performance notes |
| `dev_docs/NEW_OPERATOR_CHECKLIST.md` | Step-by-step checklist for adding a new operator |
| `dev_docs/PLAYER.md` | Player/runtime architecture — headless cook, export, standalone builds |
| `dev_docs/RELEASE_CHECKLIST.md` | Release process — version bumps, CI, changelogs, packaging |
| `dev_docs/ROADMAP.md` | Feature roadmap — phased plan with priorities |
| `dev_docs/SCRIPTS.md` | Script utilities reference — what each `scripts/*.py` tool does |
| `dev_docs/TESTING.md` | Testing guide — running tests, writing tests, coverage targets |
| `dev_docs/TIMELINE.md` | Timeline & transport system — expression functions, TimelineCHOP |
| `dev_docs/TIMELINE_DESIGN_PHILOSOPHY.md` | Design rationale for the timeline approach |
| `dev_docs/GONODES_VS_THE_REST.md` | Comparison matrix — GONODES vs TouchDesigner/vvvv/Max/etc. |
| `dev_docs/VDMX_VUO_AUDIT.md` | LibGONODES integration audit for VDMX and Vuo hosts |
| `dev_docs/PATTERNS.md` | Common code patterns and idioms used across the codebase |

### `libgonodes/` — C API Library

| File | Purpose |
|------|---------|
| `libgonodes/README.md` | LibGONODES overview — API, examples, build instructions |

### Extension READMEs (`addons/gn_ext_*/README.md`)

Each extension has its own README documenting:
- What the extension provides
- Native dependencies and build requirements
- Operator list
- Platform support

---

## Rules for Updating Documentation

### When Adding a New Operator

1. **`docs/OPERATORS.md`** — Add the operator to its family section with full port/parameter table
2. **`docs/OPERATORS.md`** is the count. The root `README.md` does not list operator totals. Do not add them back
3. **`dev_docs/TESTING.md`** — Update total test count and file count after adding tests
4. **`dev_docs/GONODES_VS_THE_REST.md`** — Update the operator count row
5. **`GONODES_CONTEXT.md`** — Update section 35.11 totals if counts changed
6. **Registries** — Run `python scripts/scan_operators.py` and `python scripts/build_port_registry.py`
7. **Help patches** — Run `python scripts/generate_help_patches.py --operator <node_type>`
8. **Verification** — Run `python scripts/verify_new_operator.py <ClassName>`

See `dev_docs/NEW_OPERATOR_CHECKLIST.md` for the complete step-by-step process.

### When Adding a Native C++ Operator

All of the above, plus:
1. **`dev_docs/NATIVE_AUDIT.md`** — Update the native operator table and counts
2. **Extension `gn_extension.cfg`** — Add `[operator.ClassName]` entry
3. **`register_types.cpp`** — Add include and `ClassDB::register_class<>()`

### When Modifying the Cook Engine

1. **`dev_docs/COOK_ENGINE.md`** — Update affected sections
2. **`GONODES_CONTEXT.md`** — Update the cook engine section if architecture changed
3. **`dev_docs/TIMELINE.md`** — Update if expression functions or transport changed

### When Modifying the Editor UI

1. **`dev_docs/EDITOR.md`** — Update affected UI sections
2. **`GONODES_CONTEXT.md`** — Update editor architecture sections

### When Modifying Data Types

1. **`dev_docs/DATA_TYPES.md`** — Update the affected data class section
2. **`GONODES_CONTEXT.md`** — Update data type table

### When Adding/Modifying an Extension

1. **Extension `README.md`** — Create or update
2. **`dev_docs/EXTENSIONS.md`** — Update if extension system mechanics changed
3. **`addons/gonodes/help/extensions.md`** — Update if the user-facing extension guide changed. The root `README.md` does not list extensions

### When Changing Method Names or API

1. **`dev_docs/CONTRIBUTING.md`** — Update code examples to use correct method names
2. **`dev_docs/NEW_OPERATOR_CHECKLIST.md`** — Update method name references
3. **`GONODES_CONTEXT.md`** — Update API tables

### When Making a Release

Follow `dev_docs/RELEASE_CHECKLIST.md` — it covers version bumps, CHANGELOG updates,
README updates, and all files that reference version numbers.

---

## Authoritative Sources

When in doubt about counts or facts, these are the sources of truth:

| Fact | Source |
|------|--------|
| Operator count | `python scripts/scan_operators.py` → `scripts/operator_registry.json` |
| Port definitions | `python scripts/build_port_registry.py` → `scripts/port_registry.json` |
| Help patch count | `python scripts/check_coverage.py` |
| Test count | `grep -r "func test_" tests/ \| wc -l` |
| Extension count | `ls addons/gn_ext_*` |
| Native operator count | Count `*_native.gd` files in `addons/gn_ext_native/operators/` |

---

## Encoding

All documentation files are **UTF-8 without BOM**. When editing with PowerShell,
always use `-Encoding UTF8` on both `Get-Content` and `Set-Content`. Prefer
Python for any automated text manipulation. See the encoding notes in the
project's contributing guide.
