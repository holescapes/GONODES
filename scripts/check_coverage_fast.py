"""Fast coverage check — filename-based matching with underscore tolerance."""
import json, re
from pathlib import Path
from collections import defaultdict

reg = json.load(open("scripts/operator_registry.json"))

# Build family -> list of (node_type, class_name, stripped_nt, stripped_cn)
family_ops = defaultdict(list)
for op in reg:
    nt = op["node_type"]
    cn = op["class_name"]
    stripped_nt = nt.replace("_", "").lower()
    parts = re.findall(r'[A-Z][a-z]*|[A-Z]+(?=[A-Z][a-z]|\d)|[A-Z]+$|\d+', cn)
    stripped_cn = "".join(p.lower() for p in parts)
    family_ops[op["family"]].append((nt, cn, stripped_nt, stripped_cn))

# Sort by stripped_nt length descending for longest-match-first
for fam in family_ops:
    family_ops[fam].sort(key=lambda x: -len(x[2]))

# All help directories
help_roots = []
for d in Path("addons").iterdir():
    if d.is_dir():
        hp = d / "help"
        if hp.exists():
            help_roots.append(hp)

counts = defaultdict(int)
unmatched = []

def match_file(fname, fam):
    fn_stripped = fname.replace("_", "").lower()
    candidates = family_ops.get(fam, [])
    
    # Pass 1: exact prefix match on original node_type
    for nt, cn, snt, scn in candidates:
        if fname == nt or fname.startswith(nt + "_"):
            return cn
    
    # Pass 2: stripped prefix match (underscore-insensitive)
    for nt, cn, snt, scn in candidates:
        if fn_stripped.startswith(snt):
            return cn
    
    # Pass 3: class_name-derived stripped match
    for nt, cn, snt, scn in candidates:
        if fn_stripped.startswith(scn):
            return cn
    
    return None

for root in help_roots:
    for f in root.rglob("*.gnpatch"):
        fname = f.stem
        fam = f.parent.name
        cn = match_file(fname, fam)
        if cn:
            counts[cn] += 1
        else:
            unmatched.append((fam, fname))

# Operators with 0 patches
all_cns = {op["class_name"] for op in reg}
zero = all_cns - set(counts.keys())

under = [(cn, c) for cn, c in counts.items() if c < 3]
under.extend([(cn, 0) for cn in zero])
exact = [(cn, c) for cn, c in counts.items() if c == 3]
over = [(cn, c) for cn, c in counts.items() if c > 3]

print(f"Under 3: {len(under)}")
for cn, c in sorted(under):
    print(f"  {c} | {cn}")
print(f"\nExact 3: {len(exact)}")
print(f"Over 3: {len(over)}")
for cn, c in sorted(over, key=lambda x: -x[1])[:10]:
    print(f"  {c} | {cn}")
total_files = sum(1 for root in help_roots for _ in root.rglob("*.gnpatch"))
print(f"\nTotal .gnpatch: {total_files}, Matched: {total_files - len(unmatched)}, Unmatched: {len(unmatched)}")
if unmatched:
    print("Unmatched:")
    for fam, fn in sorted(unmatched):
        print(f"  {fam}/{fn}")
