#!/usr/bin/env python3
"""
clean_builds.py — Remove all compiled native extension binaries and deactivate
.gdextension files.

Used before release tagging to ensure the repository contains source only.
After a fresh clone, run the full build process (see BUILD.md) and then
`sync_gdextensions.py` to re-activate extensions.

Usage:
    python scripts/clean_builds.py              # remove binaries + deactivate
    python scripts/clean_builds.py --dry-run    # preview only
"""

import argparse
import os
import shutil
import sys


def clean_all(workspace_root: str, dry_run: bool) -> dict:
    """Remove all built native binaries and deactivate .gdextension files."""
    addons_dir = os.path.join(workspace_root, "addons")
    stats = {"binaries_removed": 0, "dirs_removed": [], "extensions_deactivated": 0}

    if not os.path.isdir(addons_dir):
        print(f"ERROR: addons directory not found: {addons_dir}", file=sys.stderr)
        return stats

    for ext_name in sorted(os.listdir(addons_dir)):
        if not ext_name.startswith("gn_ext_"):
            continue
        ext_path = os.path.join(addons_dir, ext_name)
        if not os.path.isdir(ext_path):
            continue

        # ── Remove bin/ directories inside native/ subdirectories ──
        for sub_name in sorted(os.listdir(ext_path)):
            sub_path = os.path.join(ext_path, sub_name)
            if not os.path.isdir(sub_path):
                continue

            # Remove bin/ directories (compiled output)
            bin_dir = os.path.join(sub_path, "bin")
            if os.path.isdir(bin_dir):
                file_count = sum(len(files) for _, _, files in os.walk(bin_dir))
                if dry_run:
                    print(f"  [DRY RUN] Would remove {ext_name}/{sub_name}/bin/ "
                          f"({file_count} files)")
                else:
                    shutil.rmtree(bin_dir)
                    print(f"  [-] Removed {ext_name}/{sub_name}/bin/ "
                          f"({file_count} files)")
                stats["binaries_removed"] += file_count
                stats["dirs_removed"].append(f"{ext_name}/{sub_name}/bin/")

            # Deactivate .gdextension → .gdextension.disabled
            for fname in os.listdir(sub_path):
                if fname.endswith(".gdextension") and not fname.endswith(".disabled"):
                    old_path = os.path.join(sub_path, fname)
                    new_name = fname + ".disabled"
                    new_path = os.path.join(sub_path, new_name)
                    if dry_run:
                        print(f"  [DRY RUN] Would deactivate "
                              f"{ext_name}/{sub_name}/{fname}")
                    else:
                        os.rename(old_path, new_path)
                        print(f"  [-] Deactivated {ext_name}/{sub_name}/{fname} "
                              f"→ {new_name}")
                    stats["extensions_deactivated"] += 1

    # ── Clean toolchain bundles (these are generated, not source) ──
    toolchain_dirs = [
        os.path.join(addons_dir, "gn_ext_user_native", "toolchain", "godot-cpp"),
        os.path.join(addons_dir, "gn_ext_user_python", "toolchain", "python"),
    ]
    for tc_dir in toolchain_dirs:
        if os.path.isdir(tc_dir):
            # Don't remove README.md or .gdignore — only the actual toolchain content
            contents = [f for f in os.listdir(tc_dir)
                        if f not in ("README.md", ".gdignore")]
            if contents:
                rel = os.path.relpath(tc_dir, workspace_root)
                if dry_run:
                    print(f"  [DRY RUN] Would clean toolchain: {rel}/ "
                          f"({len(contents)} items)")
                else:
                    for item in contents:
                        item_path = os.path.join(tc_dir, item)
                        if os.path.isdir(item_path):
                            shutil.rmtree(item_path)
                        else:
                            os.remove(item_path)
                    print(f"  [-] Cleaned toolchain: {rel}/ "
                          f"({len(contents)} items)")

    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Remove all compiled native extension binaries and "
                    "deactivate .gdextension files for a clean release state.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview changes without applying them.")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.dirname(script_dir)

    print(f"[clean_builds] root={workspace_root}"
          f"{' (dry run)' if args.dry_run else ''}")

    stats = clean_all(workspace_root, args.dry_run)

    print(f"\n[clean_builds] Summary: "
          f"{stats['binaries_removed']} binary files removed, "
          f"{stats['extensions_deactivated']} extensions deactivated, "
          f"{len(stats['dirs_removed'])} bin/ directories cleaned.")

    if not args.dry_run and (stats["binaries_removed"] > 0
                             or stats["extensions_deactivated"] > 0):
        print("[clean_builds] Repository is now in clean source-only state.")
        print("[clean_builds] After building, run: "
              "python scripts/sync_gdextensions.py")

    return 0


if __name__ == "__main__":
    sys.exit(main())
