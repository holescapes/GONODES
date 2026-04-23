#!/usr/bin/env python3
"""
GONODES — Bundle godot-cpp Toolchain for User C++ Nodes

Copies the built godot-cpp (headers + static libs) into the gn_ext_user_native
toolchain directory so end-users can compile custom C++ operators without
installing Godot or cloning repos.

Usage:
  python scripts/bundle_toolchain.py               # copy for current platform
  python scripts/bundle_toolchain.py --all          # copy for all platforms
  python scripts/bundle_toolchain.py --verify       # just check, don't copy
"""
import argparse
import glob
import os
import platform as _platform
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

GODOTCPP_SRC = os.path.join(ROOT, "addons", "gn_ext_native", "native", "godot-cpp")
TOOLCHAIN_DST = os.path.join(ROOT, "addons", "gn_ext_user_native", "toolchain", "godot-cpp")

# Directories to copy (headers + generated bindings)
HEADER_DIRS = ["include", os.path.join("gen", "include"), "gdextension"]

# Directories to exclude from copy
EXCLUDE_DIRS = {".git", "test", "doc", "misc", ".github", "__pycache__"}

# File patterns to exclude
EXCLUDE_PATTERNS = {".o", ".obj", ".dblite", ".pyc"}


def detect_host_platform() -> str:
    if sys.platform == "win32":
        return "windows"
    elif sys.platform == "darwin":
        return "macos"
    return "linux"


def _should_exclude(name: str) -> bool:
    if name in EXCLUDE_DIRS:
        return True
    _, ext = os.path.splitext(name)
    return ext in EXCLUDE_PATTERNS


def copy_headers():
    """Copy godot-cpp header directories to toolchain."""
    for header_dir in HEADER_DIRS:
        src = os.path.join(GODOTCPP_SRC, header_dir)
        dst = os.path.join(TOOLCHAIN_DST, header_dir)

        if not os.path.isdir(src):
            print(f"  [!] Source header dir not found: {header_dir}")
            continue

        if os.path.isdir(dst):
            shutil.rmtree(dst)

        shutil.copytree(
            src, dst,
            ignore=shutil.ignore_patterns("*.o", "*.obj", "*.pyc", "__pycache__"),
        )
        file_count = sum(1 for _, _, files in os.walk(dst) for _ in files)
        print(f"  [+] {header_dir}/ → {file_count} files")


def copy_libs(platforms: list[str]):
    """Copy pre-built static libraries to toolchain."""
    src_bin = os.path.join(GODOTCPP_SRC, "bin")
    dst_bin = os.path.join(TOOLCHAIN_DST, "bin")

    if not os.path.isdir(src_bin):
        print(f"  [X] godot-cpp bin/ not found — build godot-cpp first")
        return False

    os.makedirs(dst_bin, exist_ok=True)

    plat_map = {"windows": "windows", "linux": "linux", "macos": "macos"}
    lib_exts = {"windows": ".lib", "linux": ".a", "macos": ".a"}

    copied = 0
    for plat in platforms:
        pattern = f"libgodot-cpp.{plat}.template_release.*"
        matches = [f for f in os.listdir(src_bin) if f.startswith(f"libgodot-cpp.{plat}.template_release")]

        for fname in matches:
            src_file = os.path.join(src_bin, fname)
            dst_file = os.path.join(dst_bin, fname)
            shutil.copy2(src_file, dst_file)
            size_mb = os.path.getsize(dst_file) / (1024 * 1024)
            print(f"  [+] bin/{fname} ({size_mb:.1f} MB)")
            copied += 1

    if copied == 0:
        missing = ", ".join(platforms)
        print(f"  [!] No release libs found for: {missing}")
        print(f"      Build first: cd addons/gn_ext_native/native/godot-cpp && scons target=template_release -j8")
        return False

    return True


def copy_sconstruct():
    """Copy SConstruct so user builds can find the godot-cpp build system."""
    src = os.path.join(GODOTCPP_SRC, "SConstruct")
    dst = os.path.join(TOOLCHAIN_DST, "SConstruct")
    if os.path.isfile(src):
        shutil.copy2(src, dst)
        print(f"  [+] SConstruct")


