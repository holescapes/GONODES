#!/usr/bin/env python3
"""
GONODES — Dependency Setup

Run after cloning the repository to fetch all external dependencies:
  - godot-cpp  (C++ bindings for GDExtension, required to build native operators)
  - Extension SDKs from native/build.cfg (`vendor_clone`, `setup`, or setup_*.py)

Usage:
  python setup_deps.py            # fetch everything
  python setup_deps.py --core     # godot-cpp only (skip extension SDKs)
  python setup_deps.py --list     # show what would be fetched, don't download
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(ROOT, "build")
if BUILD_DIR not in sys.path:
    sys.path.insert(0, BUILD_DIR)

from gn_ext_plan import detect_host_platform  # noqa: E402
from gn_ext_setup import configure_stdio_utf8, run_extension_setups  # noqa: E402


def _load_versions_env() -> dict:
    """Read key=value pairs from versions.env at project root."""
    env_file = os.path.join(ROOT, "versions.env")
    vals = {}
    if os.path.isfile(env_file):
        with open(env_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip()
    return vals


_VERSIONS = _load_versions_env()

GODOTCPP_BRANCH = _VERSIONS.get("GODOTCPP_BRANCH", "4.5")
GODOTCPP_REPO = "https://github.com/godotengine/godot-cpp.git"
GODOTCPP_DIR = os.path.join(ROOT, "addons", "gn_ext_native", "native", "godot-cpp")


def header(msg):
    print(f"\n{'-' * 60}")
    print(f"  {msg}")
    print(f"{'-' * 60}")


def ensure_gdignore(directory):
    """Place a .gdignore marker so Godot skips this directory."""
    marker = os.path.join(directory, ".gdignore")
    if not os.path.isfile(marker):
        os.makedirs(directory, exist_ok=True)
        open(marker, "w").close()


def clone_repo(name, repo_url, dest, branch=None):
    """Clone a git repo if the destination doesn't already exist."""
    if os.path.isdir(dest) and os.listdir(dest):
        print(f"  [skip] {name} already exists at {os.path.relpath(dest, ROOT)}")
        return False

    cmd = ["git", "clone", "--depth", "1"]
    if branch:
        cmd += ["--branch", branch]
    cmd += [repo_url, dest]

    print(f"  Cloning {name} ...")
    subprocess.run(cmd, check=True)
    ensure_gdignore(dest)
    print(f"  [done] {name}")
    return True


def main():
    configure_stdio_utf8()

    parser = argparse.ArgumentParser(description="GONODES dependency setup")
    parser.add_argument(
        "--core", action="store_true",
        help="Only fetch core dependencies (godot-cpp). Skip extension SDKs.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List what would be fetched without downloading anything.",
    )
    args = parser.parse_args()

    plat = detect_host_platform()
    godot_exists = os.path.isdir(GODOTCPP_DIR) and os.listdir(GODOTCPP_DIR)

    if args.list:
        header("Dependencies")
        status = "present" if godot_exists else "needed"
        print(
            f"  [CORE] {'godot-cpp (branch ' + GODOTCPP_BRANCH + ')':40s} "
            f"-> {os.path.relpath(GODOTCPP_DIR, ROOT):50s} [{status}]"
        )
        print()
        run_extension_setups(
            ROOT, plat,
            tier="all",
            include_optional_setups=True,
            dry_run=True,
        )
        return

    header("Core dependencies")
    clone_repo("godot-cpp", GODOTCPP_REPO, GODOTCPP_DIR, branch=GODOTCPP_BRANCH)

    if not args.core:
        header("Extension SDKs (from build.cfg)")
        run_extension_setups(
            ROOT, plat,
            tier="all",
            include_optional_setups=True,
            for_build=False,
        )
    else:
        print("\n  --core flag: skipping extension SDKs")

    header("Setup complete")
    print("  Next: run extension setups for your build tier, then compile:")
    print("    python scripts/run_extension_setups.py --for-build --tier all")
    print("    cd build && scons platform=<plat> target=template_release")
    print("  Or use scripts/build_windows.ps1 for the full Windows pipeline.")
    print()


if __name__ == "__main__":
    main()
