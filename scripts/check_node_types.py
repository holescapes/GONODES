"""List all node_type values from operator .gd files."""
import os, re

for root, dirs, files in os.walk("addons"):
    for f in sorted(files):
        if not f.endswith(".gd"):
            continue
        path = os.path.join(root, f)
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r'\s*node_type\s*=\s*"([^"]+)"', line)
                if m:
                    print(f"{m.group(1):30s} {path}")
