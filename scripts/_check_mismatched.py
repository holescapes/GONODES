"""Quick check for patches where the expected operator (from filename) is missing from the nodes."""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HELP_DIR = ROOT / "addons" / "gonodes" / "help"
REG_PATH = ROOT / "scripts" / "operator_registry.json"

# Build (node_type, family) -> class_name lookup
nt_fam_to_class = {}
if REG_PATH.exists():
    data = json.load(open(REG_PATH))
    for e in data:
        nt_fam_to_class[(e["node_type"], e["family"])] = e["class_name"]

mismatches = []
family_filter = sys.argv[1] if len(sys.argv) > 1 else None

for fdir in sorted(HELP_DIR.iterdir()):
    if not fdir.is_dir():
        continue
    if family_filter and fdir.name != family_filter:
        continue
    for pf in sorted(fdir.glob("*.gnpatch")):
        stem = pf.stem
        family = fdir.name
        # Strip variant
        for sfx in ("_basic", "_advanced"):
            if stem.endswith(sfx):
                stem = stem[:-len(sfx)]
                break
        else:
            parts = stem.rsplit("_", 1)
            if len(parts) > 1:
                stem = parts[0]

        key = (stem, family)
        if key not in nt_fam_to_class:
            continue  # can't verify

        expected = nt_fam_to_class[key]
        try:
            patch = json.load(open(pf))
        except Exception:
            continue
        types_in_patch = {nd.get("type") for nd in patch.get("nodes", {}).values()}
        if expected not in types_in_patch:
            mismatches.append((fdir.name, pf.name, expected, types_in_patch))

print(f"Found {len(mismatches)} mismatched patches:")
for fam, fname, expected, actual in mismatches:
    print(f"  {fam}/{fname}: expected {expected}, has {sorted(actual)}")
