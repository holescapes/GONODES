"""Check which operators have fewer than 3 patches."""
import json
import sys
sys.path.insert(0, '.')
from pathlib import Path

# Use the improved matching from engine
sys.path.insert(0, 'scripts')
from help_patch_engine import find_existing_patches, load_registry

registry = load_registry()
under = []
over = []
exact = []
for op in registry:
    patches = find_existing_patches(op)
    count = len(patches)
    if count < 3:
        under.append((op['class_name'], op['family'], count, op['node_type']))
    elif count == 3:
        exact.append((op['class_name'], op['family'], count))
    else:
        over.append((op['class_name'], op['family'], count))

print(f"Under 3: {len(under)}")
for cn, fam, cnt, nt in sorted(under, key=lambda x: (x[1], x[0])):
    print(f"  {cnt} | {fam:6s} {cn:30s} (node_type: {nt})")

print(f"\nExact 3: {len(exact)}")
print(f"Over 3: {len(over)}")
for cn, fam, cnt in sorted(over, key=lambda x: -x[2])[:10]:
    print(f"  {cnt} | {fam:6s} {cn}")
