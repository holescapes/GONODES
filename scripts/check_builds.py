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
import re
import subprocess
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


def _missing_status(platform: str, host_platform: str) -> str:
    """FAIL on the host platform; UNAVAIL for platforms not buildable here."""
    return "FAIL" if platform == host_platform else "UNAVAIL"


def check_extension(
    ext: dict, target_platforms: list[str], host_platform: str
) -> list[tuple[str, str, str, str]]:
    """Check an extension's build outputs. Returns list of (status, label, detail, platform)."""
    results = []
    native_dir = ext["native_dir"]

    for plat in target_platforms:
        label = f"{ext['name']} ({plat})"

        if plat not in ext["platforms"]:
            results.append(("SKIP", label, "platform not supported", plat))
            continue

        lib_ext = LIB_EXTENSIONS[plat]

        if ext["has_build_cfg"]:
            # Built by gn_build.py → output in bin/<plat>/
            bin_dir = os.path.join(native_dir, BIN_DIRS[plat])
            if not os.path.isdir(bin_dir):
                results.append(
                    (_missing_status(plat, host_platform), label, f"{BIN_DIRS[plat]}/ not found", plat)
                )
                continue

            # Look for the expected library
            found = [f for f in os.listdir(bin_dir)
                     if f.startswith(f"lib{ext['lib_name']}") and
                     "template_release" in f and f.endswith(lib_ext)]

            if found:
                sizes = ", ".join(f"{f} ({os.path.getsize(os.path.join(bin_dir, f)) // 1024}KB)"
                                  for f in found)
                results.append(("PASS", label, sizes, plat))
            else:
                all_files = os.listdir(bin_dir)
                if all_files:
                    detail = f"no release lib found (bin has: {', '.join(all_files[:5])})"
                else:
                    detail = f"{BIN_DIRS[plat]}/ is empty"
                results.append((_missing_status(plat, host_platform), label, detail, plat))
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
                results.append(("PASS", label, f"{len(found_libs)} shared lib(s)", plat))
            else:
                results.append(
                    (_missing_status(plat, host_platform), label, "no shared libraries found", plat)
                )

    return results


GDEXT_RES_RE = re.compile(r"res://[^\s'\"]+\.gdextension")


def resolve_godot_binary() -> str | None:
    """Return Godot console binary: GONODES_GODOT env, else path from dev_docs/TESTING.md."""
    env_path = os.environ.get("GONODES_GODOT", "")
    if env_path and os.path.isfile(env_path):
        return env_path

    testing_md = os.path.join(ROOT, "dev_docs", "TESTING.md")
    if not os.path.isfile(testing_md):
        return None

    with open(testing_md, encoding="utf-8") as fh:
        for line in fh:
            match = re.search(r'GONODES_GODOT\s*=\s*"([^"]+)"', line)
            if match:
                path = match.group(1)
                if os.path.isfile(path):
                    return path
    return None


def parse_gdextension_load_failures(output: str) -> list[str]:
    """Extract res:// paths of enabled .gdextension files Godot failed to load."""
    failed: set[str] = set()
    failure_markers = (
        "Error loading extension:",
        "GDExtension dynamic library not found:",
        "Can't open GDExtension dynamic library:",
        "No GDExtension library found",
        "Can't open dynamic library:",
    )

    for line in output.splitlines():
        if "ERROR:" not in line or ".gdextension.disabled" in line:
            continue
        if not any(marker in line for marker in failure_markers):
            continue
        for match in GDEXT_RES_RE.finditer(line):
            path = match.group(0)
            if not path.endswith(".gdextension.disabled"):
                failed.add(path)
    return sorted(failed)


def gdextension_to_extension_name(gdext_path: str) -> str:
    """Map res://addons/gn_ext_foo/bar.gdextension -> gn_ext_foo."""
    rel = gdext_path.removeprefix("res://")
    parts = rel.replace("\\", "/").split("/")
    if len(parts) >= 2 and parts[0] == "addons":
        return parts[1]
    return os.path.splitext(os.path.basename(rel))[0]


def run_godot_load_check() -> tuple[list[str], str | None]:
    """Launch headless Godot against this project and detect unloadable extensions."""
    godot = resolve_godot_binary()
    if not godot:
        return [], (
            "Godot binary not found (set GONODES_GODOT or update dev_docs/TESTING.md)"
        )

    cmd = [godot, "--headless", "--path", ROOT, "--quit"]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        return [], "Godot load check timed out after 180s"
    except OSError as exc:
        return [], f"Failed to launch Godot: {exc}"

    combined = (result.stdout or "") + (result.stderr or "")
    return parse_gdextension_load_failures(combined), None


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

    host_platform = detect_host_platform()
    extensions = scan_extensions()
    print(f"Found {len(extensions)} native extensions")
    print(f"Checking platforms: {', '.join(target_platforms)}")
    print(f"Host platform: {host_platform}")
    print("-" * 64)

    all_results = []
    for ext in extensions:
        results = check_extension(ext, target_platforms, host_platform)
        all_results.extend(results)

    host_results = [r for r in all_results if r[3] == host_platform]
    foreign_results = [r for r in all_results if r[3] != host_platform]

    def print_results(results: list[tuple[str, str, str, str]], heading: str | None = None) -> tuple[int, int, int, int]:
        if heading:
            print(heading)
        passes = fails = unavail = skips = 0
        icons = {"PASS": "+", "FAIL": "X", "SKIP": "-", "UNAVAIL": "~"}
        for status, label, detail, _plat in results:
            icon = icons[status]
            print(f"  [{icon}] {label}  —  {detail}")
            if status == "PASS":
                passes += 1
            elif status == "FAIL":
                fails += 1
            elif status == "UNAVAIL":
                unavail += 1
            else:
                skips += 1
        return passes, fails, unavail, skips

    h_pass, h_fail, _h_unavail, h_skip = print_results(
        host_results, f"Host platform ({host_platform})"
    )
    if foreign_results:
        print("-" * 64)
        f_pass, _f_fail, f_unavail, f_skip = print_results(
            foreign_results,
            f"Other platforms (not buildable on this host)",
        )
    else:
        f_pass = f_unavail = f_skip = 0

    passes = h_pass + f_pass
    fails = h_fail
    unavail = f_unavail
    skips = h_skip + f_skip

    print("-" * 64)
    total = len(all_results)
    print(
        f"  {passes}/{total} passed, {fails} failed on host, "
        f"{unavail} not buildable on host, {skips} skipped"
    )
    unloadable: list[str] = []
    if host_platform in target_platforms:
        print("-" * 64)
        print("Godot headless extension load check")
        load_error: str | None
        unloadable, load_error = run_godot_load_check()
        if load_error:
            print(f"  [X] {load_error}")
            fails += 1
        elif unloadable:
            for gdext_path in unloadable:
                ext_name = gdextension_to_extension_name(gdext_path)
                print(f"  [X] {ext_name}  —  failed to load ({gdext_path})")
            fails += len(unloadable)
        else:
            print("  [+] All enabled GDExtensions loaded")

    if fails:
        if unloadable:
            names = ", ".join(gdextension_to_extension_name(p) for p in unloadable)
            print(f"\n  Unloadable extensions: {names}")
        print("\n  Some extensions are missing build outputs or failed Godot load.")
        print("  Run: cd build && scons platform=<plat> target=template_release -j8")
        sys.exit(1)
    else:
        print("\n  All expected build outputs present and loadable!")


if __name__ == "__main__":
    main()
