#!/usr/bin/env python3
"""
build_user_node.py — CLI build script for user native C++ operators.

Compiles a single user C++ header into a hot-reloadable GDExtension library,
independent of the Godot editor.

Usage:
  python build_user_node.py <source.h> <ClassName> [options]

Examples:
  python build_user_node.py my_deformer.h MyDeformer
  python build_user_node.py wave_sop.h WaveDeformSOP --platform windows --arch x86_64
  python build_user_node.py life_top.h LifeTOP --godot-cpp /path/to/godot-cpp
  python build_user_node.py my_node.h MyNode --clean

Prerequisites:
  - godot-cpp checked out and built (SCons or pre-built)
  - SCons installed (pip install scons)  OR  a C++ compiler on PATH
  - SDK headers in ../sdk/ (relative to this script)
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import textwrap


# ── Templates ──────────────────────────────────────────────────────────────────

REGISTER_TYPES_TEMPLATE = """\
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "{source_filename}"

using namespace godot;

void initialize_user_node(ModuleInitializationLevel p_level) {{
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<{class_name}>();
}}

void uninitialize_user_node(ModuleInitializationLevel p_level) {{
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
}}

extern "C" {{
GDExtensionBool GDE_EXPORT user_node_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization) {{
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_user_node);
    init_obj.register_terminator(uninitialize_user_node);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}}
}}
"""

SCONSTRUCT_TEMPLATE = """\
#!/usr/bin/env python
import os, sys

godot_cpp_path = "{godot_cpp_path}"
if not os.path.isdir(godot_cpp_path):
    print("ERROR: godot-cpp not found at:", godot_cpp_path)
    sys.exit(1)

env = SConscript(os.path.join(godot_cpp_path, "SConstruct"))
env.Append(CPPPATH=["{sdk_path}"])

sources = Glob("*.cpp")
library = env.SharedLibrary(
    target="bin/{lib_name}" + env["suffix"] + env["SHLIBSUFFIX"],
    source=sources,
)
Default(library)
"""

GDEXTENSION_TEMPLATE = """\
[configuration]
entry_symbol = "user_node_init"
compatibility_minimum = 4.1
reloadable = true

