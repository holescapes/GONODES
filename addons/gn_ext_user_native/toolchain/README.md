# Bundled Toolchain

This directory holds the build dependencies for compiling user C++ operators.

---

## Directory Structure

```
toolchain/
  godot-cpp/           ← Clone or symlink godot-cpp here
  README.md            ← This file
```

---

## Setup: godot-cpp

The compiler needs godot-cpp headers and bindings to build GDExtension libraries.

The build system searches for godot-cpp in this order:

1. `toolchain/godot-cpp/` — bundled with the extension (checked first)
2. `GODOT_CPP_PATH` environment variable — point to any checkout on disk
3. `addons/gn_ext_native/native/godot-cpp/` — the project's shared copy

### Option A: Clone into toolchain (recommended for standalone use)

```bash
cd addons/gn_ext_user_native/toolchain
git clone --depth 1 --branch godot-4.2-stable https://github.com/godotengine/godot-cpp.git
```

### Option B: Use the project's godot-cpp (zero-config if gn_ext_native is built)

If you've already built `gn_ext_native`, its `godot-cpp/` directory is
automatically found. No extra setup required.

### Option C: Environment variable

Set `GODOT_CPP_PATH` to an existing godot-cpp checkout anywhere on disk:

```bash
# Windows (PowerShell)
$env:GODOT_CPP_PATH = "C:\dev\godot-cpp"

# Linux / macOS
export GODOT_CPP_PATH="/home/user/godot-cpp"
```

**Important:** godot-cpp must be built (`scons` run inside the godot-cpp
directory) before compiling user nodes. The compiler needs the pre-built
static library (`libgodot-cpp.*.lib` or `.a`).

---

## Setup: Build System

### Option A: SCons (recommended)

SCons is the build system (same one Godot itself uses).

```bash
pip install scons
scons --version
```

### Option B: Direct compiler (automatic fallback)

If SCons is not installed, the compiler falls back to invoking the system
C++ compiler directly (`cl.exe` / `g++` / `clang++`). This requires
godot-cpp to be pre-built.

---

## Setup: C++ Compiler

### Windows

Install **Visual Studio Build Tools** (free):
1. Download from https://visualstudio.microsoft.com/visual-cpp-build-tools/
2. Select **Desktop development with C++**
3. Ensure **MSVC v143** and **Windows SDK** are checked

Or install **TDM-GCC** for a lighter footprint:
1. Download from https://jmeubank.github.io/tdm-gcc/
2. Install to `C:\TDM-GCC-64`
3. Add to PATH

### Linux

```bash
sudo apt install build-essential   # Debian/Ubuntu
sudo dnf install gcc-c++           # Fedora
```

### macOS

```bash
xcode-select --install
```

---

## Checking Toolchain Status

From the C++ code editor's build output, or programmatically:

```gdscript
var compiler = GNNativeCompiler.new()
print(compiler.get_toolchain_status())
# ✓ godot-cpp: /path/to/godot-cpp
# ✓ SCons: scons
# ✓ Platform: windows  Arch: x86_64
```

---

## CLI Build Script

Build user nodes from the command line (outside Godot):

```bash
cd addons/gn_ext_user_native

# Basic usage
python build_user_node.py examples/wave_deform_sop.h WaveDeformSOP

# Specify platform/arch
python build_user_node.py mynode.h MyNode --platform linux --arch x86_64

# Specify godot-cpp path explicitly
python build_user_node.py mynode.h MyNode --godot-cpp /path/to/godot-cpp

# Clean build
python build_user_node.py mynode.h MyNode --clean

# Skip SCons, use direct compiler
python build_user_node.py mynode.h MyNode --no-scons
```

Run `python build_user_node.py --help` for full options.

---

## Build Output

Compiled libraries are placed in:

**From Godot editor** (runtime compile):
```
user://gonodes_native_build/<node_id>/
  user_<node_id>.h              # Your source
  register_types.cpp            # Auto-generated
  SConstruct                    # Auto-generated
  bin/libuser_<node_id>.*       # Compiled library
  libuser_<node_id>.gdextension # Extension manifest
```

**From CLI** (`build_user_node.py`):
```
build_output/build_<classname>/
  <source>.h                    # Copied source
  register_types.cpp            # Auto-generated
  SConstruct                    # Auto-generated
  bin/libuser_<classname>.*     # Compiled library
  libuser_<classname>.gdextension
```

Each node gets its own build directory to avoid conflicts.
The `clean_build()` method removes these files for a fresh build.