def copy_tools():
    """Copy godot-cpp tools/ directory (SCons tool modules, platform configs)."""
    src = os.path.join(GODOTCPP_SRC, "tools")
    dst = os.path.join(TOOLCHAIN_DST, "tools")
    if not os.path.isdir(src):
        print(f"  [!] tools/ not found in godot-cpp source")
        return
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(
        src, dst,
        ignore=shutil.ignore_patterns("*.pyc", "__pycache__"),
    )
    file_count = sum(1 for _, _, files in os.walk(dst) for _ in files)
    print(f"  [+] tools/ → {file_count} files")


def verify(platforms: list[str]) -> bool:
    """Check that the toolchain has all required files."""
    ok = True

    # Headers
    for header_dir in HEADER_DIRS:
        path = os.path.join(TOOLCHAIN_DST, header_dir)
        if os.path.isdir(path):
            count = sum(1 for _, _, files in os.walk(path) for _ in files)
            print(f"  [+] {header_dir}/ — {count} files")
        else:
            print(f"  [X] {header_dir}/ — MISSING")
            ok = False

    # Libs
    bin_dir = os.path.join(TOOLCHAIN_DST, "bin")
    if not os.path.isdir(bin_dir):
        print(f"  [X] bin/ — MISSING")
        ok = False
    else:
        for plat in platforms:
            found = [f for f in os.listdir(bin_dir)
                     if f.startswith(f"libgodot-cpp.{plat}") and "template_release" in f]
            if found:
                for f in found:
                    size_mb = os.path.getsize(os.path.join(bin_dir, f)) / (1024 * 1024)
                    print(f"  [+] bin/{f} ({size_mb:.1f} MB)")
            else:
                print(f"  [X] bin/ — no release lib for {plat}")
                ok = False

    # Tools (SCons tool modules)
    tools_dir = os.path.join(TOOLCHAIN_DST, "tools")
    godotcpp_tool = os.path.join(tools_dir, "godotcpp.py")
    if os.path.isfile(godotcpp_tool):
        count = sum(1 for _, _, files in os.walk(tools_dir) for _ in files)
        print(f"  [+] tools/ — {count} files (godotcpp.py present)")
    else:
        print(f"  [X] tools/godotcpp.py — MISSING (SCons builds will fail)")
        ok = False

    return ok


def main():
    parser = argparse.ArgumentParser(description="Bundle godot-cpp for user_native toolchain")
    parser.add_argument("--all", action="store_true", help="Bundle for all platforms")
    parser.add_argument("--verify", action="store_true", help="Check existing toolchain only")
    parser.add_argument("--platform", choices=["windows", "linux", "macos"],
                        help="Bundle for specific platform")
    args = parser.parse_args()

    if args.all:
        platforms = ["windows", "linux", "macos"]
    elif args.platform:
        platforms = [args.platform]
    else:
        platforms = [detect_host_platform()]

    if args.verify:
        print(f"Verifying toolchain at: {os.path.relpath(TOOLCHAIN_DST, ROOT)}")
        print("-" * 50)
        ok = verify(platforms)
        print("-" * 50)
        if ok:
            print("Toolchain ready!")
        else:
            print("Toolchain incomplete — run without --verify to bundle.")
            sys.exit(1)
        return

    # Pre-checks
    if not os.path.isdir(GODOTCPP_SRC):
        print(f"ERROR: godot-cpp not found at {os.path.relpath(GODOTCPP_SRC, ROOT)}")
        print(f"Run: python setup_deps.py --core")
        sys.exit(1)

    print(f"Bundling godot-cpp toolchain for: {', '.join(platforms)}")
    print(f"  Source:      {os.path.relpath(GODOTCPP_SRC, ROOT)}")
    print(f"  Destination: {os.path.relpath(TOOLCHAIN_DST, ROOT)}")
    print("-" * 50)

    copy_headers()
    success = copy_libs(platforms)
    copy_sconstruct()
    copy_tools()

    print("-" * 50)
    if success:
        print("Toolchain bundled successfully!")
    else:
        print("Toolchain bundled with warnings — check missing libs above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
