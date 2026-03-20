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
GDScript wrapper (UserPythonSOP/CHOP/IMG/TOP/DAT)
    ↓ integrated into
GONODES cook engine
```

The C++ GDExtension embeds CPython via `Py_Initialize()` and provides:
- **Zero-copy numpy bridge**: `PackedFloat32Array` ↔ `numpy.ndarray` via
  `PyArray_SimpleNewFromData()`.
- **GIL management**: Acquired/released around each `cook()` call.
- **Module hot-reload**: `importlib.reload()` on Ctrl+R.

## Requirements

- Python 3.10+ (embeddable or system)
- NumPy (`pip install numpy`)
- Desktop only: Windows, macOS, Linux

## Operator Families

| Operator | Base Class | Description |
|----------|-----------|-------------|
| UserPythonSOP | GNSopBase | Geometry processing |
| UserPythonCHOP | GNChopBase | Channel/signal processing |
| UserPythonIMG | GNImgBase | CPU image processing |
| UserPythonTOP | GNTopBase | CPU texture generation |
| UserPythonDAT | GNDatBase | Table/text data |

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
| Performance | NumPy speed (~5-20× GDScript) | Full native (~10-50× GDScript) |
| Dependencies | Python + NumPy | C++ compiler + SCons |
| Hot-reload | Instant (<10ms) | Rebuild required |
| Libraries | Any pip package | Manual linking |
| Threading | GIL (single-threaded) | WorkerThreadPool |

Use Python when you want rapid iteration and access to the Python
ecosystem (ML, data science, etc.). Use C++ when you need maximum
throughput for per-element operations.
