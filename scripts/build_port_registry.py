#!/usr/bin/env python3
"""Scan every operator .gd file and extract input/output port types.

Produces a Python dict:  class_name -> { family, inputs, outputs, dynamic_inputs }

Patterns matched:
  class_name XXX
  family = GNFamily.Type.XXX
  add_input("name", GNFamily.Type.XXX, ...)
  add_output("name", GNFamily.Type.XXX, ...)
  _enable_dynamic_inputs(GNFamily.Type.XXX, ...)

Also applies inherited base-class ports when an operator does NOT override
_init_ports() (i.e. inherits the default from its base).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directories that contain operator .gd files
OPERATOR_DIRS = [
    ROOT / "addons" / "gonodes" / "operators",
]
# Also scan all gn_ext_* extension operator dirs
for ext_dir in sorted((ROOT / "addons").glob("gn_ext_*")):
    ops = ext_dir / "operators"
    if ops.is_dir():
        OPERATOR_DIRS.append(ops)

RE_CLASS_NAME = re.compile(r'^class_name\s+(\w+)', re.MULTILINE)
RE_FAMILY = re.compile(r'family\s*=\s*GNFamily\.Type\.(\w+)')
RE_ADD_INPUT = re.compile(
    r'add_input\(\s*"([^"]+)"\s*,\s*GNFamily\.Type\.(\w+)')
RE_ADD_OUTPUT = re.compile(
    r'add_output\(\s*"([^"]+)"\s*,\s*GNFamily\.Type\.(\w+)')
RE_DYNAMIC_INPUTS = re.compile(
    r'_enable_dynamic_inputs\(\s*GNFamily\.Type\.(\w+)')
RE_INIT_PORTS = re.compile(r'^func _init_ports\b', re.MULTILINE)

# Map base-class extends → default output port(s) when _init_ports is NOT overridden
BASE_MAP = {
    "GNTopBase":  ("TOP",  [{"port": 0, "name": "out", "type": "TOP"}]),
    "GNChopBase": ("CHOP", [{"port": 0, "name": "out", "type": "CHOP"}]),
    "GNSopBase":  ("SOP",  [{"port": 0, "name": "out", "type": "SOP"}]),
    "GNDatBase":  ("DAT",  [{"port": 0, "name": "out", "type": "DAT"}]),
    "GNCompBase": ("COMP", [{"port": 0, "name": "out", "type": "COMP"}]),
    "GNMatBase":  ("MAT",  [{"port": 0, "name": "out", "type": "MAT"}]),
    "GNImgBase":  ("IMG",  [{"port": 0, "name": "out", "type": "IMG"}]),
    "GNVolBase":  ("VOL",  [{"port": 0, "name": "out", "type": "VOL"}]),
    "GNPopBase":  ("POP",  [{"port": 0, "name": "out", "type": "POP"}]),
    "GNOutBase":  ("OUT",  []),  # Sinks have no default output
    "GNUiBase":   ("UI",   [{"port": 0, "name": "out", "type": "UI"}]),
    # GNUiBase also adds "state" CHOP in initialize(), handled specially below
}


def scan_file(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8", errors="replace")

    m = RE_CLASS_NAME.search(text)
    if not m:
        return None
    class_name = m.group(1)

    # Family from explicit assignment or inferred from base class
    family_match = RE_FAMILY.search(text)
    family = family_match.group(1) if family_match else None

    # Get the extends base class
    extends_match = re.search(r'^extends\s+(\w+)', text, re.MULTILINE)
    base_class = extends_match.group(1) if extends_match else None

    # If no explicit family, infer from base class
    if family is None and base_class in BASE_MAP:
        family = BASE_MAP[base_class][0]

    # Check if the operator overrides _init_ports
    has_init_ports = RE_INIT_PORTS.search(text) is not None

    inputs = []
    for idx, m_in in enumerate(RE_ADD_INPUT.finditer(text)):
        inputs.append({
            "port": idx,
            "name": m_in.group(1),
            "type": m_in.group(2),
        })

    outputs = []
    for idx, m_out in enumerate(RE_ADD_OUTPUT.finditer(text)):
        outputs.append({
            "port": idx,
            "name": m_out.group(1),
            "type": m_out.group(2),
        })

    dynamic_inputs = None
    dyn_m = RE_DYNAMIC_INPUTS.search(text)
    if dyn_m:
        dynamic_inputs = dyn_m.group(1)

    # If operator has NO _init_ports override AND no explicit ports found,
    # apply inherited base-class default ports
    if not has_init_ports and not inputs and not outputs and not dynamic_inputs:
        if base_class in BASE_MAP:
            _, default_outputs = BASE_MAP[base_class]
            outputs = [dict(o) for o in default_outputs]  # deep copy

    # GNUiBase always appends a "state" CHOP output in initialize(),
    # regardless of _init_ports override
    if base_class == "GNUiBase":
        # Check if "state" isn't already in outputs
        has_state = any(o["name"] == "state" for o in outputs)
        if not has_state:
            outputs.append({
                "port": len(outputs),
                "name": "state",
                "type": "CHOP",
            })

    rel = path.relative_to(ROOT)

    return {
        "class_name": class_name,
        "family": family,
        "inputs": inputs,
        "outputs": outputs,
        "dynamic_inputs": dynamic_inputs,
        "file": str(rel).replace("\\", "/"),
    }


def main():
    registry = {}
    files_scanned = 0

    for ops_dir in OPERATOR_DIRS:
        for gd_file in sorted(ops_dir.rglob("*.gd")):
            files_scanned += 1
            info = scan_file(gd_file)
            if info is None:
                print(f"  SKIP (no class_name): {gd_file.relative_to(ROOT)}", file=sys.stderr)
                continue
            cn = info["class_name"]
            if cn in registry:
                # Prefer the non-native version (shorter path); keep native as alias
                existing = registry[cn]
                print(f"  DUP class_name={cn}: {info['file']} vs {existing['file']}", file=sys.stderr)
                continue
            registry[cn] = info

    # Second pass: resolve operators that extend other operators (not base classes)
    # e.g. CompositorEffectTOP extends RenderTOP
    for cn, info in registry.items():
        if not info["inputs"] and not info["outputs"] and not info.get("dynamic_inputs"):
            path = ROOT / info["file"]
            text = path.read_text(encoding="utf-8", errors="replace")
            extends_match = re.search(r'^extends\s+(\w+)', text, re.MULTILINE)
            if extends_match:
                parent = extends_match.group(1)
                if parent in registry:
                    p = registry[parent]
                    if not info["family"]:
                        info["family"] = p["family"]
                    if not info["inputs"] and p["inputs"]:
                        info["inputs"] = [dict(i) for i in p["inputs"]]
                    if not info["outputs"] and p["outputs"]:
                        info["outputs"] = [dict(o) for o in p["outputs"]]
                    if not info["dynamic_inputs"] and p.get("dynamic_inputs"):
                        info["dynamic_inputs"] = p["dynamic_inputs"]
                    info["inherits_from"] = parent

    # Print summary stats
    print(f"Scanned {files_scanned} files, found {len(registry)} operators", file=sys.stderr)

    # Write JSON to file
    out_path = ROOT / "scripts" / "port_registry.json"
    out_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")
    print(f"Written to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
