#!/usr/bin/env python3
"""
sync_gdextensions.py — Activate/deactivate .gdextension files based on binary presence.

Mirrors the GDScript `GNExtensionRegistry.sync_native_extensions()` logic but
runs as a standalone CLI tool so it can be invoked after `scons` builds or in CI
— eliminating the two-restart problem.

Usage:
    python scripts/sync_gdextensions.py                   # auto-detect platform
    python scripts/sync_gdextensions.py --platform windows --arch x86_64
    python scripts/sync_gdextensions.py --dry-run          # preview only
"""

import argparse
import configparser
import os
import platform
import struct
import sys


def detect_platform() -> str:
    name = platform.system().lower()
    return {"darwin": "macos"}.get(name, name)


def detect_arch() -> str:
    machine = platform.machine().lower()
    mapping = {
        "amd64": "x86_64",
        "x86_64": "x86_64",
        "aarch64": "arm64",
        "arm64": "arm64",
    }
    return mapping.get(machine, machine)


def gdextension_has_binary(gdext_path: str, workspace_root: str,
                           plat: str, arch: str) -> bool:
    """Parse a .gdextension file and check if the library binary exists."""
    cfg = configparser.ConfigParser()
    cfg.read(gdext_path, encoding="utf-8")

    if "libraries" not in cfg:
        return False

    # Try keys from most specific to least, matching Godot's resolution order.
    # Godot uses: platform.arch.target (e.g. windows.x86_64.release)
    keys_to_try = [
        f"{plat}.{arch}.debug",
        f"{plat}.{arch}.release",
        f"{plat}.debug.{arch}",
        f"{plat}.release.{arch}",
        f"{plat}.debug",
        f"{plat}.release",
        f"{plat}.{arch}",
        plat,
    ]

    for key in keys_to_try:
        lib_path = cfg.get("libraries", key, fallback="")
        # Strip surrounding quotes that configparser may leave
        lib_path = lib_path.strip().strip('"').strip("'")
        if not lib_path:
            continue
        # Resolve res:// to absolute path
        if lib_path.startswith("res://"):
            lib_path = os.path.join(workspace_root, lib_path[len("res://"):])
        lib_path = os.path.normpath(lib_path)
        if os.path.isfile(lib_path):
            return True

    return False


def sync_dir(native_dir: str, workspace_root: str, plat: str, arch: str,
             dry_run: bool) -> list:
    """Scan a directory for .gdextension / .gdextension.disabled files."""
    changes = []
    if not os.path.isdir(native_dir):
        return changes

    for fname in os.listdir(native_dir):
        fpath = os.path.join(native_dir, fname)
        if os.path.isdir(fpath):
            continue

        is_active = fname.endswith(".gdextension")
        is_disabled = fname.endswith(".gdextension.disabled")

        if not (is_active or is_disabled):
            continue

        has_binary = gdextension_has_binary(fpath, workspace_root, plat, arch)

        if has_binary and is_disabled:
            new_name = fname.replace(".gdextension.disabled", ".gdextension")
            new_path = os.path.join(native_dir, new_name)
            if dry_run:
                changes.append(("activate", fname, new_name, "[DRY RUN]"))
            else:
                os.rename(fpath, new_path)
                changes.append(("activate", fname, new_name, "OK"))
        elif not has_binary and is_active:
            new_name = fname + ".disabled"
            new_path = os.path.join(native_dir, new_name)
            if dry_run:
                changes.append(("deactivate", fname, new_name, "[DRY RUN]"))
            else:
                os.rename(fpath, new_path)
                changes.append(("deactivate", fname, new_name, "OK"))

    return changes


def sync_all(workspace_root: str, plat: str, arch: str,
             dry_run: bool) -> list:
    """Walk all gn_ext_* extensions and sync .gdextension files."""
    addons_dir = os.path.join(workspace_root, "addons")
    all_changes = []

    if not os.path.isdir(addons_dir):
        print(f"ERROR: addons directory not found: {addons_dir}", file=sys.stderr)
        return all_changes

    for ext_name in sorted(os.listdir(addons_dir)):
        if not ext_name.startswith("gn_ext_"):
            continue
        ext_path = os.path.join(addons_dir, ext_name)
        if not os.path.isdir(ext_path):
            continue

        # Scan every immediate subdirectory (matches GDScript logic)
        for sub_name in sorted(os.listdir(ext_path)):
            sub_path = os.path.join(ext_path, sub_name)
            if os.path.isdir(sub_path):
                changes = sync_dir(sub_path, workspace_root, plat, arch, dry_run)
                for action, old, new, status in changes:
                    all_changes.append((ext_name, action, old, new, status))

    return all_changes


def main():
    parser = argparse.ArgumentParser(
        description="Sync .gdextension activation state with compiled binaries.")
    parser.add_argument("--platform", default="",
                        help="Target platform (windows/linux/macos). Auto-detected if omitted.")
    parser.add_argument("--arch", default="",
                        help="Target architecture (x86_64/arm64). Auto-detected if omitted.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview changes without applying them.")
    args = parser.parse_args()

    plat = args.platform or detect_platform()
    arch = args.arch or detect_arch()

    # Resolve workspace root (script is in scripts/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.dirname(script_dir)

    print(f"[sync_gdextensions] platform={plat}  arch={arch}  "
          f"root={workspace_root}{' (dry run)' if args.dry_run else ''}")

    changes = sync_all(workspace_root, plat, arch, args.dry_run)

    if not changes:
        print("[sync_gdextensions] All .gdextension files already in sync.")
    else:
        for ext_name, action, old, new, status in changes:
            symbol = "+" if action == "activate" else "-"
            print(f"  [{symbol}] {ext_name}: {old} -> {new}  {status}")
        print(f"\n[sync_gdextensions] {len(changes)} change(s).")
        if not args.dry_run:
            print("[sync_gdextensions] Restart Godot once to load the updated extensions.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
