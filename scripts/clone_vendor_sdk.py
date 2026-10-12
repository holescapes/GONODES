#!/usr/bin/env python3
"""Clone one permissive SDK declared as vendor_clone in build.cfg.

GitHub Actions sets VENDOR_CLONE_JSON to the discover job's map and EXT_KEY
to the extension being built. No-op when this extension has nothing to clone.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys


def main() -> int:
    raw = os.environ.get("VENDOR_CLONE_JSON", "").strip() or "{}"
    ext = os.environ.get("EXT_KEY", "").strip()
    try:
        mapping = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"vendor clone JSON is not valid: {exc}")
        return 1
    spec = mapping.get(ext, "")
    if not spec:
        return 0
    parts = spec.split()
    if len(parts) < 2:
        print(f"vendor clone for {ext} is incomplete: {spec}")
        return 1
    url, dest_dir = parts[0], parts[1]
    ext_base = ext.split("/")[0]
    dest = os.path.join("addons", ext_base, "native", dest_dir)
    if os.path.isdir(dest) and os.listdir(dest):
        print(f"present {dest}")
        return 0
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    print(f"cloning {url} -> {dest}")
    subprocess.run(["git", "clone", "--depth", "1", url, dest], check=True)
    marker = os.path.join(dest, ".gdignore")
    if not os.path.isfile(marker):
        open(marker, "w").close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
