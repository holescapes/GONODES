#!/usr/bin/env python3
"""
GONODES — Dependency Setup

Run after cloning the repository to fetch all external dependencies:
  - godot-cpp  (C++ bindings for GDExtension, required to build native operators)
  - Spout2     (Windows-only texture sharing SDK)
  - Extension-specific SDKs (ONNX Runtime, embedded CPython, etc.)

Usage:
  python setup_deps.py            # fetch everything
  python setup_deps.py --core     # godot-cpp + Spout2 only (skip extension SDKs)
  python setup_deps.py --list     # show what would be fetched, don't download
"""
import argparse
import glob
import os
import platform
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))


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

SPOUT2_REPO = "https://github.com/leadedge/Spout2.git"
SPOUT2_DIR = os.path.join(ROOT, "addons", "gn_ext_spout", "native", "Spout2")


def header(msg):
    print(f"\n{'─' * 60}")
    print(f"  {msg}")
    print(f"{'─' * 60}")


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


def find_extension_setup_scripts():
    """Discover setup_*.py scripts inside extension directories."""
    pattern = os.path.join(ROOT, "addons", "gn_ext_*", "setup_*.py")
    scripts = sorted(glob.glob(pattern))
    return scripts


def run_extension_script(script_path):
    """Run an extension's setup script with --no-enable flag."""
    ext_name = os.path.basename(os.path.dirname(script_path))
    script_name = os.path.basename(script_path)
    print(f"  Running {ext_name}/{script_name} ...")
    subprocess.run(
        [sys.executable, script_path, "--no-enable"],
        cwd=os.path.dirname(script_path),
        check=True,
    )
    print(f"  [done] {ext_name}/{script_name}")


def main():
    parser = argparse.ArgumentParser(description="GONODES dependency setup")
    parser.add_argument(
        "--core", action="store_true",
        help="Only fetch core dependencies (godot-cpp, Spout2). Skip extension SDKs.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List what would be fetched without downloading anything.",
    )
    args = parser.parse_args()

    # ── Gather tasks ───────────────────────────────────────────────────────
    tasks = []

    # Core: godot-cpp
    exists = os.path.isdir(GODOTCPP_DIR) and os.listdir(GODOTCPP_DIR)
    tasks.append({
        "name": f"godot-cpp (branch {GODOTCPP_BRANCH})",
        "target": os.path.relpath(GODOTCPP_DIR, ROOT),
        "exists": exists,
        "kind": "core",
    })

    # Core: Spout2 (Windows only, but clone on all platforms for completeness)
    is_windows = platform.system() == "Windows"
    spout_exists = os.path.isdir(SPOUT2_DIR) and os.listdir(SPOUT2_DIR)
    tasks.append({
        "name": "Spout2 SDK" + ("" if is_windows else " (Windows-only, skipped)"),
        "target": os.path.relpath(SPOUT2_DIR, ROOT),
        "exists": spout_exists,
        "kind": "core",
        "skip": not is_windows,
    })

    # Extension SDKs
    ext_scripts = find_extension_setup_scripts()
    for sp in ext_scripts:
        ext_name = os.path.basename(os.path.dirname(sp))
        script_name = os.path.basename(sp)
        tasks.append({
            "name": f"{ext_name}/{script_name}",
            "target": os.path.relpath(os.path.dirname(sp), ROOT),
            "exists": False,  # scripts are idempotent, always safe to run
            "kind": "extension",
            "script": sp,
        })

    # ── List mode ──────────────────────────────────────────────────────────
    if args.list:
        header("Dependencies")
        for t in tasks:
            status = "present" if t["exists"] else ("skip" if t.get("skip") else "needed")
            scope = "CORE" if t["kind"] == "core" else "EXT "
            print(f"  [{scope}] {t['name']:40s} -> {t['target']:50s} [{status}]")
        return

    # ── Fetch core ─────────────────────────────────────────────────────────
    header("Core dependencies")
    clone_repo("godot-cpp", GODOTCPP_REPO, GODOTCPP_DIR, branch=GODOTCPP_BRANCH)

    if is_windows:
        clone_repo("Spout2", SPOUT2_REPO, SPOUT2_DIR)
    else:
        print("  [skip] Spout2 — Windows-only dependency")

    # ── Extension SDKs ─────────────────────────────────────────────────────
    if not args.core and ext_scripts:
        header("Extension SDKs")
        for sp in ext_scripts:
            run_extension_script(sp)
    elif args.core:
        print("\n  --core flag: skipping extension SDKs")

    # ── Summary ────────────────────────────────────────────────────────────
    header("Setup complete")
    print("  You can now build extensions with:")
    print("    cd build && scons ext=<name> platform=<plat> target=template_release")
    print()


if __name__ == "__main__":
    main()
