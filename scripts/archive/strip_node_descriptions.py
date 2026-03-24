#!/usr/bin/env python3
"""Strip node_description assignments from operator .gd files.

Since descriptions are now injected from the manifest (gn_core.cfg /
gn_extension.cfg) at create_instance() time, the hardcoded
`node_description = "..."` lines in _init() are redundant.

This script removes them from core operators. Extension operators are
left untouched (they may still want a fallback description).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OPERATORS_DIR = ROOT / "addons" / "gonodes" / "operators"

count = 0
for gd_file in sorted(OPERATORS_DIR.rglob("*.gd")):
    text = gd_file.read_text(encoding="utf-8", errors="replace")
    # Match lines like:  node_description = "..."
    # Could be tab-indented, single or double quoted
    new_text = re.sub(
        r'\n\tnode_description\s*=\s*"[^"]*"\n',
        '\n',
        text
    )
    if new_text != text:
        gd_file.write_text(new_text, encoding="utf-8", newline="")
        count += 1
        print(f"  Stripped: {gd_file.relative_to(ROOT)}")

print(f"\nStripped node_description from {count} files")
