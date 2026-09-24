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
import sys


def _is_ignored_lock_file(name: str) -> bool:
    """Skip Windows lock/temp artifacts next to DLLs (see build_templates.ps1)."""
    return name.startswith("~")


def _remove_file(path: str, dry_run: bool) -> bool:
    """Remove one file. Returns True on success; False on PermissionError."""
    if dry_run:
        return True
    try:
        os.remove(path)
        return True
    except PermissionError:
        print(f"  [WARN] Could not remove (may be locked): {path}", file=sys.stderr)
        return False


def _remove_tree(dir_path: str, dry_run: bool) -> tuple[int, bool]:
    """Remove a directory tree, skipping ~ lock files. Returns (file_count, ok)."""
    if not os.path.isdir(dir_path):
        return 0, True

    file_count = 0
    ok = True
    for root, dirs, files in os.walk(dir_path, topdown=False):
        for fname in files:
            if _is_ignored_lock_file(fname):
                continue
            fpath = os.path.join(root, fname)
            file_count += 1
            if not _remove_file(fpath, dry_run):
                ok = False

        for dname in dirs:
            dpath = os.path.join(root, dname)
            if dry_run:
                continue
            try:
                os.rmdir(dpath)
            except OSError:
                pass

    if not dry_run:
        try:
            os.rmdir(dir_path)
        except OSError:
            pass

    return file_count, ok


def _deactivate_gdextension(old_path: str, new_path: str, label: str,
                            dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would deactivate {label}")
        return
    if os.path.isfile(new_path):
        os.remove(old_path)
    else:
        os.rename(old_path, new_path)
    print(f"  [-] Deactivated {label} -> {os.path.basename(new_path)}")


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

        pending_deactivations: list[tuple[str, str, str]] = []
        clean_ok = True

        for fname in os.listdir(ext_path):
            if fname.endswith(".gdextension") and not fname.endswith(".disabled"):
                old_path = os.path.join(ext_path, fname)
                new_path = os.path.join(ext_path, fname + ".disabled")
                pending_deactivations.append(
                    (old_path, new_path, f"{ext_name}/{fname}"))

        # ── Remove extension-root bin/ and runtime/ (build outputs) ──
        for root_out in ("bin", "runtime"):
            out_dir = os.path.join(ext_path, root_out)
            if os.path.isdir(out_dir):
                file_count, removed_ok = _remove_tree(out_dir, dry_run)
                clean_ok = clean_ok and removed_ok
                if dry_run:
                    print(f"  [DRY RUN] Would remove {ext_name}/{root_out}/ "
                          f"({file_count} files)")
                else:
                    print(f"  [-] Removed {ext_name}/{root_out}/ ({file_count} files)")
                stats["binaries_removed"] += file_count
                stats["dirs_removed"].append(f"{ext_name}/{root_out}/")

        # ── Walk native/ subdirectories ──
        for sub_name in sorted(os.listdir(ext_path)):
            sub_path = os.path.join(ext_path, sub_name)
            if not os.path.isdir(sub_path):
                continue

            # Remove bin/ directories (compiled output)
            bin_dir = os.path.join(sub_path, "bin")
            if os.path.isdir(bin_dir):
                file_count, removed_ok = _remove_tree(bin_dir, dry_run)
                clean_ok = clean_ok and removed_ok
                if dry_run:
                    print(f"  [DRY RUN] Would remove {ext_name}/{sub_name}/bin/ "
                          f"({file_count} files)")
                else:
                    print(f"  [-] Removed {ext_name}/{sub_name}/bin/ "
                          f"({file_count} files)")
                stats["binaries_removed"] += file_count
                stats["dirs_removed"].append(f"{ext_name}/{sub_name}/bin/")

            for fname in os.listdir(sub_path):
                if fname.endswith(".gdextension") and not fname.endswith(".disabled"):
                    old_path = os.path.join(sub_path, fname)
                    new_path = os.path.join(sub_path, fname + ".disabled")
                    pending_deactivations.append(
                        (old_path, new_path, f"{ext_name}/{sub_name}/{fname}"))

        if clean_ok or dry_run:
            for old_path, new_path, label in pending_deactivations:
                _deactivate_gdextension(old_path, new_path, label, dry_run)
                stats["extensions_deactivated"] += 1
        elif pending_deactivations:
            print(f"  [WARN] Skipped deactivating {ext_name} "
                  f"({len(pending_deactivations)} .gdextension file(s)) "
                  f"because binary cleanup failed", file=sys.stderr)

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
                            _remove_tree(item_path, dry_run=False)
                        else:
                            _remove_file(item_path, dry_run=False)
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
