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
import configparser
import platform as _platform

# SCons builtins needed: Environment, Glob, File, Default, Exit, ARGUMENTS, Dir
from SCons.Script import *  # noqa: F403


# ── Constants ──────────────────────────────────────────────────────────────────

ALL_PLATFORMS = ["windows", "macos", "linux"]
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
    machine = _platform.machine().lower()
    if machine in ("aarch64", "arm64"):
        return "arm64"
    return "x86_64"


def is_cross_compile(target_arch):
    return target_arch != detect_host_arch()


# ── Config parsing ─────────────────────────────────────────────────────────────

def parse_build_cfg(cfg_path):
    """Parse a build.cfg into a dictionary with typed values."""
    cp = configparser.ConfigParser()
    cp.read(cfg_path)

    def get_list(section, key, fallback=""):
        raw = cp.get(section, key, fallback=fallback).strip()
        if not raw:
            return []
        return [s.strip() for s in raw.split(",") if s.strip()]

    cfg = {
        "lib_name":      cp.get("library", "name", fallback=""),
        "entry_symbol":  cp.get("library", "entry_symbol", fallback=""),
        "platforms":     get_list("library", "platforms") or ALL_PLATFORMS,
        "sources":       get_list("sources", "cpp", fallback="src/*.cpp"),
        "c_sources":     get_list("sources", "c"),
        "objcxx_sources": get_list("sources", "objcxx"),  # .mm files (macOS)
        "thirdparty_cpp": get_list("sources", "thirdparty_cpp"),
        "thirdparty_c":   get_list("sources", "thirdparty_c"),
        "thirdparty_cc":  get_list("sources", "thirdparty_cc"),
        "include_dirs":   get_list("sources", "include_dirs"),
    }

    # Per-platform sections: [windows], [macos], [linux]
    for plat in ALL_PLATFORMS:
        cfg[plat] = {
            "libs":       get_list(plat, "libs") if cp.has_section(plat) else [],
            "frameworks": get_list(plat, "frameworks") if cp.has_section(plat) else [],
            "defines":    get_list(plat, "defines") if cp.has_section(plat) else [],
            "objcxx_sources": get_list(plat, "objcxx_sources") if cp.has_section(plat) else [],
        }

    return cfg


# ── Environment construction ───────────────────────────────────────────────────

def make_env(plat, target, arch, godotcpp_root, cfg, native_dir):
    """
    Create a fully configured SCons Environment for the given platform/arch.
    Returns (env, suffix, out_dir) or None if the platform should be skipped.
    """
    if plat not in cfg["platforms"]:
        print(f"  {cfg['lib_name']}: Skipping — platform '{plat}' not supported.")
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
        for d in cfg["linux"]["defines"]:
            env.Append(CPPDEFINES=[d])

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


# ── Discovery ──────────────────────────────────────────────────────────────────

def discover_extensions(addons_dir="addons"):
    """
    Scan addons/ for gn_ext_*/native/build.cfg files.
    Returns a list of (ext_name, native_dir, cfg_path) tuples.
    gn_ext_native is excluded — it uses godot-cpp's SConstruct directly.
    """
    extensions = []
    if not os.path.isdir(addons_dir):
        return extensions

    for entry in sorted(os.listdir(addons_dir)):
        if not entry.startswith("gn_ext_") or entry == "gn_ext_native":
            continue
        native_dir = os.path.join(addons_dir, entry, "native")
        cfg_path = os.path.join(native_dir, "build.cfg")
        if os.path.isfile(cfg_path):
            extensions.append((entry, native_dir, cfg_path))

    return extensions


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
    if arch is None:
        arch = ARGUMENTS.get("arch", "") or detect_host_arch()

    print(f"Building {cfg['lib_name']}: platform={plat}  target={target}  arch={arch}")

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
    return library
