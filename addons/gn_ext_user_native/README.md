# gn_ext_user_native — Hot-Reloadable C++ Operators

Write C++ operators that run at native speed with a 2–8 second compile-and-reload cycle. No Godot restart required.

## Quick Start

1. In the GONODES editor, add a **UserNativeSOP** (or CHOP/IMG/TOP/DAT) node
2. Click **"Edit C++ ↗"** in the parameter inspector — opens the C++ code editor
3. Write your `cook()` function using the GONODES C++ SDK
4. Press **Ctrl+B** or click **"Build"** — compiles in 2–8 seconds
5. The node hot-reloads and starts cooking with your C++ code immediately

## How It Works

Each UserNative operator:
- Has an embedded C++ source file stored as a parameter
- Compiles to a temporary GDExtension `.dll`/`.so` via bundled godot-cpp + SCons
- Hot-reloads using Godot 4.2+'s GDExtension reload API
- Falls back to a "no output" state if compilation fails (with error display)
- Preserves all parameters and connections across reloads

## Building

### From the editor

Press **Ctrl+B** in the C++ code editor — the `GNNativeCompiler` handles everything:
writes source, generates register_types.cpp + SConstruct + .gdextension,
invokes SCons (or falls back to direct g++/clang++/cl compilation), and
hot-reloads the result.

> **Windows / MSVC:** `cl.exe` must be on your PATH. Launch Godot from a
> **Developer Command Prompt for VS** or run `vcvarsall.bat x64` first.
> MinGW/TDM-GCC users already have `g++` on PATH after installation.

### From the command line

```bash
cd addons/gn_ext_user_native
python build_user_node.py examples/wave_deform_sop.h WaveDeformSOP
python build_user_node.py my_node.h MyNode --clean --platform windows --arch x86_64
```

See `python build_user_node.py --help` for full options.

### godot-cpp discovery order

1. `toolchain/godot-cpp/` — local clone
2. `GODOT_CPP_PATH` environment variable
3. `addons/gn_ext_native/native/godot-cpp/` — project's shared copy

## Directory Structure

```
addons/gn_ext_user_native/
├── gn_extension.cfg         # Extension manifest
├── build_user_node.py       # CLI build script
├── README.md                # This file
├── operators/               # GDScript wrapper operators
│   ├── user_native_sop.gd
│   ├── user_native_chop.gd
│   ├── user_native_img.gd
│   ├── user_native_top.gd
│   └── user_native_dat.gd
├── sdk/                     # C++ SDK headers (user-facing API)
│   ├── gn_user_node.h       # Base class for all user nodes
│   ├── gn_user_types.h      # Type aliases + param factories + make_multi_output()
│   ├── gn_user_sop.h        # SOP output helpers
│   ├── gn_user_chop.h       # CHOP output helpers
│   ├── gn_user_img.h        # IMG output helpers
│   ├── gn_user_top.h        # TOP output helpers
│   ├── gn_user_dat.h        # DAT output helpers
│   └── gn_user_sdf.h       # SDF tree construction (extension SDK)
├── templates/               # Starter templates for each family
│   ├── sop_template.h
│   ├── chop_template.h
│   ├── img_template.h
│   ├── top_template.h
│   └── dat_template.h
├── examples/                # Example C++ source files
│   ├── wave_deform_sop.h    # Sine wave vertex deformer
│   ├── scatter_sop.h        # Point scatter (vector3/enum)
│   ├── signal_gen_chop.h    # Multi-waveform generator
│   ├── edge_detect_img.h    # Sobel edge detection
│   ├── life_top.h           # Conway's Game of Life
│   ├── gradient_top.h       # GPU gradient generator
│   └── csv_parse_dat.h      # Fast CSV parser
├── toolchain/               # Bundled compiler (populated at install)
│   └── README.md
├── help/                    # Help documentation and example patches
└── core/                    # Internal infrastructure
    ├── gn_native_compiler.gd    # Compilation + direct fallback
    ├── gn_native_reloader.gd    # Hot-reload manager
    ├── gn_native_file_watch.gd  # File change detection
    └── gn_cpp_code_editor.gd    # C++ code editor window
```

## Threading

C++ user nodes get **full WorkerThreadPool parallelism** automatically. The existing GONODES threading contract guarantees safety — parameters and inputs are resolved on the main thread before dispatch; only `cook()` runs on worker threads.

**Safe:** `ArrayMesh`, `SurfaceTool`, `PackedVector3Array`, `PackedFloat32Array`, `Image`, math operations.
**Unsafe (main-thread only):** `RenderingServer`, `DisplayServer`, `AudioServer` direct calls.

## Multi-Output

C++ operators can produce multiple outputs of different families.

1. Define multiple output ports in `get_port_definitions()`.
2. Return `gn::make_multi_output({result0, result1, ...})` from `native_cook()`.

```cpp
#include "gn_user_types.h"
#include "gn_user_chop.h"
#include "gn_user_dat.h"

Array get_port_definitions() override {
    return Array::make(
        gn::output_port("channels", "CHOP", "Channel data"),
        gn::output_port("stats", "DAT", "Statistics")
    );
}

Dictionary native_cook(const Dictionary &params,
                       const Array &inputs,
                       const Dictionary &ctx) override {
    Dictionary chop = gn::make_chop_single("val", arr);
    Dictionary dat = gn::make_dat_table(headers, rows);
    return gn::make_multi_output({chop, dat});
}
```

Single-output operators are unchanged — return a flat Dictionary as before.
The wrapper detects the `"outputs"` key automatically.

## Extension Family SDKs

Extension families (like SDF) ship SDK headers in the same `sdk/` directory.
Include them like any other header:

```cpp
#include "gn_user_sdf.h"

Dictionary native_cook(...) override {
    auto tree = gn::sdf_smooth_union(
        gn::sdf_sphere(0, 0, 0, 1.0),
        gn::sdf_box(2, 0, 0, 0.8, 0.8, 0.8),
        0.3
    );
    return gn::make_sdf_result(tree);
}
```

Available extension SDK headers:
- `gn_user_sdf.h` — SDF primitives, booleans, modifiers, materials

## Bundled Toolchain

GONODES editor distributions include:
- **godot-cpp** headers (matching the engine version)
- **SCons** (Python-based build system)
- **Compiler** (platform-specific):
  - Windows: TDM-GCC MinGW-w64 (~80MB)
  - macOS: Clang (via Xcode Command Line Tools — prompted to install if missing)
  - Linux: System GCC (prompted to install via package manager if missing)