[libraries]
{lib_entries}
"""


# ── Platform detection ─────────────────────────────────────────────────────────

def detect_platform():
    if sys.platform == "win32":
        return "windows"
    elif sys.platform == "darwin":
        return "macos"
    return "linux"


def detect_arch():
    machine = platform.machine().lower()
    if machine in ("aarch64", "arm64"):
        return "arm64"
    return "x86_64"


LIB_EXT = {"windows": ".dll", "linux": ".so", "macos": ".dylib"}


# ── godot-cpp discovery ───────────────────────────────────────────────────────

def find_godot_cpp(explicit_path=None):
    """Search for godot-cpp in standard locations."""
    candidates = []
    if explicit_path:
        candidates.append(explicit_path)
    candidates.append(os.environ.get("GODOT_CPP_PATH", ""))

    # Relative to this script's addon
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates.append(os.path.join(script_dir, "toolchain", "godot-cpp"))

    # Project-level (gn_ext_native's copy)
    project_root = os.path.normpath(os.path.join(script_dir, "..", ".."))
    candidates.append(os.path.join(project_root, "addons", "gn_ext_native", "native", "godot-cpp"))

    for path in candidates:
        if path and os.path.isdir(path):
            return os.path.abspath(path)
    return None


# ── Build logic ────────────────────────────────────────────────────────────────

def build_scons(build_dir, plat, arch, jobs):
    """Build using SCons."""
    scons = shutil.which("scons")
    if not scons:
        return None  # signal: not available
    cmd = [
        scons, "-C", build_dir,
        f"platform={plat}",
        f"arch={arch}",
        "target=template_release",
        f"-j{jobs}",
    ]
    print(f"  Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result


def build_direct(build_dir, source_cpp, lib_name, plat, arch,
                 godot_cpp_path, sdk_path):
    """Build using direct compiler invocation (fallback)."""
    suffix = f".{plat}.template_release.{arch}"
    includes = [
        os.path.join(godot_cpp_path, "include"),
        os.path.join(godot_cpp_path, "gen", "include"),
        os.path.join(godot_cpp_path, "gdextension"),
        sdk_path,
    ]

    # Find pre-built godot-cpp lib
    if plat == "windows":
        godotcpp_lib = os.path.join(godot_cpp_path, "bin", f"libgodot-cpp{suffix}.lib")
    else:
        godotcpp_lib = os.path.join(godot_cpp_path, "bin", f"libgodot-cpp{suffix}.a")

    if not os.path.isfile(godotcpp_lib):
        print(f"  ERROR: godot-cpp library not found: {godotcpp_lib}")
        print(f"  Build godot-cpp first: cd {godot_cpp_path} && scons platform={plat} arch={arch}")
        return subprocess.CompletedProcess([], 1, stderr="godot-cpp not built")

    bin_dir = os.path.join(build_dir, "bin")
    os.makedirs(bin_dir, exist_ok=True)
    ext = LIB_EXT[plat]
    out_path = os.path.join(bin_dir, f"{lib_name}{suffix}{ext}")

    if plat == "windows":
        compiler = shutil.which("cl")
        if compiler:
            return _build_msvc(build_dir, bin_dir, source_cpp, out_path,
                               suffix, includes, godotcpp_lib, lib_name, arch)
        compiler = shutil.which("g++") or shutil.which("clang++")
    else:
        compiler = shutil.which("g++") or shutil.which("clang++")

    # Linux ARM64 cross-compilation: prefer aarch64-linux-gnu-g++
    if plat == "linux" and arch == "arm64":
        cross = shutil.which("aarch64-linux-gnu-g++")
        if cross:
            compiler = cross

    if not compiler:
        print("  ERROR: No C++ compiler found on PATH.")
        return subprocess.CompletedProcess([], 1, stderr="No compiler")

    return _build_gcc(compiler, source_cpp, out_path, plat, includes, godotcpp_lib, arch)


def _build_msvc(build_dir, bin_dir, source_cpp, out_path, suffix,
                includes, godotcpp_lib, lib_name, arch="x86_64"):
    """Direct MSVC compile + link."""
    obj_path = os.path.join(build_dir, "register_types.obj")
    compile_cmd = [
        "cl", "/c", "/std:c++17", "/EHsc", "/utf-8",
        "/O2", "/MT", "/DNDEBUG",
        "/DWINDOWS_ENABLED", "/DTYPED_METHOD_BIND", "/DNOMINMAX",
        "/DWIN32", "/D_WIN32",
    ]
    if arch == "arm64":
        compile_cmd.append("/arch:ARM64")
    for inc in includes:
        compile_cmd.append(f"/I{inc}")
    compile_cmd += [f"/Fo{obj_path}", source_cpp]

    print(f"  Compile: cl ...")
    result = subprocess.run(compile_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        return result

    link_cmd = ["link", "/DLL", f"/OUT:{out_path}", obj_path, godotcpp_lib]
    print(f"  Link: link /DLL ...")
    result = subprocess.run(link_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
    return result


def _build_gcc(compiler, source_cpp, out_path, plat, includes, godotcpp_lib,
               arch="x86_64"):
    """Direct g++/clang++ compile + link."""
    cmd = [
        compiler, "-std=c++17", "-fPIC", "-O2", "-DNDEBUG",
        "-DTYPED_METHOD_BIND",
    ]
    if plat == "linux":
        cmd += ["-DLINUX_ENABLED", "-shared"]
    else:  # macOS
        cmd += ["-DMACOS_ENABLED", "-arch", arch, "-dynamiclib"]

    for inc in includes:
        cmd += ["-I", inc]
    cmd += ["-o", out_path, source_cpp, godotcpp_lib]

    print(f"  Compile+link: {compiler} ...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
    return result


def write_gdextension(build_dir, lib_name, lib_filename, plat, arch):
    """Write the .gdextension manifest."""
    relative = f"bin/{lib_filename}"
    if plat == "macos":
        entries = f'macos.debug = "{relative}"\nmacos.release = "{relative}"\n'
    else:
        entries = (
            f'{plat}.debug.{arch} = "{relative}"\n'
            f'{plat}.release.{arch} = "{relative}"\n'
        )

    content = GDEXTENSION_TEMPLATE.format(lib_entries=entries)
    gde_path = os.path.join(build_dir, f"{lib_name}.gdextension")
    with open(gde_path, "w", encoding="utf-8") as f:
        f.write(content)
    return gde_path


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Build a user native C++ operator into a GDExtension library.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            The build script looks for godot-cpp in this order:
              1. --godot-cpp argument
              2. GODOT_CPP_PATH environment variable
              3. toolchain/godot-cpp/ (next to this script)
              4. addons/gn_ext_native/native/godot-cpp/ (project root)
        """),
    )
    parser.add_argument("source", help="Path to the C++ header file (.h)")
    parser.add_argument("class_name", help="C++ class name to register")
    parser.add_argument("--platform", default=detect_platform(),
                        choices=["windows", "macos", "linux"],
                        help="Target platform (default: auto-detect)")
    parser.add_argument("--arch", default=detect_arch(),
                        choices=["x86_64", "arm64"],
                        help="Target architecture (default: auto-detect)")
    parser.add_argument("--godot-cpp", dest="godot_cpp",
                        help="Path to godot-cpp checkout")
    parser.add_argument("--output", "-o",
                        help="Output directory (default: build_<class_name>/)")
    parser.add_argument("--jobs", "-j", type=int,
                        default=os.cpu_count() or 4,
                        help="Parallel build jobs")
    parser.add_argument("--clean", action="store_true",
                        help="Remove build directory before building")
    parser.add_argument("--no-scons", action="store_true",
                        help="Skip SCons, use direct compiler invocation")
    args = parser.parse_args()

    source_path = os.path.abspath(args.source)
    if not os.path.isfile(source_path):
        print(f"ERROR: Source file not found: {source_path}")
        return 1

    class_name = args.class_name
    plat = args.platform
    arch = args.arch

    # Determine build directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sdk_path = os.path.join(script_dir, "sdk")
    if not os.path.isdir(sdk_path):
        print(f"ERROR: SDK headers not found at: {sdk_path}")
        return 1

    build_dir = args.output or os.path.join(
        script_dir, "build_output", f"build_{class_name.lower()}")

    if args.clean and os.path.isdir(build_dir):
        print(f"  Cleaning: {build_dir}")
        shutil.rmtree(build_dir)

    os.makedirs(build_dir, exist_ok=True)

    # Find godot-cpp
    godot_cpp = find_godot_cpp(args.godot_cpp)
    if not godot_cpp:
        print("ERROR: godot-cpp not found.")
        print("  --godot-cpp /path/to/godot-cpp")
        print("  OR set GODOT_CPP_PATH environment variable")
        print("  OR clone into toolchain/godot-cpp/")
        return 1

    print(f"Building: {class_name}")
    print(f"  Source:    {source_path}")
    print(f"  Platform:  {plat}/{arch}")
    print(f"  godot-cpp: {godot_cpp}")
    print(f"  SDK:       {sdk_path}")
    print(f"  Build dir: {build_dir}")

    # Copy source to build dir
    source_filename = os.path.basename(source_path)
    dest_source = os.path.join(build_dir, source_filename)
    shutil.copy2(source_path, dest_source)

    # Generate register_types.cpp
    reg_cpp = REGISTER_TYPES_TEMPLATE.format(
        source_filename=source_filename,
        class_name=class_name,
    )
    reg_path = os.path.join(build_dir, "register_types.cpp")
    with open(reg_path, "w", encoding="utf-8") as f:
        f.write(reg_cpp)

    lib_name = f"libuser_{class_name.lower()}"
    success = False

    if not args.no_scons:
        # Generate SConstruct
        sconstruct = SCONSTRUCT_TEMPLATE.format(
            godot_cpp_path=godot_cpp.replace("\\", "/"),
            sdk_path=sdk_path.replace("\\", "/"),
            lib_name=lib_name,
        )
        with open(os.path.join(build_dir, "SConstruct"), "w", encoding="utf-8") as f:
            f.write(sconstruct)

        result = build_scons(build_dir, plat, arch, args.jobs)
        if result is not None:
            if result.returncode == 0:
                success = True
            else:
                print(f"\nSCons build failed (exit {result.returncode}):")
                print(result.stdout)
                print(result.stderr)
        else:
            print("  SCons not found, falling back to direct compiler...")

    if not success:
        result = build_direct(build_dir, reg_path, lib_name, plat, arch,
                              godot_cpp, sdk_path)
        success = (result.returncode == 0)

    if not success:
        print("\nBuild FAILED.")
        return 1

    # Find compiled library
    bin_dir = os.path.join(build_dir, "bin")
    lib_filename = None
    if os.path.isdir(bin_dir):
        for f in os.listdir(bin_dir):
            if f.startswith(lib_name):
                lib_filename = f
                break

    if not lib_filename:
        print("\nBuild succeeded but compiled library not found in bin/.")
        return 1

    # Write .gdextension
    gde_path = write_gdextension(build_dir, lib_name, lib_filename, plat, arch)

    print(f"\nBuild SUCCESS:")
    print(f"  Library:      {os.path.join(bin_dir, lib_filename)}")
    print(f"  .gdextension: {gde_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
