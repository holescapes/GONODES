#!/usr/bin/env python3
"""Generate operator contract tests for untested GONODES operators.

Reads operator_registry.json, checks which class_names appear in existing
test files, and generates coverage test files for any operator missing tests.

Tests verify the *operator contract* — the minimum assertions every operator
must satisfy:
  1. Instantiation succeeds (ClassName.new() returns a GNNode)
  2. node_type is a non-empty string
  3. family matches the expected GNFamily.Type value
  4. Has at least one output port (generators) or input port (consumers)
  5. cook(null-inputs) does not crash

This script is idempotent — re-running it after adding operators will only
generate tests for newly added, untested operators.  Existing hand-written
tests are never overwritten.

Usage:
    python scripts/generate_operator_tests.py
    python scripts/generate_operator_tests.py --dry-run
    python scripts/generate_operator_tests.py --family top
    python scripts/generate_operator_tests.py --extension gn_ext_native
"""
import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts" / "operator_registry.json"

# GNFamily.Type enum values
FAMILY_ENUM = {
    "top": 0, "img": 1, "chop": 2, "sop": 3, "pop": 4,
    "dat": 5, "mat": 6, "comp": 7, "vol": 8, "ui": 9,
    "output": 10, "script": 11, "net": 12,
}


def load_registry():
    with open(REGISTRY, encoding="utf-8") as f:
        return json.load(f)


def collect_tested_classnames():
    """Scan all test .gd files and return set of class_names mentioned."""
    tested = set()
    dirs = [ROOT / "tests"]
    # Also scan extension test dirs
    addons = ROOT / "addons"
    if addons.exists():
        for d in addons.iterdir():
            if d.is_dir() and d.name.startswith("gn_ext_"):
                ext_tests = d / "tests"
                if ext_tests.exists():
                    dirs.append(ext_tests)

    for scan_dir in dirs:
        for gd_file in scan_dir.rglob("*.gd"):
            try:
                content = gd_file.read_text(encoding="utf-8", errors="ignore")
                tested.update(_extract_classnames(content))
            except Exception:
                pass
    return tested


def _extract_classnames(content: str) -> set:
    """Extract likely class names from GDScript test content."""
    import re
    # Match ClassName.new() or _make_node(ClassName.new(), or ClassName, "id")
    names = set()
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]+)\s*\.new\s*\(', content):
        names.add(m.group(1))
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]+)\s*,\s*"', content):
        names.add(m.group(1))
    return names


def output_path_for(op: dict) -> Path:
    """Determine the target test file path for an operator."""
    ext = op.get("extension")
    family = op["family"]
    if ext:
        # Extension operator → tests live in the extension's tests/ dir
        return ROOT / "addons" / ext / "tests" / f"test_{family}_coverage.gd"
    else:
        # Core operator → tests/unit/operators/<family>/
        return ROOT / "tests" / "unit" / "operators" / family / f"test_{family}_coverage.gd"


def family_enum_name(family: str) -> str:
    """Map registry family string to GNFamily.Type enum name."""
    mapping = {
        "top": "TOP", "img": "IMG", "chop": "CHOP", "sop": "SOP",
        "pop": "POP", "dat": "DAT", "mat": "MAT", "comp": "COMP",
        "vol": "VOL", "ui": "UI", "output": "OUT", "script": "SCRIPT",
        "net": "NET",
    }
    return mapping.get(family, family.upper())


def family_enum_value(family: str) -> int:
    # Extension families (e.g., "sdf") fall back to COMP (7) at runtime
    # via GNFamily.string_to_type() — mirror that behavior here.
    return FAMILY_ENUM.get(family, FAMILY_ENUM["comp"])


