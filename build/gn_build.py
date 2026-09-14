"""
gn_build.py — Shared build configuration for all GONODES GDExtension addons.

This module provides a unified build environment that:
  - Reads a declarative build.cfg from each extension's native/ directory
  - Sets up godot-cpp include paths and links the pre-built static library
  - Handles platform detection, arch detection, cross-compilation
  - Applies platform-specific compiler flags, system libraries, and frameworks
  - Compiles bundled third-party sources inline
  - Outputs shared libraries to the correct bin/<platform>/ directory

Usage from a per-extension SConstruct:
    import sys, os
    sys.path.insert(0, os.path.join("..", "..", "..", "build"))
    from gn_build import build_extension
    build_extension()

Or from the root SConstruct:
    from build.gn_build import discover_extensions, build_extension_at
"""

import os
import sys
import json
import subprocess

from gn_ext_plan import (
    ALL_PLATFORMS,
    parse_build_cfg,
    discover_extensions,
    get_effective_probes,
    check_probes,
    plan_extensions,
    should_build_extension,
    detect_host_platform,
)

# SCons builtins needed: Environment, Glob, File, Default, Exit, ARGUMENTS, Dir
from SCons.Script import *  # noqa: F403


# Re-export for backwards compatibility
__all__ = [
    "ALL_PLATFORMS",
    "parse_build_cfg",
    "discover_extensions",
    "plan_extensions",
    "should_build_extension",
    "detect_host_platform",
    "detect_host_arch",
    "make_env",
    "collect_sources",
    "build_extension",
]
ALL_ARCHS_BY_PLATFORM = {
    "windows": ["x86_64", "arm64"],
    "linux":   ["x86_64", "arm64"],
    "macos":   ["arm64", "x86_64"],  # arm64 first — primary on modern Macs
}

BIN_DIRS = {
    "windows": "bin/win64",
    "linux":   "bin/linux64",
    "macos":   "bin/macos",
}

LIB_EXTENSIONS = {
    "windows": ".dll",
    "linux":   ".so",
    "macos":   ".dylib",
}


# ── Platform / arch detection ──────────────────────────────────────────────────

def detect_host_platform():
    if sys.platform == "win32":
        return "windows"
    elif sys.platform == "darwin":
        return "macos"
    return "linux"


def detect_host_arch():
    import platform as _platform
    machine = _platform.machine().lower()
    if machine in ("aarch64", "arm64"):
        return "arm64"
    return "x86_64"


def is_cross_compile(target_arch):
    return target_arch != detect_host_arch()


# parse_build_cfg, discover_extensions — see gn_ext_plan.py


# ── Environment construction ───────────────────────────────────────────────────

