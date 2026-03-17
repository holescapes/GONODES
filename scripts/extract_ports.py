"""Extract add_input/add_output calls from _init_ports() in all operator .gd files."""
import os, re, sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(r"c:\MeOwn\Gonodes")

# Directories to scan
SCAN_DIRS = [
    ROOT / "addons" / "gonodes" / "operators",
    ROOT / "addons" / "gonodes" / "core",
]
# Also scan extension operators (skip gn_ext_native)
ext_root = ROOT / "addons"
for d in sorted(ext_root.iterdir()):
    if d.is_dir() and d.name.startswith("gn_ext_") and d.name != "gn_ext_native":
        ops = d / "operators"
        if ops.exists():
            SCAN_DIRS.append(ops)

def find_gd_files(scan_dirs):
    files = []
    for sd in scan_dirs:
        if not sd.exists():
            continue
        if sd.name == "core":
            # Only gn_*_base.gd in core
            for f in sd.glob("gn_*_base.gd"):
                files.append(f)
        else:
            for f in sd.rglob("*.gd"):
                files.append(f)
    return sorted(set(files))

def extract_init_ports(filepath):
    """Extract add_input/add_output lines from _init_ports() function."""
    text = filepath.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    
    in_init_ports = False
    indent = None
    port_lines = []
    
    for line in lines:
        stripped = line.strip()
        
        # Detect func _init_ports
        if re.match(r'^func\s+_init_ports\s*\(', stripped):
            in_init_ports = True
            indent = len(line) - len(line.lstrip())
            continue
        
        if in_init_ports:
            # Check if we've left the function (new func at same or lower indent, or class)
            if stripped and not stripped.startswith("#") and not stripped.startswith("@"):
                cur_indent = len(line) - len(line.lstrip())
                if cur_indent <= indent and (stripped.startswith("func ") or stripped.startswith("class ") or stripped.startswith("var ")):
                    in_init_ports = False
                    continue
            
            if "add_input(" in stripped or "add_output(" in stripped:
                port_lines.append(stripped)
    
    return port_lines

def guess_family(filepath, port_lines):
    """Guess the operator family from path or port families."""
    rel = filepath.relative_to(ROOT).as_posix()
    parts = rel.split("/")
    
    # Check path for family folder
    family_names = ["chop", "top", "sop", "dat", "comp", "mat", "output", "ui", "pop", "vol", "img"]
    for p in parts:
        if p.lower() in family_names:
            return p.lower()
    
    # Check filename
    fname = filepath.stem.lower()
    for fam in family_names:
        if fname.endswith("_" + fam):
            return fam
    
    # Check port families in the lines
    for line in port_lines:
        for fam in family_names:
            if f'"{fam}"' in line.lower() or f"'{fam}'" in line.lower():
                return fam
    
    # Check the file content for class hints
    text = filepath.read_text(encoding="utf-8", errors="replace")
    for fam in family_names:
        if f'extends GnChop' in text or f'family = "chop"' in text:
            return "chop"
        if f'extends GnTop' in text or f'family = "top"' in text:
            return "top"
        if f'extends GnSop' in text or f'family = "sop"' in text:
            return "sop"
        if f'extends GnDat' in text or f'family = "dat"' in text:
            return "dat"
        if f'extends GnComp' in text or f'family = "comp"' in text:
            return "comp"
        if f'extends GnMat' in text or f'family = "mat"' in text:
            return "mat"
        if f'extends GnOutput' in text or f'family = "output"' in text:
            return "output"
    
    return "unknown"

def main():
    files = find_gd_files(SCAN_DIRS)
    print(f"# Port Registry — {len(files)} .gd files scanned\n")
    
    by_family = defaultdict(list)
    multi_output = []
    total_with_ports = 0
    
    for f in files:
        port_lines = extract_init_ports(f)
        if not port_lines:
            continue
        
        total_with_ports += 1
        rel = f.relative_to(ROOT).as_posix()
        family = guess_family(f, port_lines)
        
        outputs = [l for l in port_lines if "add_output(" in l]
        inputs = [l for l in port_lines if "add_input(" in l]
        
        entry = {
            "path": rel,
            "inputs": inputs,
            "outputs": outputs,
            "all": port_lines,
        }
        by_family[family].append(entry)
        
        if len(outputs) >= 2:
            multi_output.append((rel, len(outputs)))
    
    # Print grouped by family
    for family in sorted(by_family.keys()):
        entries = by_family[family]
        print(f"## {family.upper()} ({len(entries)} operators)\n")
        for e in sorted(entries, key=lambda x: x["path"]):
            print(f"### {e['path']}")
            for line in e["all"]:
                print(f"  {line}")
            print()
    
    # Multi-output summary
    print(f"\n## MULTI-OUTPUT OPERATORS ({len(multi_output)})\n")
    for path, count in sorted(multi_output):
        print(f"  {path} — {count} outputs")
    
    print(f"\n## SUMMARY")
    print(f"  Total files with _init_ports(): {total_with_ports}")
    for family in sorted(by_family.keys()):
        print(f"  {family}: {len(by_family[family])}")

if __name__ == "__main__":
    main()
