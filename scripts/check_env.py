#!/usr/bin/env python3
"""
GONODES — Build Environment Pre-Flight Check

Verifies that all required tools, godot-cpp, and SDK dependencies are present
before starting a build or release.

Usage:
  python scripts/check_env.py           # full report
  python scripts/check_env.py --strict  # exit 1 on any failure (for CI)
"""
import argparse
import configparser
import glob
import os
import platform
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSIONS_FILE = os.path.join(ROOT, "versions.env")
GODOTCPP_DIR = os.path.join(ROOT, "addons", "gn_ext_native", "native", "godot-cpp")

# ── Helpers ────────────────────────────────────────────────────────────────────

PASS = "PASS"
WARN = "WARN"
FAIL = "FAIL"
SKIP = "SKIP"

_results: list[tuple[str, str, str]] = []  # (status, label, detail)


def record(status: str, label: str, detail: str = ""):
    _results.append((status, label, detail))


def _load_versions_env() -> dict:
    vals = {}
    if os.path.isfile(VERSIONS_FILE):
        with open(VERSIONS_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip()
    return vals


def _get_app_version() -> str:
    project_godot = os.path.join(ROOT, "project.godot")
    with open(project_godot, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r'config/version\s*=\s*"([^"]+)"', content)
    return m.group(1) if m else "unknown"


def _run_quiet(cmd: list[str]) -> str | None:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or r.stderr.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


# ── Tool checks ────────────────────────────────────────────────────────────────

def check_python():
    ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    if sys.version_info >= (3, 8):
        record(PASS, "Python", ver)
    else:
        record(FAIL, "Python", f"{ver} (need 3.8+)")


def check_scons():
    out = _run_quiet(["scons", "--version"])
    if out:
        m = re.search(r"v([\d.]+)", out)
        record(PASS, "SCons", m.group(1) if m else "found")
    else:
        record(FAIL, "SCons", "not found — pip install scons")


def check_cpp_compiler():
    system = platform.system()
    if system == "Windows":
        # Check for cl.exe directly first
        if shutil.which("cl"):
            out = _run_quiet(["cl"])
            record(PASS, "C++ compiler (MSVC)", "cl.exe in PATH")
            return
        # Fall back to vswhere
        vswhere = os.path.join(
            os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
            "Microsoft Visual Studio", "Installer", "vswhere.exe",
        )
        if os.path.isfile(vswhere):
            out = _run_quiet([vswhere, "-latest", "-property", "displayName"])
            if out:
                record(PASS, "C++ compiler (MSVC)", f"{out} (cl.exe not in PATH — use Developer Command Prompt for builds)")
                return
        record(FAIL, "C++ compiler (MSVC)", "VS Build Tools not found")
    elif system == "Linux":
        gcc = shutil.which("g++")
        if gcc:
            out = _run_quiet(["g++", "--version"])
            ver_line = (out or "").split("\n")[0] if out else ""
            record(PASS, "C++ compiler (GCC)", ver_line or "found")
        else:
            record(FAIL, "C++ compiler (GCC)", "not found — sudo apt install build-essential")
    elif system == "Darwin":
        out = _run_quiet(["clang++", "--version"])
        if out:
            record(PASS, "C++ compiler (clang)", out.split("\n")[0])
        else:
            record(FAIL, "C++ compiler (clang)", "not found — xcode-select --install")


def check_godot(versions: dict):
    expected = versions.get("GODOT_VERSION", "")
    # Check GONODES_GODOT environment variable first
    env_godot = os.environ.get("GONODES_GODOT", "")
    if env_godot and os.path.isfile(env_godot):
        out = _run_quiet([env_godot, "--version"])
        if out:
            record(PASS, "Godot editor", f"{out.split(chr(10))[0]} (via GONODES_GODOT)")
            return
    # Try common binary names
    for name in ["godot", f"Godot_v{expected}-stable_win64_console"]:
        exe = shutil.which(name)
        if exe:
            out = _run_quiet([exe, "--version"])
            if out:
                record(PASS, "Godot editor", out.split("\n")[0])
                return
    # Try known Windows path
    win_path = os.path.join(
        os.path.dirname(ROOT),
        f"Godot_v{expected}-stable_win64.exe",
        f"Godot_v{expected}-stable_win64_console.exe",
    )
    if os.path.isfile(win_path):
        out = _run_quiet([win_path, "--version"])
        if out:
            record(PASS, "Godot editor", out.split("\n")[0])
            return
    record(WARN, "Godot editor", f"not found in PATH (expected {expected})")


# ── godot-cpp check ───────────────────────────────────────────────────────────

def check_godotcpp():
    sconstruct = os.path.join(GODOTCPP_DIR, "SConstruct")
    if not os.path.isfile(sconstruct):
        record(FAIL, "godot-cpp", f"missing — run: python setup_deps.py --core")
        return

    record(PASS, "godot-cpp", "cloned")

    # Check for built libraries
    bin_dir = os.path.join(GODOTCPP_DIR, "bin")
    if not os.path.isdir(bin_dir):
        record(WARN, "godot-cpp libs", "bin/ not found — needs building")
        return

    system = platform.system().lower()
    plat_map = {"windows": "windows", "linux": "linux", "darwin": "macos"}
    plat = plat_map.get(system, system)

    libs = [f for f in os.listdir(bin_dir)
            if plat in f.lower() and "template_release" in f]
    if libs:
        record(PASS, "godot-cpp libs", f"{len(libs)} release lib(s) for {plat}")
    else:
        record(WARN, "godot-cpp libs", f"no template_release libs for {plat}")


# ── SDK checks (scanned from build.cfg files) ─────────────────────────────────

# Directories that are bundled thirdparty code (not external SDKs).
_BUNDLED_DIRS = {"src", "hap", "snappy", "squish", "rtmidi", "Syphon-Framework"}

# Directories cloned by setup_deps.py (auto-fetched, not manual SDKs).
_AUTO_FETCHED = {"Spout2", "godot-cpp"}


def _parse_sdk_dirs_from_build_cfg(cfg_path: str) -> list[tuple[str, str, bool]]:
    """Parse a build.cfg and return SDK directories it references.

    Returns list of (sdk_dir_relative_to_native, extension_name, is_optional).
    Only returns dirs that look like external SDKs (not src/, not bundled thirdparty).
    """
    ext_dir = os.path.dirname(os.path.dirname(cfg_path))  # addons/gn_ext_foo
    ext_name = os.path.basename(ext_dir)
    native_dir = os.path.dirname(cfg_path)

    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read(cfg_path, encoding="utf-8")

    sdk_dirs: set[str] = set()

    # Gather include_dirs and lib_dirs from all sections
    for section in cfg.sections():
        for key in cfg[section]:
            if "include_dir" in key or "lib_dir" in key:
                for part in cfg[section][key].split(","):
                    part = part.strip()
                    if not part:
                        continue
                    # Extract the top-level directory
                    top = part.split("/")[0].split("\\")[0]
                    if top and top not in _BUNDLED_DIRS and top not in _AUTO_FETCHED:
                        sdk_dirs.add(top)

    results = []
    for sd in sorted(sdk_dirs):
        # Check if this SDK is optional (common pattern: depth sensor sub-SDKs)
        is_optional = "depth_sensor" in ext_name or "optional" in sd.lower()
        full_path = os.path.join(native_dir, sd)
        results.append((full_path, ext_name, is_optional))

    return results


def check_sdks():
    """Scan all build.cfg files to discover SDK requirements programmatically."""
    cfg_pattern = os.path.join(ROOT, "addons", "gn_ext_*", "native", "build.cfg")
    cfg_files = sorted(glob.glob(cfg_pattern))

    # Also check known SDK locations for extensions without build.cfg (e.g., FFmpeg)
    # These use prebuilt shared libs with no native compile step.
    system = platform.system().lower()
    plat_dirs = {
        "windows": "win64",
        "linux": "linux64",
        "darwin": "macos",
    }
    prebuilt_pattern = os.path.join(ROOT, "addons", "gn_ext_*", "native")
    for native_dir in sorted(glob.glob(prebuilt_pattern)):
        ext_name = os.path.basename(os.path.dirname(native_dir))
        cfg_path = os.path.join(native_dir, "build.cfg")
        if os.path.isfile(cfg_path):
            continue  # handled below
        # Check if it has platform subdirectories with shared libs
        plat_subdir = plat_dirs.get(system)
        if plat_subdir:
            plat_path = os.path.join(native_dir, plat_subdir)
            if os.path.isdir(plat_path):
                has_libs = any(
                    f.endswith((".dll", ".so", ".dylib"))
                    for f in os.listdir(plat_path)
                )
                if has_libs:
                    record(PASS, f"{ext_name} libs", f"{plat_subdir}/ present")
                else:
                    record(WARN, f"{ext_name} libs", f"{plat_subdir}/ exists but no shared libs found")

    # Parse each build.cfg for SDK deps
    for cfg_path in cfg_files:
        ext_dir = os.path.dirname(os.path.dirname(cfg_path))
        ext_name = os.path.basename(ext_dir)

        sdk_deps = _parse_sdk_dirs_from_build_cfg(cfg_path)
        if not sdk_deps:
            continue

        for sdk_path, _, is_optional in sdk_deps:
            sdk_name = os.path.basename(sdk_path)
            label = f"{ext_name}/{sdk_name}"
            if os.path.isdir(sdk_path):
                record(PASS, label, "present")
            elif is_optional:
                record(SKIP, label, "optional — not installed")
            else:
                record(WARN, label, "missing — extension will not build")

    # Check embeddable Python for gn_ext_user_python
    py_toolchain = os.path.join(ROOT, "addons", "gn_ext_user_python", "toolchain", "python")
    if os.path.isdir(py_toolchain):
        record(PASS, "gn_ext_user_python/toolchain", "embeddable Python present")
    else:
        record(WARN, "gn_ext_user_python/toolchain", "missing — user Python operators won't work")

    # Check Spout2 (auto-fetched, but verify)
    spout_dir = os.path.join(ROOT, "addons", "gn_ext_spout", "native", "Spout2")
    if platform.system() == "Windows":
        if os.path.isdir(spout_dir):
            record(PASS, "gn_ext_spout/Spout2", "present (auto-fetched)")
        else:
            record(WARN, "gn_ext_spout/Spout2", "missing — run: python setup_deps.py --core")


# ── Report ─────────────────────────────────────────────────────────────────────

def print_report(strict: bool) -> int:
    print()
    print("=" * 64)
    print("  GONODES Build Environment Report")
    print("=" * 64)
    app_ver = _get_app_version()
    print(f"  GONODES version : {app_ver}")
    print(f"  Platform        : {platform.system()} {platform.machine()}")
    print(f"  Python          : {sys.version.split()[0]}")
    print("-" * 64)

    fails = 0
    warns = 0
    for status, label, detail in _results:
        icon = {"PASS": "+", "FAIL": "X", "WARN": "!", "SKIP": "-"}[status]
        line = f"  [{icon}] {label}"
        if detail:
            line += f"  —  {detail}"
        print(line)
        if status == FAIL:
            fails += 1
        elif status == WARN:
            warns += 1

    print("-" * 64)
    total = len(_results)
    passed = sum(1 for s, _, _ in _results if s == PASS)
    skipped = sum(1 for s, _, _ in _results if s == SKIP)
    print(f"  {passed}/{total} passed, {warns} warnings, {fails} failures, {skipped} skipped")

    if fails:
        print("\n  Fix the failures above before building.")
        return 1
    if warns and strict:
        print("\n  Strict mode: warnings treated as errors.")
        return 1
    if warns:
        print("\n  Warnings are non-blocking. Missing SDKs = those extensions won't build.")
    else:
        print("\n  All checks passed!")
    print()
    return 0


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="GONODES build environment check")
    parser.add_argument(
        "--strict", action="store_true",
        help="Treat warnings as errors (for CI).",
    )
    args = parser.parse_args()

    versions = _load_versions_env()

    # Tools
    check_python()
    check_scons()
    check_cpp_compiler()
    check_godot(versions)

    # Core dependency
    check_godotcpp()

    # Extension SDKs (programmatically discovered from build.cfg)
    check_sdks()

    sys.exit(print_report(args.strict))


if __name__ == "__main__":
    main()
