"""Scan all core GONODES operators and extract metadata: class_name, node_type, ports, parameters."""
import os
import re
import json
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
_ROOT = _SCRIPT_DIR.parent
OPS_DIR = _ROOT / "addons" / "gonodes" / "operators"

FAMILIES = ["chop", "comp", "dat", "img", "mat", "output", "pop", "sop", "top", "ui", "vol"]

# Also include root-level .gd files (dot_node.gd etc.)
def collect_gd_files():
    files = []
    for f in OPS_DIR.glob("*.gd"):
        files.append(("root", f))
    for fam in FAMILIES:
        d = OPS_DIR / fam
        if d.is_dir():
            for f in sorted(d.glob("*.gd")):
                files.append((fam, f))
    return files

def parse_operator(family, filepath):
    text = filepath.read_text(encoding="utf-8", errors="replace")
    
    # class_name
    m = re.search(r'^class_name\s+(\w+)', text, re.MULTILINE)
    class_name = m.group(1) if m else "UNKNOWN"
    
    # node_type
    m = re.search(r'node_type\s*=\s*"([^"]*)"', text)
    node_type = m.group(1) if m else "UNKNOWN"
    
    # Inputs: add_input("name", GNFamily.Type.XXX, ...)
    inputs = []
    for m in re.finditer(r'add_input\(\s*"([^"]*)"[^,]*,\s*GNFamily\.Type\.(\w+)', text):
        inputs.append({"name": m.group(1), "family": m.group(2)})
    
    # Outputs: add_output("name", GNFamily.Type.XXX, ...)
    outputs = []
    for m in re.finditer(r'add_output\(\s*"([^"]*)"[^,]*,\s*GNFamily\.Type\.(\w+)', text):
        outputs.append({"name": m.group(1), "family": m.group(2)})
    
    # Parameters: add_parameter(GNParameter.create_TYPE("name", ...))
    params = []
    for m in re.finditer(r'add_parameter\(\s*GNParameter\.create_(\w+)\(\s*"([^"]*)"', text):
        params.append({"type": m.group(1), "name": m.group(2)})
    
    # Also detect dynamic param patterns (loop-generated params)
    # Look for patterns like: for r in range(4): ... create_string("r%dc%d" ...
    
    return {
        "file": filepath.name,
        "dir": family,
        "class_name": class_name,
        "node_type": node_type,
        "inputs": inputs,
        "outputs": outputs,
        "params": params,
    }

def main():
    files = collect_gd_files()
    all_ops = {}
    for fam in ["root"] + FAMILIES:
        all_ops[fam] = []
    
    for family, fp in files:
        op = parse_operator(family, fp)
        all_ops[family].append(op)
    
    # Print counts
    for fam in ["root"] + FAMILIES:
        print(f"\n{'='*60}")
        print(f"  {fam.upper()} — {len(all_ops[fam])} operators")
        print(f"{'='*60}")
        for op in sorted(all_ops[fam], key=lambda x: x["class_name"]):
            in_str = ", ".join(f"{i['name']}:{i['family']}" for i in op["inputs"]) if op["inputs"] else "(none)"
            out_str = ", ".join(f"{o['name']}:{o['family']}" for o in op["outputs"]) if op["outputs"] else "(none — sink)"
            param_names = [p["name"] for p in op["params"]]
            print(f"\n  {op['class_name']}")
            print(f"    node_type: \"{op['node_type']}\"")
            print(f"    inputs:  [{in_str}]")
            print(f"    outputs: [{out_str}]")
            print(f"    params:  {param_names}")
    
    # Cross-family analysis
    print(f"\n\n{'='*60}")
    print(f"  CROSS-FAMILY OUTPUT OPERATORS")
    print(f"{'='*60}")
    
    family_map = {
        "chop": "CHOP", "comp": "COMP", "dat": "DAT", "img": "IMG",
        "mat": "MAT", "output": None, "pop": "POP", "sop": "SOP",
        "top": "TOP", "ui": None, "vol": "VOL", "root": None,
    }
    
    for fam in FAMILIES:
        expected = family_map.get(fam)
        if expected is None:
            continue
        for op in all_ops[fam]:
            for o in op["outputs"]:
                if o["family"] != expected:
                    print(f"  {op['class_name']} (dir={fam}) outputs {o['family']} (expected {expected})")
    
    # Also check inputs that cross families
    print(f"\n{'='*60}")
    print(f"  CROSS-FAMILY INPUT OPERATORS (inputs from different family)")
    print(f"{'='*60}")
    for fam in FAMILIES:
        expected = family_map.get(fam)
        if expected is None:
            continue
        for op in all_ops[fam]:
            cross = [i for i in op["inputs"] if i["family"] != expected]
            if cross:
                cross_str = ", ".join(f"{i['name']}:{i['family']}" for i in cross)
                print(f"  {op['class_name']} (dir={fam}) has cross-family inputs: {cross_str}")


if __name__ == "__main__":
    main()
