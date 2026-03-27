# GONODES Unit Tests

Lightweight, dependency-free unit test suite for GONODES core logic.

## Running Tests

From the project root:

```bash
# Run all tests (headless, no GPU)
godot --headless -s tests/test_runner.gd

# Filter tests by name substring
godot --headless -s tests/test_runner.gd --test-filter=parameter

# Filter by tag (core, integration, extension, patch)
godot --headless -s tests/test_runner.gd --test-tag=core
godot --headless -s tests/test_runner.gd --test-tag=integration
godot --headless -s tests/test_runner.gd --test-tag=extension
godot --headless -s tests/test_runner.gd --test-tag=patch

# Combine tag + filter
godot --headless -s tests/test_runner.gd --test-tag=core --test-filter=box

# With Godot on PATH (Windows)
& "C:\path\to\godot.exe" --headless -s tests/test_runner.gd
```

## Writing Tests

1. Create a file under `tests/` named `test_*.gd`
2. Extend `Node`
3. Add methods named `test_*()` — the runner discovers them automatically
4. Use `GNTestAssert` for assertions:

```gdscript
extends Node

func test_example() -> void:
    GNTestAssert.assert_eq(1 + 1, 2, "math works")
    GNTestAssert.assert_approx(3.14, PI, 0.01, "close enough")
    GNTestAssert.assert_true(true, "truthy")
```

### Lifecycle Hooks (optional)

| Method         | When Called                        |
|----------------|-----------------------------------|
| `before_all()` | Once before any test in the file  |
| `after_all()`  | Once after all tests in the file  |
| `before_each()`| Before every individual test      |
| `after_each()` | After every individual test       |

### Available Assertions

| Assertion | Purpose |
|-----------|---------|
| `assert_true(cond)` | Condition is true |
| `assert_false(cond)` | Condition is false |
| `assert_eq(a, b)` | `a == b` |
| `assert_ne(a, b)` | `a != b` |
| `assert_null(val)` | Value is null |
| `assert_not_null(val)` | Value is not null |
| `assert_approx(a, b, tol)` | Float within tolerance |
| `assert_gt(a, b)` | `a > b` |
| `assert_lt(a, b)` | `a < b` |
| `assert_in_range(v, min, max)` | `min <= v <= max` |
| `assert_contains(str, substr)` | String contains |
| `assert_empty(str)` | String is empty |
| `assert_not_empty(str)` | String is not empty |
| `assert_size(coll, n)` | Collection has n items |
| `assert_has_key(dict, key)` | Dictionary has key |

## Test Structure

```
tests/
├── test_runner.gd          # Runner (SceneTree main loop)
├── test_assert.gd          # GNTestAssert assertion helpers
├── test_parameter.gd       # GNParameter: modes, serialization, expressions
├── test_cook_engine.gd     # GNCookEngine: expression eval, par(), chop()
├── test_network.gd         # GNNetwork: graph model, topo sort, dirty prop
├── test_channel_data.gd    # GNChannelData: channel ops, deep copy
├── test_preset_manager.gd  # GNParamPresetManager: clipboard, reset
├── test_ramp_and_annotations.gd  # Ramp params + canvas annotations
├── test_ramp_chop.gd       # RampCHOP dynamic slots
├── test_shadertoy.gd       # Shadertoy extension
├── test_native_operators.gd # Native C++ operator wrappers
├── test_cpu_fallback.gd    # POP/VOL CPU fallback paths
├── README.md               # This file
├── operators/              # Per-family core operator tests (13 families)
│   ├── chop/test_chop_operators.gd
│   ├── sop/test_sop_operators.gd
│   ├── top/test_top_operators.gd
│   ├── dat/test_dat_operators.gd
│   ├── comp/test_comp_operators.gd
│   ├── img/test_img_operators.gd
│   ├── mat/test_mat_operators.gd
│   ├── output/test_output_operators.gd
│   ├── pop/test_pop_operators.gd
│   ├── vol/test_vol_operators.gd
│   └── ui/test_ui_operators.gd
├── functional/             # Output correctness tests
│   ├── test_sop_functional.gd
│   ├── test_chop_functional.gd
│   └── test_dat_functional.gd
└── integration/
    ├── test_chop_chains.gd
    ├── test_cook_chain.gd
    ├── test_cook_pipeline.gd
    ├── test_gnpatch_smoke.gd
    ├── test_script_chop.gd
    └── test_network_roundtrip.gd

addons/gn_ext_*/tests/      # Extension tests (18 extensions, auto-discovered)
├── gn_ext_native/tests/test_native_operators.gd
├── tests/operators/sdf/test_sdf_operators.gd
├── gn_ext_mapper/tests/test_mapper_operators.gd
└── ... (18 extensions total)
```

