#!/usr/bin/env python3
"""
GONODES — Verify Native Extension Build Outputs

Scans all extensions with native/build.cfg and checks that the expected
shared libraries exist in their bin/ directories for the current platform.

Usage:
  python scripts/check_builds.py                 # check current platform
  python scripts/check_builds.py --all           # check all platforms
  python scripts/check_builds.py --platform linux # check specific platform
"""
import argparse
import configparser
import glob
import os
import platform as _platform
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PLATFORMS = ["windows", "linux", "macos"]

BIN_DIRS = {
    "windows": "bin/win64",
    "linux": "bin/linux64",
    "macos": "bin/macos",
}

LIB_EXTENSIONS = {
    "windows": ".dll",
    "linux": ".so",
    "macos": ".dylib",
}

# Extensions that have prebuilt binaries without build.cfg (e.g., FFmpeg)
# Map: ext_name -> {platform: [glob patterns relative to native/]}
PREBUILT_EXTENSIONS = {}


def detect_host_platform() -> str:
    if sys.platform == "win32":
        return "windows"
    elif sys.platform == "darwin":
        return "macos"
    return "linux"


def scan_extensions() -> list[dict]:
    """Discover all native extensions and their expected outputs."""
    extensions = []

    # Extensions with build.cfg
    for cfg_path in sorted(glob.glob(os.path.join(ROOT, "addons", "gn_ext_*", "native", "build.cfg"))):
        native_dir = os.path.dirname(cfg_path)
        ext_dir = os.path.dirname(native_dir)
        ext_name = os.path.basename(ext_dir)

        cp = configparser.ConfigParser(interpolation=None)
        cp.read(cfg_path, encoding="utf-8")

        lib_name = cp.get("library", "name", fallback=ext_name)
        platforms_str = cp.get("library", "platforms", fallback="windows, linux, macos")
        supported_platforms = [p.strip() for p in platforms_str.split(",")]

        extensions.append({
            "name": ext_name,
            "lib_name": lib_name,
            "native_dir": native_dir,
            "platforms": supported_platforms,
            "has_build_cfg": True,
        })

    # Extensions with prebuilt shared libs (no build.cfg)
    for native_dir in sorted(glob.glob(os.path.join(ROOT, "addons", "gn_ext_*", "native"))):
        cfg_path = os.path.join(native_dir, "build.cfg")
        if os.path.isfile(cfg_path):
            continue  # Already handled above

        ext_dir = os.path.dirname(native_dir)
        ext_name = os.path.basename(ext_dir)

        # Check if it has any platform bin directories
        supported = []
        for plat, bin_dir in BIN_DIRS.items():
            if os.path.isdir(os.path.join(native_dir, bin_dir)):
                supported.append(plat)
        # Also check direct platform dirs (e.g., win64/, linux64/)
        plat_map = {"win64": "windows", "linux64": "linux", "macos": "macos"}
        for dirname, plat in plat_map.items():
            full = os.path.join(native_dir, dirname)
            if os.path.isdir(full) and plat not in supported:
                supported.append(plat)

        if not supported:
            continue

        # Try to get lib name from .gdextension file
        gdext_files = glob.glob(os.path.join(native_dir, "*.gdextension"))
        lib_name = ext_name
        if gdext_files:
            lib_name = os.path.splitext(os.path.basename(gdext_files[0]))[0]

        extensions.append({
            "name": ext_name,
            "lib_name": lib_name,
            "native_dir": native_dir,
            "platforms": supported,
            "has_build_cfg": False,
        })

    return extensions


def check_extension(ext: dict, target_platforms: list[str]) -> list[tuple[str, str, str]]:
    """Check an extension's build outputs. Returns list of (status, label, detail)."""
    results = []
    native_dir = ext["native_dir"]

    for plat in target_platforms:
        label = f"{ext['name']} ({plat})"

        if plat not in ext["platforms"]:
            results.append(("SKIP", label, "platform not supported"))
            continue

        lib_ext = LIB_EXTENSIONS[plat]

        if ext["has_build_cfg"]:
            # Built by gn_build.py → output in bin/<plat>/
            bin_dir = os.path.join(native_dir, BIN_DIRS[plat])
            if not os.path.isdir(bin_dir):
                results.append(("FAIL", label, f"{BIN_DIRS[plat]}/ not found"))
                continue

            # Look for the expected library
            expected_pattern = f"lib{ext['lib_name']}.*.template_release.*{lib_ext}"
            found = [f for f in os.listdir(bin_dir)
                     if f.startswith(f"lib{ext['lib_name']}") and
                     "template_release" in f and f.endswith(lib_ext)]

            if found:
                sizes = ", ".join(f"{f} ({os.path.getsize(os.path.join(bin_dir, f)) // 1024}KB)"
                                  for f in found)
                results.append(("PASS", label, sizes))
            else:
                all_files = os.listdir(bin_dir)
                if all_files:
                    results.append(("FAIL", label, f"no release lib found (bin has: {', '.join(all_files[:5])})"))
                else:
                    results.append(("FAIL", label, f"{BIN_DIRS[plat]}/ is empty"))
        else:
            # Prebuilt shared libs — check platform dirs
            plat_dirs = {
                "windows": ["bin/win64", "win64"],
                "linux": ["bin/linux64", "linux64"],
                "macos": ["bin/macos", "macos"],
            }
            found_libs = []
            for pd in plat_dirs.get(plat, []):
                full_dir = os.path.join(native_dir, pd)
                if os.path.isdir(full_dir):
                    libs = [f for f in os.listdir(full_dir) if f.endswith(lib_ext)]
                    found_libs.extend(libs)

            if found_libs:
                results.append(("PASS", label, f"{len(found_libs)} shared lib(s)"))
            else:
                results.append(("FAIL", label, "no shared libraries found"))

    return results


def main():
    parser = argparse.ArgumentParser(description="Verify GONODES native extension build outputs")
    parser.add_argument("--all", action="store_true", help="Check all platforms")
    parser.add_argument("--platform", choices=PLATFORMS, help="Check a specific platform")
    args = parser.parse_args()

    if args.all:
        target_platforms = PLATFORMS
    elif args.platform:
        target_platforms = [args.platform]
    else:
        target_platforms = [detect_host_platform()]

    extensions = scan_extensions()
    print(f"Found {len(extensions)} native extensions")
    print(f"Checking platforms: {', '.join(target_platforms)}")
    print("-" * 64)

    all_results = []
    for ext in extensions:
        results = check_extension(ext, target_platforms)
        all_results.extend(results)

    passes = 0
    fails = 0
    skips = 0
    for status, label, detail in all_results:
        icon = {"PASS": "+", "FAIL": "X", "SKIP": "-"}[status]
        print(f"  [{icon}] {label}  —  {detail}")
        if status == "PASS":
            passes += 1
        elif status == "FAIL":
            fails += 1
        else:
            skips += 1

    print("-" * 64)
    total = len(all_results)
    print(f"  {passes}/{total} passed, {fails} failed, {skips} skipped")

    if fails:
        print("\n  Some extensions are missing build outputs.")
        print("  Run: cd build && scons platform=<plat> target=template_release -j8")
        sys.exit(1)
    else:
        print("\n  All expected build outputs present!")


if __name__ == "__main__":
    main()
