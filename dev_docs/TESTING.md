# GONODES Testing Guide

> **Audience:** Contributors writing or running tests.  
> **Last updated:** 2026-03-27  
> **Total automated tests:** 1,355 across 31+ test files — all passing

---

## Table of Contents

1. [Philosophy](#1-philosophy)
2. [Test Framework Architecture](#2-test-framework-architecture)
3. [Running Tests](#3-running-tests)
4. [Unit Tests](#4-unit-tests)
5. [Integration Tests](#5-integration-tests)
6. [Functional Tests](#6-functional-tests)
7. [Extension Tests](#7-extension-tests)
8. [Manual Test Patches](#8-manual-test-patches)
9. [Manual Test Scenes (Legacy)](#9-manual-test-scenes-legacy)
10. [Writing New Tests](#10-writing-new-tests)
11. [What Is and Isn't Tested](#11-what-is-and-isnt-tested)
12. [Bugs Found by Tests](#12-bugs-found-by-tests)
13. [Directory Layout](#13-directory-layout)

---

## 1. Philosophy

GONODES uses a **four-layer testing strategy** designed around the constraints of a GPU-accelerated, Godot-based node graph:

| Layer | Runs | Verifies | Requires GPU? |
|-------|------|----------|--------------|
| **Unit tests** | Headless CLI | Individual classes (GNParameter, GNNetwork, GNCookEngine, GNChannelData, GNParamPresetManager) in isolation | No |
| **Operator tests** | Headless CLI | All 533 operators — instantiation, parameter defaults, cook-without-crash, output type correctness | No |
| **Functional tests** | Headless CLI | Output **correctness** — vertex positions, channel values, table contents, bounding boxes, topology changes | No |
| **Integration tests** | Headless CLI | Full `cook_frame()` pipeline through multi-node networks with real operator instances | No |
| **Manual test patches** | Editor (visual) | GPU rendering, shader compilation, visual output, particle systems, volumetrics, materials | Yes |

The framework is **completely dependency-free** — no GdUnit4, GUT, or any third-party test plugin. Everything is pure GDScript that ships with the project and runs via Godot's `--headless` mode.

### Design Principles

- **Non-throwing assertions.** Each test can report multiple failures without aborting early, giving a complete picture of what's wrong.
- **Scene-tree integration.** Test instances are added to the SceneTree root so `add_child()`, signals, and node lifecycle work identically to production code.
- **Zero GPU dependency for automated tests.** Unit and integration tests exercise the cook engine, parameter system, network graph, and data model — all CPU-side logic. GPU-dependent operators (TOPs that use SubViewport) are covered by manual test scenes.
- **Recursive discovery.** The runner scans `tests/` recursively and `addons/gn_ext_*/tests/` directories, so adding a test file in any subfolder is automatically picked up.
- **Self-contained extensions.** Each `gn_ext_*` extension keeps its own test file(s) in `addons/gn_ext_<name>/tests/`, keeping extension code, operators, help patches, and tests co-located.

---

## 2. Test Framework Architecture

The framework consists of two core files:

### GNTestRunner (`tests/test_runner.gd`)

A SceneTree-based runner that:

1. **Discovers** all `test_*.gd` files recursively under `res://tests/` and `res://addons/gn_ext_*/tests/` (excluding `test_runner.gd` and `test_assert.gd`).
2. **Filters** discovered scripts by `--test-tag` (core, integration, extension, patch) and/or `--test-filter` (substring match on method names).
3. **Instantiates** each test script as a Node and adds it to `root` so the scene tree is available.
4. **Collects** all methods starting with `test_` via `get_method_list()`, sorts them alphabetically, and runs them in sequence.
5. **Invokes lifecycle hooks** if present: `before_all()`, `after_all()`, `before_each()`, `after_each()`.
6. **Checks** `GNTestAssert._failure_count` after each test method to determine pass/fail.
7. **Prints** a summary and exits with code 0 (all passed) or 1 (any failures).

### GNTestAssert (`tests/test_assert.gd`)

A static assertion library (`class_name GNTestAssert`) with 15+ assertions across four categories:

**Core assertions:**
- `assert_true(condition, msg)` / `assert_false(condition, msg)`
- `assert_eq(actual, expected, msg)` / `assert_ne(actual, unexpected, msg)`
- `assert_null(actual, msg)` / `assert_not_null(actual, msg)`

**Numeric assertions:**
- `assert_approx(actual, expected, tolerance, msg)` — float equality within tolerance
- `assert_vec3_approx(actual, expected, tolerance, msg)` — Vector3 per-component tolerance
- `assert_gt(actual, threshold, msg)` / `assert_lt(actual, threshold, msg)`
- `assert_in_range(actual, min_val, max_val, msg)`

**String assertions:**
- `assert_contains(haystack, needle, msg)`
- `assert_empty(text, msg)` / `assert_not_empty(text, msg)`

**Collection assertions:**
- `assert_size(collection, expected_size, msg)` — works with Array, Dictionary, PackedStringArray
- `assert_has_key(dict, key, msg)`
- `assert_array_eq(actual, expected, msg)` — element-by-element equality for any array type

**Type assertions:**
- `assert_is(actual, type_name, msg)` — checks class name or script class name

All assertions call `_fail(msg)` which increments `_failure_count` and stores the message — they do **not** throw, so multiple assertions per test are possible.

---

## 3. Running Tests

### Prerequisites

- Godot 4.6 editor binary on your system path (or specify the full path)
- No additional plugins or packages required

### Run all tests

```bash
godot --headless --path /path/to/Gonodes -s tests/test_runner.gd
```

On Windows with the project's Godot build:

```powershell
& "C:\Ford\Godot\godot\bin\godot.windows.editor.x86_64.console.exe" --headless --path "C:\MeOwn\Gonodes" -s tests/test_runner.gd
```

### Filter by name

```bash
godot --headless --path /path/to/Gonodes -s tests/test_runner.gd --test-filter=parameter
godot --headless --path /path/to/Gonodes -s tests/test_runner.gd --test-filter=chop_chain
godot --headless --path /path/to/Gonodes -s tests/test_runner.gd --test-filter=roundtrip
```

The filter is case-insensitive and matches against test method names using `containsn()`.

### Filter by tag

```bash
# Run only core unit tests (tests/ except integration/ and functional/)
godot --headless -s tests/test_runner.gd --test-tag=core

# Run only functional correctness tests (tests/functional/)
godot --headless -s tests/test_runner.gd --test-tag=functional

# Run only integration tests (tests/integration/)
godot --headless -s tests/test_runner.gd --test-tag=integration

# Run only extension tests (addons/gn_ext_*/tests/)
godot --headless -s tests/test_runner.gd --test-tag=extension

# Run only the .gnpatch smoke test
godot --headless -s tests/test_runner.gd --test-tag=patch
```

Tags and filters can be combined: `--test-tag=core --test-filter=box`

### Understanding the output

```
═══════════════════════════════════════════════════
  GONODES Unit Test Runner
═══════════════════════════════════════════════════

── test_chop_chains ──
  ✓ test_constant_to_null_passthrough
  ✓ test_constant_plus_scalar
  ✗ test_some_broken_test — Expected '42' == '43'. values should match

═══════════════════════════════════════════════════
  ALL PASSED — 1355 tests

    ✗ test_chop_chains::test_some_broken_test — Expected '42' == '43'. values should match
═══════════════════════════════════════════════════
```

- `✓` = passed
- `✗` = one or more assertions failed (the first failure message is shown)
- Exit code `0` = all passed, `1` = failures present
- `SCRIPT ERROR` lines from expected error-path tests (e.g., syntax error in GDScriptSCRIPT) are normal

---

## 4. Unit Tests

Unit tests live directly in `tests/` and focus on **individual core classes in isolation**, using mock/minimal setups rather than full operator instances.

### test_parameter.gd — 47 tests

Tests the `GNParameter` class, the foundation of the entire parameter system.

| Category | Tests | What's covered |
|----------|-------|----------------|
| Factory constructors | 8 | `create_float`, `create_int`, `create_bool`, `create_string`, `create_enum`, `create_vector2`, `create_color`, `create_file` — verifies default values, types, labels |
| Value & signals | 1 | `set_value` emits `value_changed` signal |
| Clamping | 3 | Min/max enforcement, null limits bypass clamping |
| Mode switching | 4 | CONSTANT ↔ EXPRESSION mode transitions, `mode_changed` signal, resolved value in each mode |
| Reset | 1 | `reset_to_defaults()` restores factory values |
| References | 5 | `set_param_reference`, `set_chop_reference` with scale/offset/negative-offset |
| Expression validation | 3 | Valid expressions compile, invalid expressions report errors, empty expressions are invalid |
| Per-component | 6 | Component labels for Vector2/Color, set/get component expressions, component constant restores overall mode |
| Serialization | 5 | `to_dict`/`from_dict` round-trip for float, expression, Vector2, Color, component expressions |
| Legacy migration | 3 | BIND → EXPRESSION, EXPORT → CONSTANT, unknown mode → CONSTANT fallback |
| Variant helpers | 4 | `variant_to_json`/`json_to_variant` for Vector3, Color; roundtrip primitives |

### test_cook_engine.gd — 24 tests

Tests `GNCookEngine` expression evaluation and parameter resolution in isolation (no `cook_frame()` pipeline).

| Category | Tests | What's covered |
|----------|-------|----------------|
| Expression eval | 6 | Constant values, `time`/`frame`/`dt` variables, arithmetic, math functions (`sin`, `abs`, `sqrt`) |
| `par()` functions | 6 | Self-reference, self-reference with math, cross-node reference, expression target, `parf()` float cast, `pari()` int cast, `pars()` string cast |
| `chop()` function | 2 | Read channel value, nonexistent channel returns 0.0 |
| `chops()`/`chopf()`/`chopi()` | — | Typed CHOP variants (string, float, int) |
| Circular guards | 2 | Self-referencing expression, mutual reference cycle — both resolve safely |
| Component expressions | 2 | Vector2 `.x`/`.y` per-component, Color `.r`/`.g`/`.b` per-component |
| Error recovery | 2 | Invalid expression falls back to constant, valid expression updates fallback |
| Node resolution | 3 | Flat path lookup, not-found returns null, empty path returns null |

### test_network.gd — 22 tests

Tests `GNNetwork` graph model operations.

| Category | Tests | What's covered |
|----------|-------|----------------|
| Node management | 5 | Add, add duplicate (fails), remove, remove nonexistent (fails), get-by-id returns null |
| Connections | 4 | Connect, connect nonexistent (fails), disconnect, get input connections |
| Topology | 4 | Topo sort basic (A→B→C), topo sort diamond, disconnected nodes included, cleanup on node removal |
| Cycle detection | 2 | No cycle on linear chain, no cycle on empty graph |
| Dirty propagation | 2 | Marks all downstream dirty, upstream stays clean |
| Rename | 2 | Rename node ID, rename updates connection references |
| ID generation | 1 | Generates unique IDs avoiding collisions |
| Serialization | 2 | `to_dict` structure matches expected format, empty network serializes cleanly |

### test_channel_data.gd — 14 tests

Tests `GNChannelData`, the core data container for CHOP operators.

| Category | Tests | What's covered |
|----------|-------|----------------|
| Basic I/O | 2 | Set single value, set multi-sample channel |
| Index behavior | 3 | Negative index returns last, default index returns last, out-of-range returns last with warning |
| Missing data | 2 | Get missing channel returns null, get value from missing channel returns 0.0 |
| Channel names | 2 | Returns correct names array, empty data returns empty array |
| Metadata | 2 | `length` tracks largest channel, default sample rate |
| Lifecycle | 1 | `invalidate()` clears all channels |
| Deep copy | 1 | `duplicate_data()` produces independent clone |
| Family | 1 | Family property returns `CHOP` |

### test_preset_manager.gd — 11 tests

Tests `GNParamPresetManager` clipboard and preset operations.

| Category | Tests | What's covered |
|----------|-------|----------------|
| Clipboard state | 2 | Empty clipboard, cannot paste with empty clipboard |
| Copy | 3 | Copy populates clipboard, copy overwrites previous, copy null node is safe |
| Paste | 3 | Can paste same type, paste restores values, cannot paste different operator type |
| Null safety | 2 | Can-paste with null node returns false, paste on null node is no-op |
| Reset | 1 | `reset_to_defaults()` restores factory parameter values |

---

## 5. Integration Tests

Integration tests live in `tests/integration/` and exercise the **full `cook_frame()` pipeline** — from parameter resolution through topological sorting, dirty propagation, input gathering, and operator cook — using real operator class instances.

### Common pattern

Every integration test suite follows this structure:

```gdscript
var _engine: GNCookEngine
var _network: GNNetwork

func before_each() -> void:
    _engine = GNCookEngine.new()
    _network = GNNetwork.new()
    _engine.set_network(_network)
    _engine.cooking_enabled = false   # manual control

func _make_node(script_class, id: String) -> GNNode:
    var node = script_class.new()
    node.initialize(id)
    _network.add_node(id, node)
    add_child(node)    # needed for scene tree integration
    return node

func _cook_one_frame(delta := 1.0 / 60.0) -> void:
    _engine.cooking_enabled = true
    _engine.cook_frame(delta)
    _engine.cooking_enabled = false
```

### test_chop_chains.gd — 13 tests

End-to-end CHOP operator chain cooking.

| Test | What it verifies |
|------|------------------|
| `test_constant_to_null_passthrough` | ConstantCHOP output passes through NullCHOP unchanged |
| `test_constant_plus_scalar` | ConstantCHOP(5) → MathCHOP(Add, value=10) produces 15 |
| `test_constant_multiply_scalar` | ConstantCHOP(3) → MathCHOP(Multiply, value=4) produces 12 |
| `test_two_constants_binary_add` | Two ConstantCHOPs(7, 3) → MathCHOP(Add) produces 10 |
| `test_three_node_chain` | Constant(5) → Math(×2) → Math(+100) produces 110 |
| `test_merge_chop_combines_channels` | Two ConstantCHOPs → MergeCHOP combines both channels |
| `test_expression_par_ref_through_cook` | `par("other_node", "value0")` expression resolves through cook_frame |
| `test_expression_chop_ref_through_cook` | `chop("upstream")["chan1"]` expression resolves through cook_frame |
| `test_dirty_propagation_recooks_downstream` | Changing upstream value recooks all downstream nodes |
| `test_diamond_topology` | A → B, A → C, B+C → D diamond graph produces correct merged result |
| `test_bypass_passes_input_through` | Bypassed MathCHOP passes input through unchanged |
| `test_multi_channel_math` | MathCHOP operates on all channels of multi-channel input |
| `test_time_expression_in_cook` | Expression using `time` variable resolves correctly during cook_frame |

### test_script_chop.gd — 7 tests

GDScriptSCRIPT operator (CHOP template) with runtime GDScript compilation.

| Test | What it verifies |
|------|------------------|
| `test_script_chop_basic_output` | Script that sets `op["chan1"] = [42.0]` produces correct output |
| `test_script_chop_uses_time` | Script using `time * 100.0` produces frame-time-dependent output |
| `test_script_chop_custom_param` | `@param gain float 2.0` annotation creates parameter, script reads it via `par("gain")` |
| `test_script_chop_reads_input` | Filter script reads upstream ConstantCHOP input and multiplies by 2 |
| `test_script_chop_multi_channel` | Script creating 3 channels (`x`, `y`, `z`) produces correct multi-channel output |
| `test_script_chop_syntax_error_graceful` | Intentionally broken syntax doesn't crash — node cooks with error state |
| `test_script_to_math_chain` | GDScriptSCRIPT(10) → MathCHOP(×3) produces 30 through the full pipeline |

### test_network_roundtrip.gd — 6 tests

Network serialization (`to_dict()` / `from_dict()`) round-trip fidelity.

| Test | What it verifies |
|------|------------------|
| `test_empty_network_roundtrip` | Empty network serializes and deserializes to zero nodes, zero connections |
| `test_single_node_params_preserved` | Node parameters survive round-trip with correct values |
| `test_connections_preserved` | Connection `from`/`to`/`from_port`/`to_port` survive serialization |
| `test_expression_param_roundtrip` | Expression-mode parameter retains its expression string after round-trip |
| `test_chain_cook_after_deserialize` | Constant(5) → Math(×2) → Null chain produces 10 after deserialize + cook |
| `test_node_count_preserved` | Number of nodes matches before and after serialization |

### test_gnpatch_smoke.gd — 4 tests

Bulk smoke test that loads every `.gnpatch` help file across core and extensions (1,413 patches), deserializes each into a GNNetwork, and verifies structural integrity.

| Test | What it verifies |
|------|------------------|
| `test_patches_discovered` | At least 100 `.gnpatch` files found across `addons/gonodes/help/` and `addons/gn_ext_*/help/` |
| `test_all_patches_load` | Every discovered patch deserializes via `GNNetwork.from_dict()` without error |
| `test_all_patches_have_nodes` | Every loaded patch contains at least one node (no empty patches) |
| `test_all_patches_have_valid_connections` | All connections reference nodes that exist in the loaded network (no dangling edges) |

Run the patch smoke test alone: `--test-tag=patch`

### test_cook_chain.gd — 8 tests

Multi-node cook chain integration tests that wire real operators through GNNetwork connections and cook via `GNCookEngine.cook_frame()`. Verifies the full pipeline: input gathering, topological sort, dirty propagation, and output correctness.

| Test | What it verifies |
|------|------------------|
| `test_box_into_transform_sop` | Box → TransformSOP(ty=5) — all verts shifted up |
| `test_box_into_null_sop_passthrough` | Box → NullSOP passes geometry through |
| `test_sop_three_node_chain` | Box → Transform → Null — end of chain has valid output |
| `test_constant_into_null_chop` | Constant(42) → NullCHOP preserves value |
| `test_constant_into_math_chop` | Constant(10) → Math(gain=2) produces 20 |
| `test_constant_dat_into_null_dat` | ConstantDAT → NullDAT passes data through |
| `test_dat_into_transpose_chain` | TextDAT(CSV) → TransposeDAT produces rows |
| `test_dirty_propagation_through_chain` | Upstream param change propagates through to downstream |

---

## 6. Functional Tests

Functional tests live in `tests/functional/` and verify **output correctness** — not just that operators instantiate or cook without errors, but that the results contain the right values. Run them with `--test-tag=functional`.

### test_sop_functional.gd — ~70 tests

Verifies SOP operators produce geometrically correct output.

| Category | Examples |
|----------|----------|
| **Generator bounds** | BoxSOP vertices within `±size/2`, SphereSOP vertices on sphere surface, GridSOP flat on Y=0 |
| **Transform correctness** | TransformSOP(tx=10) shifts all verts right, scale=2 doubles AABB, rotation preserves vert count |
| **Topology changes** | SubdivideSOP increases vert count, MergeSOP vert sum = inputs' sum, FuseSOP reduces duplicate verts |
| **Normal correctness** | NormalSOP flip mode negates normals, recompute produces unit-length normals, ReverseSOP flips winding |
| **Deformation** | PeakSOP grows AABB, NoiseSOP displaces verts, BendSOP/TwistSOP/TaperSOP modify positions |
| **Clip / Delete** | ClipSOP removes verts below plane, DeleteSOP reduces vert count |
| **Scatter** | ScatterSOP outputs exact requested count, same seed = same positions |
| **Copy / Extrude** | CopySOP multiplies template by point count, ExtrudeSOP adds geometry |
| **Procedural generators** | MetaballSOP, IsoSurfaceSOP, HeightfieldSOP, LSystemSOP all produce valid geometry |
| **Complex ops** | VoronoiShatterSOP produces multiple surfaces, BooleanSOP executes, WireframeSOP adds tube geometry |

### test_chop_functional.gd — ~70 tests

Verifies CHOP operators produce correct channel values.

| Category | Examples |
|----------|----------|
| **Generators** | ConstantCHOP value match, WaveCHOP sine in [-1,1], LFO amplitude range, NoiseCHOP has variation |
| **Math** | MathCHOP add/multiply/abs with constant operand, two-input add, AbsoluteCHOP makes positive |
| **Merge / Split** | MergeCHOP combines channels from both inputs, SplitCHOP extracts single channel |
| **Analysis** | AnalyzeCHOP max/min extract correct values, SlopeCHOP of ramp is positive, of constant is zero |
| **Mapping** | MapCHOP remaps [0,1] → [0,100], QuantizeCHOP snaps to step, LimitCHOP clamps to range |
| **Time-domain** | LagCHOP smooths step transitions, DelayCHOP shifts signal, SpeedCHOP integrates |
| **Logic** | LogicCHOP AND truth table, CompareCHOP greater-than threshold |
| **Crossfade** | CrossCHOP at weight=0.5 produces midpoint, InterpolateCHOP blends two inputs |
| **Rename / Select** | RenameCHOP changes channel name and removes old, SelectCHOP filters by wildcard pattern |
| **Passthrough** | NullCHOP preserves value, SwitchCHOP selects correct input |

### test_dat_functional.gd — ~56 tests

Verifies DAT operators produce correct table/text content.

| Category | Examples |
|----------|----------|
| **Generators** | TableDAT outputs table, TextDAT text matches, ConstantDAT value present, CSVDAT parses CSV rows |
| **Sort / Filter** | SortDAT ascending by column, FilterDAT by pattern reduces rows, UniqueDAT removes duplicates |
| **Merge / Split** | MergeDAT stacks rows (sum), TransposeDAT swaps rows↔cols, double transpose restores original |
| **Modify** | SubstituteDAT find/replace, DeleteDAT removes rows, InsertDAT adds rows, RenameDAT changes headers |
| **Format** | JSONDAT parse/generate, XMLDAT parse, YAMLDAT parse, ConvertDAT table→text, FormatDAT with template |
| **Lookup** | LookupDAT finds row by key, ConcatenateDAT joins text |
| **Passthrough** | NullDAT preserves table and text, SwitchDAT selects correct input |

---

## 7. Extension Tests

Extension tests live in `addons/gn_ext_<name>/tests/` and are **self-contained** alongside the extension's operators, help patches, and native code. The test runner discovers them automatically by scanning `res://addons/gn_ext_*/tests/` directories.

### Architecture

Each extension has one test file (e.g., `test_<ext>_operators.gd`) that follows the same pattern as core operator tests: `before_each()`/`after_each()` lifecycle, `_make_node()`, `_cook_no_input()`, and `_cook_with()` helpers.

### Extension test inventory (287 tests across 18 extensions)

| Extension | File | Tests | Key operators |
|-----------|------|-------|---------------|
| **gn_ext_native** | `test_native_operators.gd` | 176 | All `*Native` variants: 24 CHOP, 32 SOP, 9 POP, 7 VOL, 5 IMG |
| **core (SDF)** | `test_sdf_operators.gd` | 53 | All SDF operators + MaterialSDF |
| **gn_ext_mapper** | `test_mapper_operators.gd` | 14 | BezierMap, EdgeBlend, GridWarp, ProjectionMask, ProjectorBlend, QuadMap, Stoner |
| **gn_ext_ml** | `test_ml_operators.gd` | 7 | DepthEstimate, Segmentation, StyleTransfer, FaceDetect, HandDetect, PoseDetect, ObjectDetect |
| **gn_ext_depth_sensor** | `test_depth_sensor_operators.gd` | 5 | DepthSensorTOP/DAT, DepthPointCloudSOP, DepthHandCHOP, DepthSkeletonCHOP |
| **gn_ext_user_native** | `test_user_native_operators.gd` | 5 | CHOP, TOP, SOP, DAT, IMG user-native variants |
| **gn_ext_user_python** | `test_user_python_operators.gd` | 5 | CHOP, TOP, SOP, DAT, IMG user-python variants |
| **gn_ext_ndi** | `test_ndi_operators.gd` | 4 | NDI In/Out TOP, NDI Audio In/Out CHOP |
| **gn_ext_blackmagic** | `test_blackmagic_operators.gd` | 3 | BlackmagicIn/Out TOP, BlackmagicDAT |
| **gn_ext_midi** | `test_midi_operators.gd` | 2 | RtMidiIn/Out CHOP |
| **gn_ext_ffmpeg** | `test_ffmpeg_operators.gd` | 2 | FFmpegInTOP |
| **gn_ext_hap** | `test_hap_operators.gd` | 2 | HapInTOP |
| **gn_ext_spout** | `test_spout_operators.gd` | 2 | SpoutIn/Out TOP |
| **gn_ext_syphon** | `test_syphon_operators.gd` | 2 | SyphonIn/Out TOP |
| **gn_ext_shadertoy** | `test_shadertoy_operators.gd` | 2 | ShadertoyTOP |
| **gn_ext_isf** | `test_isf_operators.gd` | 1 | ISFTOP |
| **gn_ext_gpu_encode** | `test_gpu_encode_operators.gd` | 1 | MovieFileOutTOP |
| **gn_ext_video_capture** | `test_video_capture_operators.gd` | 1 | VideoDeviceInIMG |

### Adding tests for a new extension operator

Place tests in `addons/gn_ext_<name>/tests/test_<name>_operators.gd`. The runner picks them up automatically — no registration needed.

---

## 8. Manual Test Patches

Manual test patches live in `tests/manual/<family>/` and provide **human-assisted visual testing** for operators that require GPU, scene tree, or hardware that can't run headlessly. There is exactly **one `.gnpatch` per operator** so failures can be isolated to a single node. Each patch includes a yellow sticky note explaining what to verify.

### Structure

- **183 patches** — one per operator across 8 families
- Filter operators receive a minimal upstream source (e.g., NoiseTOP feeds BlurTOP) so they have data to process
- Generator operators stand alone with no upstream
- A yellow sticky note on each patch names the operator under test and describes what to verify
- Generated by `scripts/gen_manual_test_patches.py` — re-run after adding new operators

### How to use

1. Open the GONODES editor
2. File → Open Patch → navigate to `tests/manual/<family>/`
3. Load a patch — read the sticky note instructions
4. Enable cooking and verify the visual result matches expectations
5. Mark pass/fail in your test log

### Family coverage

| Family | Patches | What to verify |
|--------|---------|----------------|
| **TOP** | 72 | Texture output, GPU rendering, compositing, filters, generators |
| **COMP** | 20 | Scene tree integration, 3D viewport, physics, sub-networks |
| **UI** | 31 | Widget rendering, interaction, layout, value output |
| **POP** | 12 | Particle emission, forces, behaviors, rendering |
| **VOL** | 13 | Volumetric rendering, simulation, marching cubes, filters |
| **MAT** | 10 | Material appearance, shading, custom shaders |
| **IMG** | 13 | CPU image processing, I/O, conversion |
| **OUTPUT** | 12 | External output routing (file, window, network, device) |

---

## 9. Manual Test Scenes (Legacy)

> **⚠️ DEPRECATED** — Per-operator visual testing is now handled by **help example patches** (1,413 `.gnpatch` files across `addons/gonodes/help/<family>/` and extension help directories). The legacy `test_scenes/` folder is retained for reference but is no longer the primary visual verification method. See §7.1 below.

### 7.1 Help Example Patches (Replacement)

Every operator now ships with 3+ `.gnpatch` example files accessible via the `?` help button on each node. These patches provide the same visual verification that manual test scenes provided, but with these advantages:

- **Per-operator coverage** — 1,413 patches vs 8 multi-node test scenes
- **Discoverable** — click `?` on any node to see its examples
- **Required for new operators** — Hard Rule 25.21 mandates help patches for every new node
- **Self-contained** — each patch tests one operator in isolation

How to use:
1. Open the GONODES editor
2. Place any operator node on the canvas
3. Click the `?` button in the node header (or right-click → Help)
4. Click "Open Example Patch" at the bottom of the help window
5. The example loads in a floating editor — enable cooking to see the visual result

### 7.2 Legacy Test Scenes (Deprecated)

The following scenes in `test_scenes/` tested multi-node integration workflows. They remain in the repo for reference but are superseded by help patches for per-operator verification.

| Scene | File | What it tested | Replacement |
|-------|------|----------------|-------------|
| **01 — CHOP Chain Basics** | `01_chop_chain_basics.gnpatch` | LFO → Math → Null chain, expression-driven TOPs | `chop/lfo_*.gnpatch`, `chop/math_*.gnpatch` |
| **02 — ScriptCHOP** | `02_script_chop.gnpatch` | Generator + filter ScriptCHOPs | `chop/scriptchop_generator.gnpatch` |
| **03 — Custom Shader TOP** | `03_custom_shader_top.gnpatch` | Generator/filter/multi-input shaders | `top/glsl_radial_wave.gnpatch` |
| **04 — Expression Animation** | `04_expression_animation.gnpatch` | LFO → CircleTOP Lissajous animation | `chop/lfo_*.gnpatch`, `top/circle_basic.gnpatch` |
| **05 — TOP Compositing Chain** | `05_top_compositing_chain.gnpatch` | Full TOP processing pipeline | `top/composite_*.gnpatch`, `top/edge_detect.gnpatch` |

---

## 10. Writing New Tests

### Adding a unit test

1. Create `tests/test_<name>.gd` extending `Node`.
2. Add `test_*()` methods — the runner discovers them automatically.
3. Use `GNTestAssert` for all assertions.
4. Optionally implement lifecycle hooks:

```gdscript
extends Node

var _my_object: MyClass

func before_each() -> void:
    _my_object = MyClass.new()

func after_each() -> void:
    if _my_object:
        _my_object.queue_free()

func test_something() -> void:
    _my_object.do_work()
    GNTestAssert.assert_eq(_my_object.result, 42, "result should be 42")

func test_another_thing() -> void:
    GNTestAssert.assert_true(_my_object.is_valid(), "should be valid")
    GNTestAssert.assert_not_null(_my_object.output, "output should exist")
```

### Adding an integration test

1. Create `tests/integration/test_<name>.gd` extending `Node`.
2. In `before_each()`, set up `GNCookEngine` + `GNNetwork` with `cooking_enabled = false`.
3. Use real operator classes (e.g., `ConstantCHOP`, `MathCHOP`, `NullCHOP`).
4. Call `_cook_one_frame()` to drive the full pipeline, then verify `cached_output`.

```gdscript
extends Node

const ConstantCHOP = preload("res://addons/gonodes/operators/chop/constant_chop.gd")
const NullCHOP = preload("res://addons/gonodes/operators/chop/null_chop.gd")

var _engine: GNCookEngine
var _network: GNNetwork

func before_each() -> void:
    _engine = GNCookEngine.new()
    _network = GNNetwork.new()
    _engine.set_network(_network)
    _engine.cooking_enabled = false

func _make_node(script_class, id: String) -> GNNode:
    var node = script_class.new()
    node.initialize(id)
    _network.add_node(id, node)
    add_child(node)
    return node

func _cook_one_frame(delta := 1.0 / 60.0) -> void:
    _engine.cooking_enabled = true
    _engine.cook_frame(delta)
    _engine.cooking_enabled = false

func test_my_chain() -> void:
    var c := _make_node(ConstantCHOP, "c1")
    c.parameters["value0"].set_value(99.0)
    var n := _make_node(NullCHOP, "n1")
    _network.connect_nodes("c1", 0, "n1", 0)
    _cook_one_frame()
    var out: GNChannelData = n.cached_output
    GNTestAssert.assert_not_null(out, "null should have output")
    GNTestAssert.assert_approx(out.get_value("chan1"), 99.0, 0.01, "passthrough")
```

### Adding a manual test scene

1. Create `test_scenes/NN_<name>.gnpatch` — a JSON file following the network serialization format:

```json
{
    "version": "1.0.0",
    "generator": "GONODES_TEST",
    "nodes": {
        "node_id": {
            "type": "OperatorClassName",
            "position": [x, y],
            "parameters": {
                "param_name": { "value": <value> }
            }
        }
    },
    "connections": [
        { "from": "source_id", "from_port": 0, "to": "dest_id", "to_port": 0 }
    ]
}
```

2. Add a corresponding checklist section to `test_scenes/README.md`.

### Naming conventions

| Item | Convention |
|------|-----------|
| Core test file | `tests/test_<subject>.gd` or `tests/operators/<family>/test_<family>_operators.gd` |
| Extension test file | `addons/gn_ext_<name>/tests/test_<name>_operators.gd` |
| Test method | `test_<what_it_does>()` → `void` |
| Integration subfolder | `tests/integration/` |
| Manual scene | `test_scenes/NN_<name>.gnpatch` |
| Lifecycle hooks | `before_all()`, `after_all()`, `before_each()`, `after_each()` |

---

## 11. What Is and Isn't Tested

### Covered by automated tests

- **GNParameter** — all 8 type constructors, value clamping, mode switching (CONSTANT / EXPRESSION), signal emission, per-component expressions, serialization round-trip, legacy mode migration, variant helpers
- **GNCookEngine** — expression evaluation with `time`/`frame`/`dt` variables, `par()`/`parf()`/`pari()`/`pars()` functions, `chop()`/`chopf()`/`chopi()`/`chops()` data references, circular reference guards, component expression resolution, error recovery with fallback values, node path resolution
- **GNNetwork** — node add/remove, connection management, topological sort, cycle detection, dirty propagation, rename with connection update, unique ID generation, serialization structure
- **GNChannelData** — channel I/O, index bounds behavior, missing data handling, metadata tracking, deep copy, family identity
- **GNParamPresetManager** — clipboard lifecycle, type-safe paste, reset to defaults, null safety
- **All 533 operators** — instantiation, default parameter verification, cook-without-crash, correct output data types. Core operators tested in `tests/operators/<family>/`, extension operators in `addons/gn_ext_*/tests/`
- **SOP behavioral verification** — vertex counts, geometry presence, subdivision effects, deformation correctness (transform shifts, noise deforms, bend/twist/taper), merge/switch/blend output, position data comparison
- **SOP functional verification** — vertex positions within bounds, AABB size changes after scale/peak/extrude, normal directions after flip/recompute, scatter point counts, copy multiplication, clip plane enforcement, sort ordering, fuse deduplication
- **DAT behavioral verification** — cell content, row/column counts, sort correctness (ascending/descending, numeric/alphabetic), merge row stacking, transpose dimension swap, switch selection
- **DAT functional verification** — SortDAT ascending value order, SubstituteDAT find/replace correctness, TransposeDAT double-transpose identity, CSV parse with header/cell verification, UniqueDAT deduplication count, FilterDAT row reduction, JSON/XML/YAML parse output
- **CHOP functional verification** — MathCHOP arithmetic correctness (5+3=8, 4×2.5=10), WaveCHOP sine range [-1,1], MergeCHOP channel union, LimitCHOP clamping, SlopeCHOP derivative sign, RenameCHOP name change, SelectCHOP wildcard filtering, LogicCHOP truth tables, CompareCHOP thresholds, MapCHOP range remapping
- **Full cook pipeline** — `cook_frame()` through real CHOP operator chains (Constant, Math, Merge, Null, Script, LFO), including topo sort, dirty propagation, input gathering, parameter resolution, bypass mode
- **ScriptCHOP runtime** — dynamic GDScript compilation, `@param` annotation parsing, upstream input reading, multi-channel output, syntax error handling
- **Network serialization** — `to_dict()` / `from_dict()` round-trip fidelity for nodes, connections, parameters, and expressions; cook correctness after deserialization
- **Patch integrity** — all 1,413 `.gnpatch` help files load, deserialize, contain nodes, and have valid connections
- **Thread safety** — `GNNetwork.multithreading_enabled` toggle (off by default, serialized in `.gnpatch`), `GNNode.thread_safe` per-operator flag, expression edge injection into topo levels, parallel batch splitting of safe/unsafe nodes

### Covered by help example patches (1,413 patches)

- **GPU rendering** — All 28 TOP operators have visual example patches
- **Shader compilation** — `glsl_radial_wave.gnpatch` demonstrates CustomShaderTOP
- **3D scene pipeline** — `render_scene.gnpatch`, `camera_*.gnpatch`, `light_setup.gnpatch`
- **Physics simulation** — `rigid_body_basic.gnpatch`, `joint_hinge.gnpatch`, `area_gravity.gnpatch`
- **CHOP signal processing** — All 31 CHOP node types with basic + advanced examples
- **DAT table operations** — All 16 DAT node types with data manipulation examples
- **SOP geometry** — All 15 SOP node types with mesh generation/processing examples
- **MAT materials** — PBR metallic/emissive + programmable shader examples

### Covered by manual test patches (34 patches in `tests/manual/`)

- **TOP (72 patches)** — one per texture operator (NoiseTOP, BlurTOP, CompositeTOP, RenderTOP, etc.)
- **COMP (20 patches)** — one per component (GeometryCOMP, CameraCOMP, RigidBodyCOMP, SubNetworkNode, etc.)
- **UI (31 patches)** — one per widget (ButtonUI, SliderUI, KnobUI, XYPadUI, etc.)
- **POP (12 patches)** — one per particle operator (SourcePOP, ForcePOP, BoidsPOP, RenderPOP, etc.)
- **VOL (13 patches)** — one per volume operator (NoiseVOL, FluidVOL, MarchingCubesVOL, RaymarchVOL, etc.)
- **MAT (10 patches)** — one per material (PbrMAT, WireframeMAT, ShaderMAT, etc.)
- **IMG (13 patches)** — one per image operator (NoiseIMG, BlurIMG, PixelSortIMG, ImgToTOP, etc.)
- **OUTPUT (12 patches)** — one per output operator (WindowOUT, MovieOUT, OscOUT, etc.)

### Covered by legacy manual test scenes (deprecated)

- **Cross-family expression animation** — CHOP values driving TOP parameters in real-time via `chop()` expressions
- **Multi-node integration workflows** — complex chains testing operator interoperability
- **Interactive parameter tweaking** — live parameter changes propagating through the network
- **Visual output correctness** — rendered images match expected patterns (sine bars, noise, gradients, composites)

### Not tested (deferred)

| Area | Reason |
|------|--------|
| UI widgets | Requires full editor scene, mouse/keyboard input |
| Hardware I/O | MIDI, OSC, audio, webcam, serial — requires physical devices |
| GPU shader output correctness | Operators instantiate and cook, but rendered texture content is not pixel-verified |
| Performance/stress testing | Needs dedicated benchmarking framework |
| Cross-platform differences | Linux/macOS shader compilation, arm64 rendering |

---

## 12. Bugs Found by Tests

The test suite has already caught production bugs:

| Bug | Found by | Fix |
|-----|----------|-----|
| `GNParamPresetManager.reset_to_defaults()` called `temp_node.initialize()` without the required `p_id` argument | `test_preset_manager::test_reset_to_defaults` | Changed to `initialize("__temp_defaults__")` |
| `GNParamPresetManager` clipboard `_clipboard = {}` reassignment from external scope failed for static vars | `test_preset_manager::test_copy_overwrites_clipboard` | Changed to `_clipboard.clear()` |
| Serialization round-trip test used `from_node`/`to_node` keys but production format uses `from`/`to` | `test_network_roundtrip::test_connections_preserved` | Fixed test to match production serialization format |

---

## 13. Directory Layout

```
tests/
├── test_runner.gd                          # GNTestRunner — discovers & runs all test_*.gd
├── test_assert.gd                          # GNTestAssert — static assertion library
├── test_parameter.gd                       # GNParameter
├── test_cook_engine.gd                     # GNCookEngine expression eval
├── test_network.gd                         # GNNetwork graph model
├── test_channel_data.gd                    # GNChannelData
├── test_preset_manager.gd                  # GNParamPresetManager
├── test_ramp_and_annotations.gd            # Ramp params + annotations
├── test_ramp_chop.gd                       # RampCHOP
├── test_shadertoy.gd                       # Shadertoy extension
├── test_native_operators.gd                # Native C++ operator wrappers
├── test_cpu_fallback.gd                    # CPU fallback paths
├── operators/                              # Per-family core operator tests (structural)
│   ├── chop/test_chop_operators.gd         # 128 tests — core CHOPs only
│   ├── comp/test_comp_operators.gd
│   ├── dat/test_dat_operators.gd           # Core DATs + GNData subclass tests
│   ├── img/test_img_operators.gd           # Core IMGs only
│   ├── mat/test_mat_operators.gd
│   ├── output/test_output_operators.gd
│   ├── pop/test_pop_operators.gd           # Core POPs only
│   ├── sop/test_sop_operators.gd           # Core SOPs only
│   ├── top/test_top_operators.gd           # Core TOPs only
│   ├── ui/test_ui_operators.gd
│   └── vol/test_vol_operators.gd           # Core VOLs only
├── functional/                             # Output correctness tests (--test-tag=functional)
│   ├── test_sop_functional.gd              # ~70 tests — geometry value verification
│   ├── test_chop_functional.gd             # ~70 tests — channel value verification
│   └── test_dat_functional.gd              # ~56 tests — table/text content verification
├── integration/
│   ├── test_chop_chains.gd                 # CHOP operator chain cooking
│   ├── test_cook_chain.gd                  # Multi-node cook chain (SOP/CHOP/DAT end-to-end)
│   ├── test_cook_pipeline.gd               # Cook pipeline integration
│   ├── test_gnpatch_smoke.gd               # Load+verify all 1,413 .gnpatch help files
│   ├── test_script_chop.gd                 # ScriptCHOP runtime
│   └── test_network_roundtrip.gd           # Serialization round-trip
└── manual/                                 # Human-assisted visual test patches (183 patches)
    ├── top/                                # 72 patches — one per GPU texture operator
    ├── comp/                               # 20 patches — one per scene component
    ├── ui/                                 # 31 patches — one per UI widget
    ├── pop/                                # 12 patches — one per particle operator
    ├── vol/                                # 13 patches — one per volume operator
    ├── mat/                                # 10 patches — one per material operator
    ├── img/                                # 13 patches — one per image operator
    └── output/                             # 12 patches — one per output operator

addons/gn_ext_*/tests/                      # Self-contained extension tests (287 tests)
├── gn_ext_native/tests/test_native_operators.gd    # 176 tests — all *Native variants
├── tests/operators/sdf/test_sdf_operators.gd          # 53 tests — all SDF operators
├── gn_ext_mapper/tests/test_mapper_operators.gd     # 14 tests — projection mapping
├── gn_ext_ml/tests/test_ml_operators.gd             # 7 tests — ML inference operators
├── gn_ext_depth_sensor/tests/...                    # 5 tests
├── gn_ext_user_native/tests/...                     # 5 tests
├── gn_ext_user_python/tests/...                     # 5 tests
├── gn_ext_ndi/tests/...                             # 4 tests
├── gn_ext_blackmagic/tests/...                      # 3 tests
└── ... (9 more extensions with 1-2 tests each)

addons/gonodes/help/                        # Help example patches (visual verification)
├── chop/
├── top/
├── sop/
├── comp/
├── dat/
└── mat/
```
