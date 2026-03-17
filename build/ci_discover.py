#!/usr/bin/env python3
"""
ci_discover.py — Scan addons/ for GDExtensions with native/build.cfg.

Outputs a GitHub Actions matrix JSON for dynamic job generation.
Called from the 'discover' job in build-extensions.yml.

Output format (to GITHUB_OUTPUT):
  matrix=["gn_ext_hap","gn_ext_spout","gn_ext_midi",...]
"""

import json
import os

addons_dir = os.path.join(os.path.dirname(__file__), "..", "addons")
addons_dir = os.path.abspath(addons_dir)

extensions = []
for entry in sorted(os.listdir(addons_dir)):
    if not entry.startswith("gn_ext_") or entry == "gn_ext_native":
        continue
    cfg_path = os.path.join(addons_dir, entry, "native", "build.cfg")
    if os.path.isfile(cfg_path):
        extensions.append(entry)

print(f"matrix={json.dumps(extensions)}")

if extensions:
    print(f"  Discovered {len(extensions)} buildable extensions:", file=__import__('sys').stderr)
    for ext in extensions:
        print(f"    - {ext}", file=__import__('sys').stderr)
else:
    print("  No buildable extensions found.", file=__import__('sys').stderr)