## Adding Tests for New Operators

**Core operators** (in `addons/gonodes/operators/`): add tests to the matching family file under `tests/operators/<family>/`.

**Extension operators** (in `addons/gn_ext_*/operators/`): add tests to the extension's own `addons/gn_ext_<name>/tests/test_<name>_operators.gd`. The runner discovers these automatically.

### Boilerplate

Every operator test file shares this skeleton (already present in each file):

```gdscript
extends Node

var _network: GNNetwork
var _engine: GNCookEngine

func before_each() -> void:
    _network = GNNetwork.new()
    _engine = GNCookEngine.new()
    _engine.network = _network
    _engine.cooking_enabled = false
    _engine.elapsed_time = 1.0
    _engine.frame_count = 60
    _engine.current_delta = 1.0 / 60.0
    add_child(_engine)

func after_each() -> void:
    if is_instance_valid(_engine):
        remove_child(_engine)
        _engine.queue_free()

func _make_node(node: GNNode, id: String) -> GNNode:
    node.initialize(id)
    _network.add_node(node)
    _engine.add_child(node)
    return node

func _cook_no_input(node: GNNode) -> GNData:
    var inputs: Array[GNData] = []
    node.execute_cook(inputs, _engine.frame_count)
    return node.cached_output

func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
    node.execute_cook(inputs, _engine.frame_count)
    return node.cached_output
```

### Step-by-step: adding a test for a new node

Say you added a **GainCHOP** that multiplies all channel values by a gain parameter.

1. Open `tests/operators/chop/test_chop_operators.gd`.
2. Add test methods at the end of the file:

```gdscript
# ═══════════════════════════════════════════════════════════════════════════════
#  GainCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_gain_chop_default() -> void:
    var node := _make_node(GainCHOP.new(), "gain1")
    var input := _make_chop_data({"val": PackedFloat32Array([1.0, 2.0, 3.0])})
    var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
    GNTestAssert.assert_not_null(out, "gain produces output")
    GNTestAssert.assert_eq(out.channels.size(), 1, "preserves 1 channel")

func test_gain_chop_multiply() -> void:
    var node := _make_node(GainCHOP.new(), "gain2")
    node.set_param_value("gain", 3.0)
    var input := _make_chop_data({"val": PackedFloat32Array([2.0, 4.0])})
    var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
    GNTestAssert.assert_approx(out.get_value("val"), 6.0, 0.01, "first sample * 3")

func test_gain_chop_no_input() -> void:
    var node := _make_node(GainCHOP.new(), "gain3")
    var out := _cook_no_input(node)
    # Should handle gracefully — null or empty output
    if out != null:
        GNTestAssert.assert_true(true, "returned non-null safely")
```

3. Run:
```bash
godot --headless -s tests/test_runner.gd --test-filter=gain
```

### Test guidelines

- **Instantiation** — always test that the node produces non-null output with defaults.
- **Parameter effect** — change a parameter and verify the output changes accordingly.
- **Null/no-input safety** — call `_cook_no_input()` and confirm no crash.
- **Correctness** — compare specific numeric output values where deterministic (e.g. math, sort, blend with weight 0 or 1).
- **Edge cases** — empty geometry, zero-length channels, boundary parameter values.

### Family-specific helpers

Each test file may have family-specific helpers already defined:

| Family | Helpers |
|--------|---------|
| CHOP   | `_make_chop_data(channels, sample_rate)` |
| SOP    | `_make_box_geo(sx, sy, sz)`, `_make_grid_geo(rows, cols)` |
| TOP    | `_make_test_image(w, h, color)` |
| DAT    | `_make_table_dat(rows)` |

Use these to quickly create input data instead of building it from scratch.

## Design Decisions

- **No external dependencies** — pure GDScript runner, no GdUnit4/GUT.
- **Headless-compatible** — runs with `--headless`, no GPU required for core tests.
- **Scene-tree aware** — test instances are added as children of the runner's root, so `add_child()` works for tests that need the tree (cook engine, network).
- **Non-throwing assertions** — failures are recorded, not thrown. Multiple assertions per test method are supported.