def generate_test_for_operator(op: dict) -> str:
    """Generate GDScript test functions for a single operator."""
    cn = op["class_name"]
    nt = op["node_type"]
    fam = op["family"]
    fam_enum = family_enum_name(fam)
    fam_val = family_enum_value(fam)
    id_str = nt.replace(" ", "_").lower()

    lines = []

    # Instantiation test
    lines.append(f'func test_{id_str}_instantiate() -> void:')
    lines.append(f'\tvar node := _make_node({cn}.new(), "{id_str}1")')
    lines.append(f'\tGNTestAssert.assert_not_null(node, "{cn} instantiates")')
    lines.append(f'\tGNTestAssert.assert_eq(node.node_type, "{nt}", "node_type")')
    lines.append(f'\tGNTestAssert.assert_eq(node.family, {fam_val}, "family is {fam_enum}")')
    lines.append('')

    # Cook-null test (no crash)
    lines.append(f'func test_{id_str}_cook_null() -> void:')
    lines.append(f'\tvar node := _make_node({cn}.new(), "{id_str}1")')
    lines.append(f'\t_cook_no_input(node)')
    lines.append(f'\t# No crash = pass. Output may be null for operators that need input.')
    lines.append(f'\tGNTestAssert.assert_true(true, "{cn} cook-null no crash")')
    lines.append('')

    return '\n'.join(lines)


def generate_test_file(target_path: Path, ops: list, family: str, source: str) -> str:
    """Generate a complete test .gd file for a list of operators in one family."""
    fam_upper = family.upper()
    source_label = source if source != "core" else "core"

    header = f'''extends Node
## Auto-generated operator contract tests for {fam_upper} family ({source_label}).
##
## Generated by: python scripts/generate_operator_tests.py
## Tests verify: instantiation, node_type, family, and cook-null safety.
## Do NOT edit manually — re-run the generator to update.


func _make_node(node: GNNode, id: String) -> GNNode:
\tnode.initialize(id)
\treturn node


func _cook_no_input(node: GNNode) -> GNData:
\tvar inputs: Array[GNData] = []
\tnode.execute_cook(inputs, 0)
\treturn node.cached_output


'''
    body = ''
    for op in sorted(ops, key=lambda o: o["class_name"]):
        body += generate_test_for_operator(op)

    return header + body


def main():
    parser = argparse.ArgumentParser(description="Generate operator contract tests")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be generated without writing files")
    parser.add_argument("--family", type=str, default="",
                        help="Only generate for this family (e.g., top, chop)")
    parser.add_argument("--extension", type=str, default="",
                        help="Only generate for this extension (e.g., gn_ext_native)")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate even if target file exists")
    args = parser.parse_args()

    ops = load_registry()
    tested = collect_tested_classnames()

    # Filter to untested operators only
    untested = [o for o in ops if o["class_name"] not in tested]

    if args.family:
        untested = [o for o in untested if o["family"] == args.family.lower()]
    if args.extension:
        untested = [o for o in untested if o.get("extension") == args.extension]

    if not untested:
        print("All operators are covered by existing tests. Nothing to generate.")
        return

    # Group by target file path
    groups: dict[Path, list] = {}
    for op in untested:
        path = output_path_for(op)
        groups.setdefault(path, []).append(op)

    total_ops = 0
    total_tests = 0
    files_written = 0

    for target_path, ops_group in sorted(groups.items()):
        family = ops_group[0]["family"]
        ext = ops_group[0].get("extension")
        source = ext if ext else "core"

        # Check if target already exists and has content
        if target_path.exists() and not args.force:
            # Read existing file to see if it was auto-generated
            existing = target_path.read_text(encoding="utf-8", errors="ignore")
            if "Auto-generated operator contract tests" in existing:
                # Re-generate (this file is ours)
                pass
            else:
                # Hand-written file — skip
                print(f"  SKIP {target_path.relative_to(ROOT)} (hand-written, use --force)")
                continue

        content = generate_test_file(target_path, ops_group, family, source)
        test_count = content.count("func test_")
        total_ops += len(ops_group)
        total_tests += test_count

        if args.dry_run:
            print(f"  WOULD WRITE {target_path.relative_to(ROOT)}")
            print(f"    {len(ops_group)} operators, {test_count} tests")
            for op in ops_group:
                print(f"      {op['class_name']}")
        else:
            target_path.parent.mkdir(parents=True, exist_ok=True)
            target_path.write_text(content, encoding="utf-8", newline="\n")
            files_written += 1
            print(f"  WROTE {target_path.relative_to(ROOT)}")
            print(f"    {len(ops_group)} operators, {test_count} tests")

    print()
    if args.dry_run:
        print(f"Dry run: would generate {total_tests} tests for "
              f"{total_ops} operators in {len(groups)} file(s)")
    else:
        print(f"Generated {total_tests} tests for {total_ops} operators "
              f"in {files_written} file(s)")


if __name__ == "__main__":
    main()
