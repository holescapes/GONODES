"""Fill missing patches — generate exactly what's needed to bring all operators to 3 patches."""
import json, re, sys
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent))
from help_patch_engine import *

# Import the auto-generators
from generate_help_patches import (
    generate_patches_for_op, get_param_variations, make_labels
)

# ── Step 1: Count existing patches per operator using filename matching ──

reg = load_registry()

family_ops = defaultdict(list)
for op in reg:
    nt = op["node_type"]
    cn = op["class_name"]
    snt = nt.replace("_", "").lower()
    parts = re.findall(r'[A-Z][a-z]*|[A-Z]+(?=[A-Z][a-z]|\d)|[A-Z]+$|\d+', cn)
    scn = "".join(p.lower() for p in parts)
    family_ops[op["family"]].append((nt, cn, snt, scn))

for fam in family_ops:
    family_ops[fam].sort(key=lambda x: -len(x[2]))

help_roots = [d / "help" for d in Path("addons").iterdir()
              if d.is_dir() and (d / "help").exists()]


def match_file(fname, fam):
    fn_stripped = fname.replace("_", "").lower()
    for nt, cn, snt, scn in family_ops.get(fam, []):
        if fname == nt or fname.startswith(nt + "_"):
            return cn
    for nt, cn, snt, scn in family_ops.get(fam, []):
        if fn_stripped.startswith(snt):
            return cn
    for nt, cn, snt, scn in family_ops.get(fam, []):
        if fn_stripped.startswith(scn):
            return cn
    return None


counts = defaultdict(int)
existing_fnames = defaultdict(set)  # class_name -> set of filenames (stems)

for root in help_roots:
    for f in root.rglob("*.gnpatch"):
        cn = match_file(f.stem, f.parent.name)
        if cn:
            counts[cn] += 1
            existing_fnames[cn].add(f.stem)

# ── Step 2: Find operators under 3 ──

under = []
for op in reg:
    cn = op["class_name"]
    c = counts.get(cn, 0)
    if c < 3:
        under.append((op, c, 3 - c))

print(f"Operators under 3 patches: {len(under)}")
print(f"Patches needed: {sum(n for _, _, n in under)}")

# ── Step 3: Generate missing patches ──

written = 0
errors = 0
dry_run = "--dry-run" in sys.argv

for op, have, need in under:
    cn = op["class_name"]
    nt = op["node_type"]
    family = op["family"]
    help_dir = get_help_dir(op)

    patches = generate_patches_for_op(op)
    if not patches:
        print(f"  ERROR: No patches generated for {cn}")
        errors += 1
        continue

    already = existing_fnames.get(cn, set())
    added = 0

    for fname, patch_data in patches:
        if added >= need:
            break
        if fname in already:
            continue
        filepath = help_dir / f"{fname}.gnpatch"
        if filepath.exists():
            # Filename collision — add a suffix
            filepath = help_dir / f"{fname}_v2.gnpatch"
            if filepath.exists():
                filepath = help_dir / f"{fname}_v3.gnpatch"
        if not dry_run:
            write_patch(patch_data, str(filepath))
            print(f"  NEW: {filepath.relative_to(ROOT)}")
        else:
            print(f"  WOULD: {filepath.relative_to(ROOT)}")
        already.add(fname)
        added += 1
        written += 1

    if added < need:
        print(f"  WARNING: {cn} still needs {need - added} more patches (only generated {len(patches)} total)")

print(f"\nWritten: {written}, Errors: {errors}")
