# User Python Extension

Write your own GONODES operators in Python with NumPy. Scripts are loaded
directly — no compilation required. Changes hot-reload instantly.

---

## Quick Start

1. Add a **UserPythonSOP** (or CHOP / IMG / TOP / DAT) from the **User Python** section in the Add Node palette.
2. Click the node, then click **Edit Python ↗** in the inspector.
3. The built-in Python editor opens with a working example.
4. Press **Ctrl+R** (or click **Reload**) to load the script.
5. The node starts cooking with your Python code immediately.

No compilation. No external IDE. Just write Python and reload.

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| Python 3.10+ | Bundled embeddable or system Python |
| NumPy | `pip install numpy` — required for data bridges |
| Desktop only | Windows, macOS, Linux (no mobile/web) |

The extension auto-detects Python in this order:
1. Bundled: `addons/gn_ext_user_python/toolchain/python/`
2. Environment variable: `GONODES_PYTHON_HOME`
3. System Python on PATH

---

## SDK Reference

Import the SDK in your scripts:

```python
from gonodes.sop import make_sop_result, get_input_positions
from gonodes.chop import make_chop_result
from gonodes.params import input_port, output_port, float_param
import numpy as np
```

### Lifecycle Functions

| Function | Required | Description |
|----------|----------|-------------|
| `get_port_definitions()` | No | Return `{"ports": [...]}` |
| `get_param_definitions()` | No | Return `{"params": [...]}` |
| `setup(me, context)` | No | Called once at load and on reload |
| `cook(me, params, inputs, context)` | Yes | Main cook — return a result dict |

### The `me` Object

A dictionary with:

| Key | Type | Description |
|-----|------|-------------|
| `me["name"]` | str | Node name in the network |
| `me["path"]` | str | Filesystem path to this .py file |
| `me["time"]` | float | Elapsed time in seconds |
| `me["frame"]` | int | Current frame number |
| `me["delta"]` | float | Frame delta time |

### Family Helpers

| Module | Key Functions |
|--------|-------------|
| `gonodes.sop` | `make_sop_result(positions, normals, uvs, colors, indices)` |
| `gonodes.chop` | `make_chop_result(channels_dict, sample_rate)` |
| `gonodes.img` | `make_img_result(pixels, width, height)` |
| `gonodes.top` | `make_top_result(pixels, width, height)` |
| `gonodes.dat` | `make_dat_result(rows, header)` or `make_dat_result(text=...)` |
| `gonodes.sdf` | `sdf_sphere()`, `sdf_box()`, `sdf_smooth_union()`, `make_sdf_result()` |

### Multi-Output

Return `make_multi_output(result0, result1, ...)` from `cook()` with
multiple output ports defined in `get_port_definitions()`:

```python
from gonodes import make_multi_output
from gonodes.chop import make_chop_result
from gonodes.dat import make_dat_result
from gonodes.params import output_port

def get_port_definitions():
    return {"ports": [
        output_port("channels", "CHOP"),
        output_port("stats", "DAT"),
    ]}

def cook(me, params, inputs, context):
    return make_multi_output(chop_result, dat_result)
```

Single-output operators return a flat dict as before.

### Parameter Builders

From `gonodes.params`:

```python
float_param("name", default, min, max, step, "Label", "Description")
int_param("name", default, min, max, "Label", "Description")
bool_param("name", default, "Label", "Description")
string_param("name", default, "Label", "Description")
color_param("name", default_dict, "Label", "Description")
enum_param("name", ["opt1", "opt2"], default_idx, "Label", "Description")
```

---

## Port Definitions

Return from `get_port_definitions()`:

```python
from gonodes.params import input_port, output_port

def get_port_definitions():
    return {"ports": [
        input_port("in", "SOP", required=True, label="Input geometry"),
        output_port("out", "SOP", label="Output geometry"),
    ]}
```

---

## NumPy Zero-Copy Bridge

Data flows between Godot and Python through the C++ bridge:

- **PackedFloat32Array → numpy**: Zero-copy. The numpy array wraps Godot's
  memory directly via `PyArray_SimpleNewFromData()`.
- **numpy → PackedFloat32Array**: Memcpy. The result is copied back to Godot.
- **PackedByteArray ↔ numpy uint8**: Same pattern for image pixel data.

