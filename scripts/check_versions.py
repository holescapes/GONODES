#!/usr/bin/env python3
"""
Validates that all CI workflows and setup_deps.py agree on the versions
defined in versions.env.

Usage:
  python scripts/check_versions.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSIONS_FILE = os.path.join(ROOT, "versions.env")


def load_versions_env() -> dict:
    vals = {}
    with open(VERSIONS_FILE, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                vals[k.strip()] = v.strip()
    return vals


def check_workflows(versions: dict) -> list:
    errors = []
    workflow_dir = os.path.join(ROOT, ".github", "workflows")
    if not os.path.isdir(workflow_dir):
        return errors

    for fname in sorted(os.listdir(workflow_dir)):
        if not fname.endswith((".yml", ".yaml")):
            continue
        fpath = os.path.join(workflow_dir, fname)
        with open(fpath, encoding="utf-8") as f:
            content = f.read()

        for key, expected in versions.items():
            # Look for env: blocks with KEY: "value" patterns
            pattern = rf'{key}:\s*["\']?([^"\'#\n]+)["\']?'
            for m in re.finditer(pattern, content):
                found = m.group(1).strip()
                if found != expected:
                    line_num = content[:m.start()].count("\n") + 1
                    errors.append(
                        f"{fname}:{line_num}: {key} is '{found}', "
                        f"expected '{expected}' (from versions.env)"
                    )
    return errors


def main():
    if not os.path.isfile(VERSIONS_FILE):
        print("ERROR: versions.env not found at project root")
        sys.exit(1)

    versions = load_versions_env()
    print(f"versions.env: {versions}")

    errors = check_workflows(versions)

    if errors:
        print(f"\n{len(errors)} version mismatch(es) found:")
        for e in errors:
            print(f"  ✗ {e}")
        print(f"\nUpdate the workflow env: blocks to match versions.env")
        sys.exit(1)
    else:
        print("All CI workflows match versions.env ✓")


if __name__ == "__main__":
    main()
