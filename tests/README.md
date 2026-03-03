# GONODES Unit Tests

Lightweight, dependency-free unit test suite for GONODES core logic.

## Running Tests

From the project root:

```bash
# Run all tests (headless, no GPU)
godot --headless -s tests/test_runner.gd

# Filter tests by name substring
godot --headless -s tests/test_runner.gd --test-filter=parameter

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
└── README.md               # This file
```

## Design Decisions

- **No external dependencies** — pure GDScript runner, no GdUnit4/GUT.
- **Headless-compatible** — runs with `--headless`, no GPU required for core tests.
- **Scene-tree aware** — test instances are added as children of the runner's root, so `add_child()` works for tests that need the tree (cook engine, network).
- **Non-throwing assertions** — failures are recorded, not thrown. Multiple assertions per test method are supported.
