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

### Option A: Clone (recommended)

```bash
cd addons/gn_ext_user_native/toolchain
git clone --depth 1 --branch godot-4.2-stable https://github.com/godotengine/godot-cpp.git
```

This places the full godot-cpp source tree in `toolchain/godot-cpp/`.
The compiler searches this path first.

### Option B: Environment variable

Set `GODOT_CPP_PATH` to an existing godot-cpp checkout anywhere on disk:

```bash
# Windows (PowerShell)
$env:GODOT_CPP_PATH = "C:\dev\godot-cpp"

# Linux / macOS
export GODOT_CPP_PATH="/home/user/godot-cpp"
```

### Option C: System-wide

If godot-cpp is installed in a standard location or already in your
SCons `CPPPATH`, no extra config is needed — the compiler falls back
to system paths.

---

## Setup: SCons

SCons is the build system (same one Godot itself uses).

```bash
pip install scons
```

Verify:
```bash
scons --version
```

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
var status = compiler.get_toolchain_status()
print(status)
# {"scons": true, "godot_cpp": true, "compiler": "MSVC"}
```

If any component is missing, the status Dictionary tells you what to install.

---

## Build Output

Compiled libraries are placed in:

```
user://native_build/<node_id>/
  libuser_<node_id>.dll        # Windows
  libuser_<node_id>.so         # Linux
  libuser_<node_id>.dylib      # macOS
  libuser_<node_id>.gdextension
  register_types.cpp           # Auto-generated
  SConstruct                   # Auto-generated
  user_code.h                  # Your source
```

Each node gets its own build directory to avoid conflicts.
The `clean_build()` method removes these files for a fresh build.