For best performance:
- Work with flat `float32` arrays (the bridge's native format).
- Use vectorized NumPy operations — avoid Python-level for-loops.
- Keep data as `np.float32` / `np.uint8` to avoid type conversion overhead.

---

## Threading Safety

Python operators cook on the main thread (GIL constraint). The C++ bridge
acquires/releases the GIL around each cook call. This means:

- Your `cook()` runs single-threaded.
- Use NumPy vectorized operations for speed — they release the GIL internally.
- Do not create threads that call back into Godot.

---

## Hot Reload

When you modify and reload:
1. `importlib.reload()` reloads the Python module.
2. `get_port_definitions()` + `get_param_definitions()` are re-queried.
3. Ports and parameters sync to the new definitions.
4. `setup(me, context)` is called again.
5. The node re-cooks immediately.

No restart required. Reload is typically <10ms.

---

## Examples

Loadable from the code editor's **Examples** menu:

| Example | Family | Description |
|---------|--------|-------------|
| Wave Deform | SOP | Animated sine-wave vertex displacement |
| Signal Generator | CHOP | Multi-waveform oscillator |
| Edge Detect | IMG | Sobel edge detection |
| Gradient | TOP | Animated gradient texture |
| CSV Parser | DAT | CSV text → structured table |

---

## Code Editor

The built-in Python Code Editor provides a full editing environment without
leaving GONODES. Open it by clicking **Edit Python ↗** in the inspector panel
when a UserPython operator is selected.

### Toolbar

| Button | Description |
|--------|-------------|
| **Reload (Ctrl+R)** | Reloads the Python script — triggers `importlib.reload()`, re-queries ports/params, and re-cooks. |
| **Templates ▾** | Load a minimal starter template. Templates are sorted by family first — the current node's family appears at the top. |
| **Examples ▾** | Load a fully-worked example. Same family-first sorting as Templates. |
| **Presets ▾** | Load a saved preset. Factory presets ship with the extension; User presets are ones you've saved. |
| **Save Preset…** | Save the current code as a named user preset. Names are sanitized to safe filename characters. |
| **Help ❓** | Opens this help document in a scrollable popup window (Markdown rendered as BBCode). |

The right side of the toolbar shows a **SDK quick-reference** hint for the
current family — e.g. `SDK: gonodes.sop | make_sop_result(positions, normals, uvs, colors)`.

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Ctrl+R** | Reload Python script |
| **Ctrl+Enter** | Reload & Apply (commits code and reloads) |
| **Escape** | Close editor |

### Python Output Panel

Click **▶ Python Output** below the code area to expand the output panel.
When a Python error occurs, it automatically opens and shows the full
traceback. Error lines are highlighted with a red background in the code
editor, and the caret jumps to the last error line.

### Syntax Highlighting

The editor provides Python-aware syntax highlighting:

| Category | Colour | Examples |
|----------|--------|---------|
| Keywords | Pink | `def`, `class`, `for`, `if`, `return`, `import` |
| Built-in types | Cyan | `int`, `float`, `str`, `list`, `dict`, `None`, `True` |
| NumPy | Green | `np`, `ndarray`, `array`, `zeros`, `linspace` |
| GONODES SDK | Green | `make_sop_result`, `cook`, `setup`, `float_param` |
| Math | Blue | `sin`, `cos`, `sqrt`, `pi`, `dot`, `cross` |
| Strings | Gold | `"text"`, `'text'`, `"""docstring"""` |
| Comments | Grey | `# comment` |
| Decorators | Purple | `@staticmethod` |

### Presets

Presets are managed through `GNScriptHelper` and stored in the standard
GONODES preset directory under a `python/` subfolder.

- **Factory presets**: Ship with the extension (read-only).
- **User presets**: Created via **Save Preset…**. Stored in the user data
  directory alongside other GONODES presets.

When saving a preset, enter a descriptive name in the dialog. The name is
automatically sanitized: non-alphanumeric characters (except underscore) are
replaced with `_`. Files are saved with a `.py` extension.

### Templates vs Examples

- **Templates**: Minimal starters — just enough boilerplate to get cooking.
  One per family (SOP, CHOP, IMG, TOP, DAT).
- **Examples**: Fully-worked scripts demonstrating real techniques.
  Include comments explaining each step.

Both menus sort the current family's items to the top with a labelled
separator, followed by items from other families under "Other Families".

---

## File Structure

```
addons/gn_ext_user_python/
  gn_extension.cfg          # Extension manifest
  README.md
  native/                   # C++ GDExtension (CPython embedding)
    src/                    # C++ sources
    build.cfg               # Build configuration
    gn_python.gdextension   # GDExtension manifest
    python_config.py        # Python path discovery
  sdk/gonodes/              # Python SDK package
    __init__.py             # Common helpers + make_multi_output()
    sop.py, chop.py, img.py, top.py, dat.py
    sdf.py                  # SDF extension SDK
    params.py
  core/                     # GDScript infrastructure
    gn_python_code_editor.gd
  operators/                # GDScript wrappers
    sop/user_python_sop.gd
    chop/user_python_chop.gd
    img/user_python_img.gd
    top/user_python_top.gd
    dat/user_python_dat.gd
  templates/                # Minimal starters
    sop_template.py ... dat_template.py
  examples/                 # Full worked examples
    wave_deform_sop.py ... csv_parse_dat.py
  help/                     # Help docs + .gnpatch files
  toolchain/                # Bundled Python (optional)
```