def make_env(plat, target, arch, godotcpp_root, cfg, native_dir):
    """
    Create a fully configured SCons Environment for the given platform/arch.
    Returns (env, suffix, out_dir) or None if the platform should be skipped.
    """
    if plat not in cfg["platforms"]:
        print(f"  {cfg['lib_name']}: Skipping — platform '{plat}' not supported.")
        return None

    # SDK probe — skip when required files are missing.
    probes = get_effective_probes(cfg, plat, native_dir)
    missing = check_probes(probes, native_dir)
    if missing:
        label = "optional" if cfg.get("optional") else "required"
        print(f"  {cfg['lib_name']}: Skipping ({label} SDK missing): {', '.join(missing)}")
        return None

    # Common godot-cpp include paths
    common_cpppath = [
        os.path.join(godotcpp_root, "include"),
        os.path.join(godotcpp_root, "gen", "include"),
        os.path.join(godotcpp_root, "gdextension"),
    ]

    # Extension-local include dirs
    for d in cfg.get("include_dirs", []):
        common_cpppath.append(os.path.join(native_dir, d))

    # Always include src/
    common_cpppath.append(os.path.join(native_dir, "src"))

    out_dir = os.path.join(native_dir, BIN_DIRS[plat])
    lib_ext = LIB_EXTENSIONS[plat]

    # ── Python SDK auto-discovery (for extensions with [python] section) ──
    python_cfg = None
    python_config_script = os.path.join(native_dir, "python_config.py")
    if os.path.isfile(python_config_script):
        # Use GONODES_PYTHON_HOME or the toolchain embeddable if available
        _py_bin = "python.exe" if sys.platform == "win32" else "python3"
        toolchain_python = os.path.abspath(
            os.path.join(native_dir, "..", "toolchain", "python", _py_bin)
        )
        py_exe = os.environ.get("GONODES_PYTHON_HOME", "")
        if py_exe:
            py_exe = os.path.join(py_exe, _py_bin) if os.path.isdir(py_exe) else py_exe
        elif os.path.isfile(toolchain_python):
            py_exe = toolchain_python
        else:
            py_exe = sys.executable  # fallback to current Python
        py_exe = os.path.abspath(py_exe)

        try:
            result = subprocess.run(
                [py_exe, python_config_script, "--json"],
                capture_output=True, text=True, timeout=15,
                cwd=os.path.dirname(py_exe),
            )
            if result.returncode == 0:
                python_cfg = json.loads(result.stdout)
                print(f"  Python SDK: {python_cfg.get('version_full', '?')} "
                      f"(lib={python_cfg.get('lib_name', '?')})")
        except Exception as e:
            print(f"  WARNING: python_config.py failed: {e}")

    if plat == "windows":
        env = Environment(tools=["default", "msvc"])
        env.Append(CPPPATH=common_cpppath)
        env.Append(CXXFLAGS=["/std:c++17", "/EHsc", "/utf-8"])
        env.Append(CPPDEFINES=["WINDOWS_ENABLED", "TYPED_METHOD_BIND", "NOMINMAX", "WIN32", "_WIN32"])

        if target == "template_release":
            env.Append(CXXFLAGS=["/O2", "/MT", "/DNDEBUG"])
        else:
            env.Append(CXXFLAGS=["/Od", "/MTd", "/Zi", "/D_DEBUG"])

        env.Append(LINKFLAGS=["/DLL"])

        # ARM64 cross-compile
        if arch == "arm64" and is_cross_compile("arm64"):
            env["TARGET_ARCH"] = "aarch64"
            env.Append(CXXFLAGS=["/arch:ARM64"])

        suffix = f".windows.{target}.{arch}"
        godotcpp_lib = os.path.join(godotcpp_root, "bin", f"libgodot-cpp{suffix}.lib")
        env.Append(LIBS=[File(godotcpp_lib)])

        # Platform-specific system libs
        for lib in cfg["windows"]["libs"]:
            env.Append(LIBS=[lib])
        for d in cfg["windows"]["lib_dirs"]:
            env.Append(LIBPATH=[os.path.join(native_dir, d)])
        for d in cfg["windows"]["defines"]:
            env.Append(CPPDEFINES=[d])

    elif plat == "macos":
        env = Environment()
        env.Append(CPPPATH=common_cpppath)
        env.Append(CXXFLAGS=["-std=c++17", "-fPIC"])
        env.Append(OBJCXXFLAGS=["-std=c++17", "-fPIC", "-fobjc-arc"])
        env.Append(CPPDEFINES=["MACOS_ENABLED", "TYPED_METHOD_BIND"])

        env.Append(CXXFLAGS=["-arch", arch])
        env.Append(OBJCXXFLAGS=["-arch", arch])
        env.Append(LINKFLAGS=["-arch", arch, "-dynamiclib"])

        if target == "template_release":
            env.Append(CXXFLAGS=["-O2", "-DNDEBUG"])
            env.Append(OBJCXXFLAGS=["-O2", "-DNDEBUG"])
        else:
            env.Append(CXXFLAGS=["-O0", "-g", "-D_DEBUG"])
            env.Append(OBJCXXFLAGS=["-O0", "-g", "-D_DEBUG"])

        suffix = f".macos.{target}.{arch}"
        godotcpp_lib = os.path.join(godotcpp_root, "bin", f"libgodot-cpp{suffix}.a")
        env.Append(LIBS=[File(godotcpp_lib)])

        # Frameworks
        for fw in cfg["macos"]["frameworks"]:
            env.Append(FRAMEWORKS=[fw])
        for d in cfg["macos"]["lib_dirs"]:
            env.Append(LIBPATH=[os.path.join(native_dir, d)])
        for d in cfg["macos"]["defines"]:
            env.Append(CPPDEFINES=[d])

    else:  # linux
        cxx = "g++"
        cc = "gcc"
        if arch == "arm64" and is_cross_compile("arm64"):
            cxx = "aarch64-linux-gnu-g++"
            cc = "aarch64-linux-gnu-gcc"

        env = Environment(CXX=cxx, CC=cc)
        env.Append(CPPPATH=common_cpppath)
        env.Append(CXXFLAGS=["-std=c++17", "-fPIC"])
        env.Append(CPPDEFINES=["LINUX_ENABLED", "TYPED_METHOD_BIND"])
        env.Append(LINKFLAGS=["-shared"])

        if target == "template_release":
            env.Append(CXXFLAGS=["-O2", "-DNDEBUG"])
        else:
            env.Append(CXXFLAGS=["-O0", "-g", "-D_DEBUG"])

        suffix = f".linux.{target}.{arch}"
        godotcpp_lib = os.path.join(godotcpp_root, "bin", f"libgodot-cpp{suffix}.a")
        env.Append(LIBS=[File(godotcpp_lib)])

        for lib in cfg["linux"]["libs"]:
            env.Append(LIBS=[lib])
        for d in cfg["linux"]["lib_dirs"]:
            env.Append(LIBPATH=[os.path.join(native_dir, d)])
        for d in cfg["linux"]["defines"]:
            env.Append(CPPDEFINES=[d])

    # ── Inject optional SDK paths (probe for presence) ──
    for sdk_name, sdk_cfg in cfg[plat].get("optional_sdks", {}).items():
        # An optional SDK is available only when its include/lib dirs exist AND
        # (when libs are declared) at least one expected library file is present.
        # Empty SDK folders used to pass a dir-only check and then fail at link.
        inc_dirs = sdk_cfg.get("include_dirs", [])
        lib_dirs = sdk_cfg.get("lib_dirs", [])
        libs = sdk_cfg.get("libs", [])

        def _resolve(d):
            return d if os.path.isabs(d) else os.path.join(native_dir, d)

        dirs_ok = any(os.path.isdir(_resolve(d)) for d in inc_dirs + lib_dirs)
        if not dirs_ok:
            print(f"  Optional SDK '{sdk_name}': NOT FOUND — skipping")
            continue

        if libs and lib_dirs:
            lib_ok = False
            for lib_dir in lib_dirs:
                root = _resolve(lib_dir)
                for lib in libs:
                    if plat == "windows":
                        candidate = os.path.join(root, f"{lib}.lib")
                    elif plat == "linux":
                        candidate = os.path.join(root, f"lib{lib}.so")
                    else:
                        candidate = os.path.join(root, f"lib{lib}.dylib")
                    if os.path.isfile(candidate):
                        lib_ok = True
                        break
                if lib_ok:
                    break
            if not lib_ok:
                print(f"  Optional SDK '{sdk_name}': libs missing — skipping")
                continue

        print(f"  Optional SDK '{sdk_name}': FOUND — enabling")
        for d in inc_dirs:
            env.Append(CPPPATH=[_resolve(d)])
        for d in lib_dirs:
            env.Append(LIBPATH=[_resolve(d)])
        for lib in libs:
            env.Append(LIBS=[lib])
        for define in sdk_cfg.get("defines", []):
            env.Append(CPPDEFINES=[define])

    # ── Inject Python SDK paths (discovered above) ──
    if python_cfg:
        inc = python_cfg.get("include_dir", "")
        if inc and os.path.isdir(inc):
            env.Append(CPPPATH=[inc])
        lib_dir = python_cfg.get("lib_dir", "")
        if lib_dir and os.path.isdir(lib_dir):
            env.Append(LIBPATH=[lib_dir])
        lib_name = python_cfg.get("lib_name", "")
        if lib_name:
            # Override the hardcoded lib from build.cfg with the discovered one
            env.Append(LIBS=[lib_name])
        np_inc = python_cfg.get("numpy_include", "")
        if np_inc and os.path.isdir(np_inc):
            env.Append(CPPPATH=[np_inc])

    return env, suffix, out_dir, lib_ext


