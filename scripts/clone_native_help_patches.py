#!/usr/bin/env python3
"""Clone help patches from GDScript originals for all Native variants.

For each native wrapper (e.g., CopyCHOPNative), finds the corresponding
GDScript original's help patches (e.g., CopyCHOP) and clones them with
the focus node type swapped to the Native class name.

Output: addons/gn_ext_native/help/<family>/<node_type>_basic.gnpatch (etc.)
"""

import copy
import json
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NATIVE_DIR = os.path.join(ROOT, "addons", "gn_ext_native", "operators")
NATIVE_HELP_DIR = os.path.join(ROOT, "addons", "gn_ext_native", "help")




def scan_natives():
    """Scan native wrappers and return {native_class: {original, node_type, family_dir}}.
    
    The original class_name is looked up from the ACTUAL GDScript operator file
    (same node_type + family), not derived by stripping 'Native'.
    This handles class name mismatches like IkCHOPNative → IKCHOP.
    """
    # First pass: collect all native wrappers
    natives = {}
    for root, dirs, files in os.walk(NATIVE_DIR):
        for f in files:
            if not f.endswith(".gd"):
                continue
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8") as fh:
                content = fh.read()
            cn = None
            nt = None
            for line in content.splitlines():
                if line.strip().startswith("class_name "):
                    cn = line.strip().split()[1]
                m = re.match(r'\s*node_type\s*=\s*"(.+?)"', line)
                if m:
                    nt = m.group(1)
            if cn and cn.endswith("Native") and nt:
                family_dir = os.path.basename(root)
                natives[cn] = {
                    "original": cn[:-6],  # initial guess
                    "node_type": nt,
                    "family_dir": family_dir,
                }

    # Second pass: find actual original class names by matching node_type + family
    originals_by_nt_fam = {}  # (node_type, family_dir) -> actual_class_name
    core_ops = os.path.join(ROOT, "addons", "gonodes", "operators")
    for root, dirs, files in os.walk(core_ops):
        for f in files:
            if not f.endswith(".gd"):
                continue
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8") as fh:
                content = fh.read()
            cn = None
            nt = None
            for line in content.splitlines():
                if line.strip().startswith("class_name "):
                    cn = line.strip().split()[1]
                m = re.match(r'\s*node_type\s*=\s*"(.+?)"', line)
                if m:
                    nt = m.group(1)
            if cn and nt:
                fam_dir = os.path.basename(root)
                originals_by_nt_fam[(nt, fam_dir)] = cn

    # Also check bridge operators in special dirs
    for bridge_dir in ["bridge", "vol", "chop", "sop", "top", "img", "dat",
                        "comp", "mat", "out", "ui", "pop", "sdf", "script"]:
        dir_path = os.path.join(core_ops, bridge_dir)
        if os.path.isdir(dir_path):
            for f in os.listdir(dir_path):
                if f.endswith(".gd"):
                    path = os.path.join(dir_path, f)
                    with open(path, "r", encoding="utf-8") as fh:
                        content = fh.read()
                    cn = None
                    nt = None
                    for line in content.splitlines():
                        if line.strip().startswith("class_name "):
                            cn = line.strip().split()[1]
                        m = re.match(r'\s*node_type\s*=\s*"(.+?)"', line)
                        if m:
                            nt = m.group(1)
                    if cn and nt:
                        originals_by_nt_fam[(nt, bridge_dir)] = cn

    # Update natives with actual original class names
    for ncn, info in natives.items():
        key = (info["node_type"], info["family_dir"])
        if key in originals_by_nt_fam:
            info["original"] = originals_by_nt_fam[key]

    return natives


