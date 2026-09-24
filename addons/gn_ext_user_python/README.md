# gn_ext_user_python — User Python Operators

Write custom GONODES operators in **Python with NumPy**. Scripts load
instantly with hot-reload — no compilation required.

## Architecture

```
Python script (.py)
    ↓ imported by
GNPythonProcessor (C++ GDExtension, per-node)
    ↓ managed by
GNPythonRuntime (C++ singleton, embeds CPython)
    ↓ called from
GDScript wrapper (PythonSCRIPT)
    ↓ integrated into
GONODES cook engine
```

The C++ GDExtension embeds CPython via `Py_Initialize()` and provides:
- **Zero-copy numpy bridge**: `PackedFloat32Array` ↔ `numpy.ndarray` via
  `PyArray_SimpleNewFromData()`.
- **GIL management**: Acquired/released around each `cook()` call.
- **Module hot-reload**: `importlib.reload()` on Ctrl+R.

## Quick Setup (Recommended)

Run the automated setup script **before** building the native extension
(`setup_deps.py` runs this automatically on a fresh clone):

```bash
python addons/gn_ext_user_python/setup_python.py
```

On Windows this downloads the embeddable CPython package, installs pip +
NumPy, and enables the `.gdextension` file. On Linux/macOS it verifies
system Python and dev headers.

Options:
- `--python-version 3.12.8` — use a specific Python version
- `--skip-numpy` — skip NumPy installation

Then build:

```bash
cd build && scons ext=gn_ext_user_python platform=<your_platform> -j8
```

## Requirements (Manual Setup)

- Python 3.10+ (embeddable or system)
- NumPy (`pip install numpy`)
- Desktop only: Windows, macOS, Linux

## Operator

Add a **PythonSCRIPT** node from the User Python section. Use the
**Template** dropdown in the parameter inspector to select the CHOP, SOP,
DAT, IMG, or TOP context — this loads a family-focused starter script and
sets up the default input/output marshalling for that family.

## Quick Start

```python
from gonodes.sop import make_sop_result, get_input_positions
from gonodes.params import input_port, output_port, float_param
import numpy as np

def get_port_definitions():
    return {"ports": [
        input_port("in", "SOP"),
        output_port("out", "SOP"),
    ]}

def get_param_definitions():
    return {"params": [
        float_param("amplitude", 1.0, 0.0, 10.0),
    ]}

def cook(me, params, inputs, context):
    pos = get_input_positions(inputs, 0)
    if pos is None: return {}
    pos[:, 1] += np.sin(pos[:, 0] * 3.0 + me["time"]) * params["amplitude"]
    return make_sop_result(pos)
```

## Building the GDExtension

The C++ GDExtension (`libgn_python.dll/.so/.dylib`) must be built once
before use. It links against CPython and NumPy C APIs.

```bash
# From workspace root:
scons ext=gn_ext_user_python platform=windows
```

Or manually via `native/python_config.py` to discover Python paths.

## Bundling Python

For distribution, place the Python embeddable package in
`toolchain/python/`. See [toolchain/README.md](toolchain/README.md).

## vs. User Native C++

| Feature | Python | C++ Native |
|---------|--------|-----------|
| Compilation | None | 2-8 seconds |
| Performance | NumPy speed (~5-20x GDScript) | Full native (~10-50x GDScript) |
| Dependencies | Python + NumPy | C++ compiler + SCons |
| Hot-reload | Instant (<10ms) | Rebuild required |
| Libraries | Any pip package | Manual linking |
| Threading | GIL (single-threaded) | WorkerThreadPool |

Use Python when you want rapid iteration and access to the Python
ecosystem (ML, data science, etc.). Use C++ when you need maximum
throughput for per-element operations.

## Multi-Output

Python operators can produce multiple outputs of different families.

1. Define multiple output ports in `get_port_definitions()`.
2. Return `make_multi_output(result0, result1, ...)` from `cook()`.

```python
from gonodes import make_multi_output
from gonodes.chop import make_chop_result
from gonodes.dat import make_dat_result
from gonodes.params import output_port

def get_port_definitions():
    return {"ports": [
        output_port("channels", "CHOP", label="Channel data"),
        output_port("stats", "DAT", label="Statistics"),
    ]}

def cook(me, params, inputs, context):
    chop = make_chop_result({"val": [1.0, 2.0, 3.0]})
    dat = make_dat_result([["mean", "2.0"]], header=["stat", "value"])
    return make_multi_output(chop, dat)
```

Single-output operators are unchanged - return a flat dict as before.

## Extension Family SDKs

Extension families (like SDF) ship SDK modules in the `gonodes` package.
Import them like any other module:

```python
from gonodes.sdf import sdf_sphere, sdf_smooth_union, make_sdf_result

def cook(me, params, inputs, context):
    tree = sdf_smooth_union(
        sdf_sphere(0, 0, 0, 1.0),
        sdf_sphere(2, 0, 0, 0.8),
        k=0.3
    )
    return make_sdf_result(tree)
```

Available extension SDK modules:
- `gonodes.sdf` - SDF primitives, booleans, modifiers, materials
