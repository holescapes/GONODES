# User Native C++ Extension

Write your own GONODES operators in C++ with instant hot-reload.
Get full native performance — 10-50× faster than GDScript for per-element
operations — with seamless integration into the GONODES cook engine.

---

## Quick Start

1. Add a **UserNativeSOP** (or CHOP / IMG / TOP / DAT) from the **User Native** section in the Add Node palette.
2. Click the node, then click **Edit C++ ↗** in the inspector.
3. The built-in C++ editor opens with a working example.
4. Press **Ctrl+B** (or click **Build**) to compile.
5. On success, the node hot-reloads and starts cooking with your C++ code.

No external IDE needed for simple operators. For complex projects,
edit `.h` files on disk and enable **Auto Build** — the node watches for changes.

---

## Toolchain Requirements

| Platform | Compiler | Notes |
|----------|----------|-------|
| Windows  | MSVC (Visual Studio Build Tools) or MinGW/TDM-GCC | MSVC recommended |
| Linux    | GCC 11+ or Clang 14+ | `build-essential` package |
| macOS    | Xcode Command Line Tools (Apple Clang) | `xcode-select --install` |

You also need:
- **SCons** — `pip install scons`
- **godot-cpp** — placed in `addons/gn_ext_user_native/toolchain/godot-cpp/`
  or set the `GODOT_CPP_PATH` environment variable.

Check toolchain status: the compiler will tell you what's missing in the
build output panel.

---

## SDK Reference

All headers are in `addons/gn_ext_user_native/sdk/`.

### Base Class: `gn::GNUserNode`

Every user operator extends this class. Override these virtual methods:

| Method | Required | Description |
|--------|----------|-------------|
| `get_node_type()` | Yes | Unique operator identifier (e.g. `"my_sop"`) |
| `get_node_description()` | Yes | One-line description for tooltips |
| `get_port_definitions()` | No | Input/output port definitions array |
| `get_param_definitions()` | No | Parameter definitions array |
| `native_setup(context)` | No | Called once after loading |
| `native_cook(params, inputs, context)` | Yes | Main cook — return a Dictionary |

### Parameter Helpers

Static methods on `GNUserNode` for reading parameters:

```cpp
float  parf(params, "name", default_val);
int    pari(params, "name", default_val);
bool   parb(params, "name", default_val);
String pars(params, "name", default_val);
Color  parc(params, "name", default_val);
Vector3 parv3(params, "name", default_val);
```

### Parameter Definition Helpers

For `get_param_definitions()`, use the `gn::` namespace helpers:

```cpp
gn::parf("name", default, min, max, step, "Label", "Description");
gn::pari("name", default, min, max, "Label", "Description");
gn::parb("name", default, "Label", "Description");
gn::pars("name", default, "Label", "Description");
gn::parc("name", default_color, "Label", "Description");
```

### Family Helpers

Each family has its own header with result-building helpers:

| Header | Key Functions |
|--------|-------------|
| `gn_user_sop.h` | `make_sop_result(pos, nrm, uv, col, idx)`, `make_point_cloud(pos)` |
| `gn_user_chop.h` | `make_chop_result(channels_dict)`, `make_chop_single(name, arr)` |
| `gn_user_img.h` | `make_img_result(image)`, `get_input_image(inputs, i)`, `create_like(img)` |
| `gn_user_top.h` | `make_top_shader_result(code, uniforms)`, `make_top_image_result(img)` |
| `gn_user_dat.h` | `make_dat_table(headers, rows)`, `make_dat_text(text)` |

---

## Port Definitions

Return an Array of Dictionaries from `get_port_definitions()`:

```cpp
Dictionary port;
port["name"]      = "geo_in";       // unique port id
port["family"]    = "SOP";          // SOP, CHOP, TOP, IMG, DAT, MAT
port["direction"] = "input";        // "input" or "output"
port["required"]  = true;           // optional, default false
port["label"]     = "Input Mesh";   // display label
```

Ports defined in C++ override the GDScript defaults. The wrapper
automatically syncs ports after each successful build.

---

## Cook Context

The `context` Dictionary passed to `native_cook()`:

| Key | Type | Description |
|-----|------|-------------|
| `delta` | float | Frame delta time (seconds) |
| `elapsed` | float | Total elapsed time since engine start |
| `frame` | int | Current frame number |

---

## Threading Safety

User C++ operators cook on the **WorkerThreadPool** alongside other CPU
families (CHOP, SOP, IMG, DAT). This means:

- Your `native_cook()` may run on **any thread**.
- Do **not** access `RenderingServer` or any GPU API directly.
- Use only thread-safe Godot types (`PackedFloat32Array`, `Image`, `Dictionary`, etc.).
- For TOP operators, return shader code + uniforms — the GDScript wrapper
  handles GPU submission on the main thread.

---

## Hot Reload

When you modify and rebuild:
1. The GDExtension library is unloaded via `GDExtensionManager`.
2. The new library is loaded.
3. A fresh processor instance is created.
4. Port and parameter definitions are re-synced.
5. The node re-cooks immediately.

This happens without restarting Godot. During reload there is a brief
pause (typically <100ms).

---

## Examples

Loadable from the code editor's **Examples** menu:

| Example | Family | Description |
|---------|--------|-------------|
| Wave Deform | SOP | Travelling sine wave vertex displacement |
| Signal Generator | CHOP | Multi-waveform signal generator (sine/saw/square/tri/noise) |
| Edge Detect | IMG | 3×3 Sobel edge detection |
| Game of Life | TOP | Conway's Game of Life as GPU shader |
| CSV Parser | DAT | High-performance CSV parsing |

---

## File Structure

```
addons/gn_ext_user_native/
  gn_extension.cfg          # Extension manifest
  README.md                 # This file
  sdk/                      # C++ SDK headers
    gn_user_types.h
    gn_user_node.h
    gn_user_sop.h
    gn_user_chop.h
    gn_user_img.h
    gn_user_top.h
    gn_user_dat.h
  core/                     # Infrastructure
    gn_native_file_watch.gd
    gn_native_compiler.gd
    gn_native_reloader.gd
    gn_cpp_code_editor.gd
  operators/                # GDScript wrappers
    sop/user_native_sop.gd
    chop/user_native_chop.gd
    img/user_native_img.gd
    top/user_native_top.gd
    dat/user_native_dat.gd
  templates/                # Minimal starters per family
    sop_template.h
    chop_template.h
    img_template.h
    top_template.h
    dat_template.h
  examples/                 # Full worked examples
    wave_deform_sop.h
    signal_gen_chop.h
    edge_detect_img.h
    life_top.h
    csv_parse_dat.h
  help/                     # Help patches (loadable in editor)
    sop/usernativesop_basic.gnpatch
    chop/usernativechop_basic.gnpatch
    img/usernativeimg_basic.gnpatch
    top/usernativetop_basic.gnpatch
    dat/usernativedat_basic.gnpatch
  toolchain/                # Bundled build dependencies
    README.md
```
