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


def get_app_version() -> str:
    """Reads the GONODES app version from project.godot (single source of truth)."""
    project_godot = os.path.join(ROOT, "project.godot")
    with open(project_godot, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r'config/version\s*=\s*"([^"]+)"', content)
    if not m:
        raise ValueError("project.godot missing config/version setting")
    return m.group(1)


def check_libgonodes_version(expected: str) -> list:
    """Validates that gonodes_host.h and CMakeLists.txt agree with versions.env."""
    errors = []
    parts = expected.split(".")
    if len(parts) != 3:
        errors.append(f"versions.env: LIBGONODES_VERSION '{expected}' is not MAJOR.MINOR.PATCH")
        return errors
    exp_major, exp_minor, exp_patch = parts

    # Check gonodes_host.h macros
    header = os.path.join(ROOT, "libgonodes", "include", "gonodes_host.h")
    if os.path.isfile(header):
        with open(header, encoding="utf-8") as f:
            hdr_content = f.read()

        for macro, exp_val in [("MAJOR", exp_major), ("MINOR", exp_minor), ("PATCH", exp_patch)]:
            m = re.search(
                rf'#define\s+GONODES_API_VERSION_{macro}\s+(\d+)',
                hdr_content,
            )
            if not m:
                errors.append(f"gonodes_host.h: GONODES_API_VERSION_{macro} not found")
            elif m.group(1) != exp_val:
                errors.append(
                    f"gonodes_host.h: GONODES_API_VERSION_{macro} is {m.group(1)}, "
                    f"expected {exp_val} (from versions.env)"
                )
    else:
        errors.append("gonodes_host.h not found")

    # Check CMakeLists.txt — look for file(STRINGS) or hardcoded project(VERSION)
    cmake = os.path.join(ROOT, "libgonodes", "CMakeLists.txt")
    if os.path.isfile(cmake):
        with open(cmake, encoding="utf-8") as f:
            cmake_content = f.read()

        # If CMakeLists reads from versions.env dynamically, that's fine.
        # But if there's a hardcoded project(... VERSION X.Y.Z), flag drift.
        m = re.search(r'project\s*\(\s*libgonodes\s+VERSION\s+([\d.]+)', cmake_content)
        if m:
            cmake_ver = m.group(1)
            if cmake_ver != expected:
                errors.append(
                    f"CMakeLists.txt: project VERSION is {cmake_ver}, "
                    f"expected {expected} (from versions.env)"
                )
        # else: version comes from versions.env dynamically — OK
    else:
        errors.append("libgonodes/CMakeLists.txt not found")

    return errors


def main():
    if not os.path.isfile(VERSIONS_FILE):
        print("ERROR: versions.env not found at project root")
        sys.exit(1)

    versions = load_versions_env()
    print(f"versions.env: {versions}")

    app_ver = get_app_version()
    print(f"GONODES app version (from project.godot): {app_ver}")

    errors = check_workflows(versions)
    errors.extend(check_template_source(versions))

    # libgonodes version consistency
    lib_ver = versions.get("LIBGONODES_VERSION")
    if lib_ver:
        print(f"libgonodes API version (from versions.env): {lib_ver}")
        errors.extend(check_libgonodes_version(lib_ver))
    else:
        errors.append("versions.env missing LIBGONODES_VERSION")

    if errors:
        print(f"\n{len(errors)} version mismatch(es) found:")
        for e in errors:
            print(f"  ✗ {e}")
        print(f"\nUpdate the affected files to match versions.env")
        sys.exit(1)
    else:
        print("All versions consistent ✓")


def check_template_source(versions: dict) -> list:
    """template_source.cfg godot_version must match versions.env."""
    errors = []
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import template_release
    found = template_release.read_source_cfg()
    expected = versions.get("GODOT_VERSION", "")
    got = found.get("godot_version", "")
    if got != expected:
        errors.append(
            "addons/gonodes/template_source.cfg: godot_version is '%s', "
            "expected '%s' (from versions.env)" % (got, expected)
        )
    return errors


if __name__ == "__main__":
    main()