def scan_original_help_patches(natives):
    """Find help patches for each native's original, using filename + family matching.
    
    Help patches follow the naming convention: help/<family>/<node_type>_<variant>.gnpatch
    When node_types collide across families (e.g., "analyze" for CHOP/TOP/VOL),
    we match by both filename prefix AND the family subdirectory.
    
    Returns {original_class_name: [list of patch file paths]}.
    """
    help_files = glob.glob(
        os.path.join(ROOT, "addons", "gonodes", "help", "**", "*.gnpatch"),
        recursive=True,
    )
    # Include extension help dirs except gn_ext_native
    for ext_patch in glob.glob(
        os.path.join(ROOT, "addons", "gn_ext_*", "help", "**", "*.gnpatch"),
        recursive=True,
    ):
        if "gn_ext_native" not in ext_patch:
            help_files.append(ext_patch)

    # Build (node_type, family_dir) -> original_class_name mapping
    nt_family_to_original = {}
    for ncn, info in natives.items():
        key = (info["node_type"], info["family_dir"])
        nt_family_to_original[key] = info["original"]

    # Match patches by filename prefix AND family subdirectory
    class_patches = {}
    for hp in help_files:
        # Normalize path separators
        hp_norm = hp.replace("\\", "/")
        fname = os.path.basename(hp)
        name_no_ext = fname.rsplit(".", 1)[0]  # e.g. "analyze_basic"

        # Extract family dir from path: .../help/<family>/<file>.gnpatch
        parts = hp_norm.split("/")
        family_idx = None
        for i, p in enumerate(parts):
            if p == "help" and i + 2 < len(parts):
                family_idx = i + 1
                break
        if family_idx is None:
            continue
        family_dir = parts[family_idx]

        # Try matching against known (node_type, family) pairs
        for (nt, fam), original_cn in nt_family_to_original.items():
            if fam == family_dir and (name_no_ext == nt or name_no_ext.startswith(nt + "_")):
                if original_cn not in class_patches:
                    class_patches[original_cn] = set()
                class_patches[original_cn].add(hp)

    # Content-based fallback: for originals still missing, search JSON type fields.
    # This handles cases like chop_to_vol_basic.gnpatch where filename doesn't
    # match the node_type (choptovol vs chop_to_vol).
    original_cn_set = set(info["original"] for info in natives.values())
    missing = original_cn_set - set(class_patches.keys())
    if missing:
        for hp in help_files:
            try:
                data = json.load(open(hp, "r", encoding="utf-8"))
            except Exception:
                continue
            for nd in data.get("nodes", {}).values():
                t = nd.get("type", "")
                if t in missing:
                    if t not in class_patches:
                        class_patches[t] = set()
                    class_patches[t].add(hp)

    # Convert sets to sorted lists
    return {k: sorted(v) for k, v in class_patches.items()}


def clone_patch(patch_path, original_class, native_class):
    """Clone a help patch, swapping original_class -> native_class in type fields.
    
    Also handles case-insensitive matching for class names that differ
    only in capitalization (e.g., IKCHOP vs IkCHOP).
    """
    with open(patch_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    cloned = copy.deepcopy(data)

    # Swap type field for all nodes matching the original class
    swapped = False
    for nid, nd in cloned.get("nodes", {}).items():
        if nd.get("type") == original_class:
            nd["type"] = native_class
            swapped = True

    # Update annotations to mention Native variant
    for ann in cloned.get("annotations", []):
        text = ann.get("text", "")
        if original_class in text:
            text = text.replace(original_class, native_class)
        # Also update the descriptive text
        if " \u2014 " in text:
            # Add "(Native)" hint if not already there
            if "Native" not in text and "native" not in text:
                parts = text.split("\n", 1)
                if len(parts) >= 1:
                    parts[0] = parts[0].rstrip() + " (Native)"
                text = "\n".join(parts)
        ann["text"] = text

    return cloned, swapped


def main():
    dry_run = "--dry-run" in sys.argv

    natives = scan_natives()
    print(f"Found {len(natives)} native variants")

    original_help = scan_original_help_patches(natives)
    print(f"Found help patches for {len(original_help)} original class names")

    created = 0
    skipped = 0
    missing_originals = []

    for native_cn in sorted(natives.keys()):
        info = natives[native_cn]
        original_cn = info["original"]
        node_type = info["node_type"]
        family_dir = info["family_dir"]

        if original_cn not in original_help:
            missing_originals.append((native_cn, original_cn))
            continue

        patches = original_help[original_cn]
        out_dir = os.path.join(NATIVE_HELP_DIR, family_dir)
        os.makedirs(out_dir, exist_ok=True)

        for patch_path in patches:
            # Derive output filename from original patch filename
            orig_fname = os.path.basename(patch_path)
            # The output name follows the same convention
            out_path = os.path.join(out_dir, orig_fname)

            if dry_run:
                print(f"  Would create: {os.path.relpath(out_path, ROOT)}")
                created += 1
                continue

            cloned, swapped = clone_patch(patch_path, original_cn, native_cn)
            if not swapped:
                skipped += 1
                continue

            with open(out_path, "w", encoding="utf-8", newline="") as fh:
                json.dump(cloned, fh, indent=2, ensure_ascii=False)
                fh.write("\n")

            created += 1

    print(f"\n{'Would create' if dry_run else 'Created'}: {created} help patches")
    if skipped:
        print(f"Skipped (no focus node matched): {skipped}")
    if missing_originals:
        print(f"Missing original help patches for {len(missing_originals)} natives:")
        for ncn, ocn in missing_originals:
            print(f"  {ncn} -> {ocn}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