# ── Source collection ──────────────────────────────────────────────────────────

def collect_sources(env, cfg, native_dir, plat):
    """Glob all source files from build.cfg patterns."""
    sources = []

    for pattern in cfg.get("sources", ["src/*.cpp"]):
        sources += Glob(os.path.join(native_dir, pattern))

    for pattern in cfg.get("c_sources", []):
        sources += Glob(os.path.join(native_dir, pattern))

    # Third-party
    for pattern in cfg.get("thirdparty_cpp", []):
        sources += Glob(os.path.join(native_dir, pattern))
    for pattern in cfg.get("thirdparty_c", []):
        sources += Glob(os.path.join(native_dir, pattern))
    for pattern in cfg.get("thirdparty_cc", []):
        sources += Glob(os.path.join(native_dir, pattern))

    # ObjC++ sources — always from global + platform-specific
    if plat == "macos":
        for pattern in cfg.get("objcxx_sources", []):
            sources += Glob(os.path.join(native_dir, pattern))
        for pattern in cfg[plat].get("objcxx_sources", []):
            sources += Glob(os.path.join(native_dir, pattern))

    return sources


# discover_extensions — see gn_ext_plan.py


# ── Build orchestration ────────────────────────────────────────────────────────

def build_extension(native_dir=None, plat=None, target=None, arch=None):
    """
    Build a single extension from its native/ directory.
    Called from per-extension SConstruct or from the root SConstruct.
    """
    if native_dir is None:
        native_dir = os.getcwd()

    cfg_path = os.path.join(native_dir, "build.cfg")
    if not os.path.isfile(cfg_path):
        print(f"ERROR: No build.cfg found at {cfg_path}")
        Exit(1)

    cfg = parse_build_cfg(cfg_path)

    if plat is None:
        plat = ARGUMENTS.get("platform", "") or detect_host_platform()
    if target is None:
        target = ARGUMENTS.get("target", "template_release")
    if target != "template_release":
        print(f"WARNING: GONODES only ships release builds. "
              f"target='{target}' may fail if godot-cpp debug lib is not built.")
    if arch is None:
        arch = ARGUMENTS.get("arch", "") or detect_host_arch()

    print(f"Building {cfg['lib_name']}: platform={plat}  target={target}  arch={arch}")

    # Locate godot-cpp by searching upward from native_dir for the
    # gn_ext_native sibling directory.  Handles standard layout
    # (native_dir = addons/ext/native/) and nested builds
    # (native_dir = addons/ext/native/subdir/).
    godotcpp_root = None
    _search = native_dir
    for _ in range(6):
        _search = os.path.dirname(_search)
        _candidate = os.path.join(_search, "gn_ext_native", "native", "godot-cpp")
        if os.path.isdir(_candidate):
            godotcpp_root = os.path.abspath(_candidate)
            break
    if godotcpp_root is None:
        # Fallback to the original two-level-up path
        godotcpp_root = os.path.abspath(
            os.path.join(native_dir, "..", "..", "gn_ext_native", "native", "godot-cpp")
        )

    result = make_env(plat, target, arch, godotcpp_root, cfg, native_dir)
    if result is None:
        return None

    env, suffix, out_dir, lib_ext = result

    sources = collect_sources(env, cfg, native_dir, plat)
    if not sources:
        print(f"  WARNING: No sources found for {cfg['lib_name']}")
        return None

    os.makedirs(out_dir, exist_ok=True)

    lib_target = os.path.join(out_dir, f"lib{cfg['lib_name']}{suffix}{lib_ext}")
    library = env.SharedLibrary(target=lib_target, source=sources)
    Default(library)

    # If library_dest is set, also copy the built library to that location
    # (relative to extension root). Needed when main DLL must be outside native/.
    import shutil
    lib_dest_rel = cfg.get("library_dest", "")
    if lib_dest_rel:
        ext_root = os.path.dirname(native_dir)
        lib_dest_dir = os.path.normpath(os.path.join(ext_root, lib_dest_rel.rstrip("/\\"), BIN_DIRS[plat]))
        os.makedirs(lib_dest_dir, exist_ok=True)
        lib_copy_dst = os.path.join(lib_dest_dir, os.path.basename(lib_target))
        if os.path.isfile(lib_target):
            shutil.copy2(lib_target, lib_copy_dst)
            print(f"  Copied library: {os.path.basename(lib_target)} -> {lib_dest_dir}")
    import shutil
    plat_cfg = cfg.get(plat, {})
    runtime_dlls = plat_cfg.get("runtime_dlls", [])
    if runtime_dlls:
        # runtime_dlls_dest is relative to the extension root (parent of native_dir).
        # Defaults to out_dir (native/bin/<platform>/) if not set.
        ext_root = os.path.dirname(native_dir)
        dlls_dest_rel = plat_cfg.get("runtime_dlls_dest", "")
        if dlls_dest_rel:
            dlls_dest = os.path.normpath(os.path.join(ext_root, dlls_dest_rel))
        else:
            dlls_dest = out_dir
        os.makedirs(dlls_dest, exist_ok=True)
        for dll_rel in runtime_dlls:
            dll_src = os.path.join(native_dir, dll_rel)
            if os.path.isfile(dll_src):
                dll_dst = os.path.join(dlls_dest, os.path.basename(dll_src))
                if not os.path.isfile(dll_dst):
                    shutil.copy2(dll_src, dll_dst)
                    print(f"  Copied runtime DLL: {os.path.basename(dll_src)} -> {dlls_dest}")

    return library
