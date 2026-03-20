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

## Directory Structure

```
addons/gn_ext_user_native/
├── gn_extension.cfg         # Extension manifest
├── README.md                # This file
├── operators/               # GDScript wrapper operators
│   ├── sop/
│   ├── chop/
│   ├── img/
│   ├── top/
│   └── dat/
├── sdk/                     # C++ SDK headers (user-facing API)
│   ├── gn_user_node.h       # Base class for all user nodes
│   ├── gn_user_sop.h        # SOP-specific helpers
│   ├── gn_user_chop.h       # CHOP-specific helpers
│   ├── gn_user_img.h        # IMG-specific helpers
│   ├── gn_user_top.h        # TOP-specific helpers
│   ├── gn_user_dat.h        # DAT-specific helpers
│   └── gn_user_types.h      # Common type aliases
├── templates/               # Starter templates for each family
│   ├── sop_template.h
│   ├── chop_template.h
│   ├── img_template.h
│   ├── top_template.h
│   └── dat_template.h
├── examples/                # Example C++ source files
│   ├── wave_deform_sop.h    # SOP: sine wave vertex deformer
│   ├── signal_gen_chop.h    # CHOP: multi-waveform generator
│   ├── edge_detect_img.h    # IMG: Sobel edge detection
│   ├── life_top.h           # TOP: Conway's Game of Life
│   └── csv_parse_dat.h      # DAT: fast CSV parser
├── toolchain/               # Bundled compiler (populated at install)
│   └── README.md
├── help/                    # Help documentation and example patches
│   ├── user_native.md       # Main guide
│   ├── sop/
│   ├── chop/
│   ├── img/
│   ├── top/
│   └── dat/
└── core/                    # Internal infrastructure
    ├── gn_native_compiler.gd    # Compilation manager
    ├── gn_native_reloader.gd    # Hot-reload manager
    ├── gn_native_file_watch.gd  # File change detection
    └── gn_cpp_code_editor.gd    # C++ code editor window
```

## Threading

C++ user nodes get **full WorkerThreadPool parallelism** automatically. The existing GONODES threading contract guarantees safety — parameters and inputs are resolved on the main thread before dispatch; only `cook()` runs on worker threads.

**Safe:** `ArrayMesh`, `SurfaceTool`, `PackedVector3Array`, `PackedFloat32Array`, `Image`, math operations.
**Unsafe (main-thread only):** `RenderingServer`, `DisplayServer`, `AudioServer` direct calls.

## Bundled Toolchain

GONODES editor distributions include:
- **godot-cpp** headers (matching the engine version)
- **SCons** (Python-based build system)
- **Compiler** (platform-specific):
  - Windows: TDM-GCC MinGW-w64 (~80MB)
  - macOS: Clang (via Xcode Command Line Tools — prompted to install if missing)
  - Linux: System GCC (prompted to install via package manager if missing)
