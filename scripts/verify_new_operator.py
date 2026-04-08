#!/usr/bin/env python3
"""
verify_new_operator.py — Validate that a new operator is fully integrated.

Checks every touchpoint that must be updated when adding a new operator:
  1. Operator .gd file exists with required structure
  2. Registration in gn_core.cfg or gn_extension.cfg
  3. Help patches exist (minimum 1, target 3)
  4. operator_registry.json is up to date
  5. port_registry.json is up to date
  6. docs/OPERATORS.md lists the operator
  7. Operator count in docs is consistent
  8. Test file covers the operator's family

Usage:
  python scripts/verify_new_operator.py SinkOUT
  python scripts/verify_new_operator.py --all          # Check every registered operator
  python scripts/verify_new_operator.py --recent       # Show operators missing from registries
  python scripts/verify_new_operator.py SinkOUT --auto-register  # Register in gn_core.cfg
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)

# ── Colors ────────────────────────────────────────────────────────────────────

def green(s): return f"\033[92m{s}\033[0m"
def red(s):   return f"\033[91m{s}\033[0m"
def yellow(s): return f"\033[93m{s}\033[0m"
def bold(s):  return f"\033[1m{s}\033[0m"

PASS = green("✓")
FAIL = red("✗")
WARN = yellow("⚠")

# ── Finders ───────────────────────────────────────────────────────────────────

def find_gd_file(class_name):
    """Find the .gd file containing class_name declaration."""
    for root, _, files in os.walk("addons"):
        for f in files:
            if not f.endswith(".gd"):
                continue
            fp = os.path.join(root, f)
            try:
                text = open(fp, "r", encoding="utf-8").read()
            except Exception:
                continue
            if re.search(rf"^class_name\s+{re.escape(class_name)}\b", text, re.MULTILINE):
                return fp, text
    return None, None


def find_cfg_entry(class_name):
    """Check if the operator is registered in gn_core.cfg or any gn_extension.cfg."""
    cfgs = []
    core = ROOT / "addons" / "gonodes" / "gn_core.cfg"
    if core.exists():
        cfgs.append(("gn_core.cfg", core))
    for entry in sorted((ROOT / "addons").iterdir()):
        if entry.is_dir() and entry.name.startswith("gn_ext_"):
            cfg = entry / "gn_extension.cfg"
            if cfg.exists():
                cfgs.append((entry.name, cfg))

    section = f"[operator.{class_name}]"
    for label, cfg_path in cfgs:
        text = cfg_path.read_text(encoding="utf-8")
        if section in text:
            return label
    return None


def find_help_patches(class_name, node_type):
    """Find help .gnpatch files for this operator."""
    patches = []
    for root, _, files in os.walk("addons"):
        if "/help/" not in root.replace("\\", "/"):
            continue
        for f in files:
            if not f.endswith(".gnpatch"):
                continue
            fp = os.path.join(root, f)
            try:
                data = json.load(open(fp, "r", encoding="utf-8"))
            except Exception:
                continue
            nodes = data.get("nodes", {})
            for ninfo in nodes.values():
                if ninfo.get("type") == class_name:
                    patches.append(fp)
                    break
            else:
                # Fallback: filename match on node_type
                stem = Path(f).stem.lower()
                nt_lower = node_type.lower().replace("_", "")
                stem_stripped = stem.replace("_", "")
                if stem_stripped.startswith(nt_lower):
                    patches.append(fp)
    return list(set(patches))


def check_operator_registry(class_name):
    """Check if operator_registry.json includes this operator."""
    reg_path = ROOT / "scripts" / "operator_registry.json"
    if not reg_path.exists():
        return None  # File doesn't exist
    reg = json.load(open(reg_path, "r", encoding="utf-8"))
    for op in reg:
        if op.get("class_name") == class_name:
            return True
    return False


def check_port_registry(class_name):
    """Check if port_registry.json includes this operator."""
    reg_path = ROOT / "scripts" / "port_registry.json"
    if not reg_path.exists():
        return None
    reg = json.load(open(reg_path, "r", encoding="utf-8"))
    return class_name in reg


def check_operators_md(class_name):
    """Check if docs/OPERATORS.md mentions this operator."""
    md_path = ROOT / "docs" / "OPERATORS.md"
    if not md_path.exists():
        return None
    text = md_path.read_text(encoding="utf-8")
    return class_name in text


def check_test_coverage(class_name, family):
    """Check if there's a test file for this operator's family."""
    fam_lower = family.lower() if family else "unknown"
    # Map family names to test directories
    fam_dir_map = {
        "top": "top", "chop": "chop", "sop": "sop", "dat": "dat",
        "comp": "comp", "mat": "mat", "img": "img", "out": "output",
        "output": "output", "ui": "ui", "pop": "pop", "vol": "vol",
        "sdf": "sdf", "script": "script",
    }
    test_dir = fam_dir_map.get(fam_lower, fam_lower)

    # Check tests/operators/<family>/
    test_path = ROOT / "tests" / "operators" / test_dir
    if test_path.exists():
        for f in test_path.rglob("*.gd"):
            text = f.read_text(encoding="utf-8", errors="replace")
            if class_name in text:
                return str(f.relative_to(ROOT))

    # Check extension test directories
    for ext_dir in (ROOT / "addons").glob("gn_ext_*/tests"):
        for f in ext_dir.rglob("*.gd"):
            text = f.read_text(encoding="utf-8", errors="replace")
            if class_name in text:
                return str(f.relative_to(ROOT))

    return None


def extract_info(text):
    """Extract node_type and family from .gd file text."""
    m = re.search(r'node_type\s*=\s*"([^"]*)"', text)
    node_type = m.group(1) if m else None
    m = re.search(r'family\s*=\s*GNFamily\.Type\.(\w+)', text)
    family = m.group(1) if m else None
    return node_type, family


def extract_cfg_description(class_name):
    """Extract the description= value from the .cfg entry for this operator."""
    cfgs = []
    core = ROOT / "addons" / "gonodes" / "gn_core.cfg"
    if core.exists():
        cfgs.append(core)
    for entry in sorted((ROOT / "addons").iterdir()):
        if entry.is_dir() and entry.name.startswith("gn_ext_"):
            cfg = entry / "gn_extension.cfg"
            if cfg.exists():
                cfgs.append(cfg)

    section = f"[operator.{class_name}]"
    for cfg_path in cfgs:
        text = cfg_path.read_text(encoding="utf-8")
        idx = text.find(section)
        if idx < 0:
            continue
        # Read lines after the section header until next section
        block = text[idx + len(section):]
        next_sec = block.find("\n[")
        if next_sec > 0:
            block = block[:next_sec]
        m = re.search(r'description\s*=\s*"([^"]*)"', block)
        if m:
            return m.group(1)
    return None


# ── Base class → family mapping ───────────────────────────────────────────────

BASE_TO_FAMILY = {
    "GNTopBase": "TOP", "GNChopBase": "CHOP", "GNSopBase": "SOP",
    "GNDatBase": "DAT", "GNCompBase": "COMP", "GNMatBase": "MAT",
    "GNImgBase": "IMG", "GNOutBase": "OUT", "GNUiBase": "UI",
    "GNPopBase": "POP", "GNVolBase": "VOL", "GNNode": None,
}


def extract_docstring(gd_text):
    """Extract the first ## docstring line from a .gd file."""
    m = re.search(r"^##\s+(.+)", gd_text, re.MULTILINE)
    return m.group(1).strip() if m else None


def extract_family_from_extends(gd_text):
    """Derive the family name from the extends base class."""
    m = re.search(r"^extends\s+(\w+)", gd_text, re.MULTILINE)
    if not m:
        return None
    base = m.group(1)
    # Direct mapping
    if base in BASE_TO_FAMILY:
        return BASE_TO_FAMILY[base]
    # Fallback: infer from suffix (e.g., RenderTOP → TOP)
    for suffix in ("TOP", "CHOP", "SOP", "DAT", "COMP", "MAT", "IMG", "OUT", "UI", "POP", "VOL"):
        if base.upper().endswith(suffix):
            return suffix
    return None


def auto_register(class_name):
    """Auto-register an operator in gn_core.cfg using its .gd docstring.

    Returns True on success, False on failure.
    """
    # Check if already registered
    if find_cfg_entry(class_name):
        print(f"  {WARN} {class_name} is already registered — skipping")
        return True

    # Find the .gd file
    gd_path, gd_text = find_gd_file(class_name)
    if not gd_path:
        print(f"  {FAIL} Cannot auto-register: .gd file not found for '{class_name}'")
        return False

    # Extract family
    family = extract_family_from_extends(gd_text)
    if not family:
        # Fallback from extract_info
        _, family = extract_info(gd_text)
    if not family:
        print(f"  {FAIL} Cannot auto-register: unable to determine family for '{class_name}'")
        return False

    # Extract description from ## docstring
    description = extract_docstring(gd_text)
    if not description:
        print(f"  {FAIL} Cannot auto-register: no ## docstring in {gd_path}")
        return False

    # Build script path (convert filesystem path to res://)
    rel_path = os.path.relpath(gd_path, ROOT).replace("\\", "/")
    script_path = f"res://{rel_path}"

    # Append to gn_core.cfg
    core_cfg = ROOT / "addons" / "gonodes" / "gn_core.cfg"
    if not core_cfg.exists():
        print(f"  {FAIL} gn_core.cfg not found")
        return False

    entry = (
        f"\n[operator.{class_name}]\n"
        f"\n"
        f'family="{family}"\n'
        f'script="{script_path}"\n'
        f'description="{description}"\n'
    )

    with open(core_cfg, "a", encoding="utf-8") as f:
        f.write(entry)

    print(f"  {PASS} Auto-registered {class_name} in gn_core.cfg")
    print(f"        family={family}")
    print(f"        description=\"{description}\"")
    return True


def count_operators_in_docs():
    """Extract the operator count from docs/OPERATORS.md header."""
    md_path = ROOT / "docs" / "OPERATORS.md"
    if not md_path.exists():
        return None
    text = md_path.read_text(encoding="utf-8")
    m = re.search(r"\*\*(\d+)\s+operators\*\*", text)
    return int(m.group(1)) if m else None


def count_registered_operators():
    """Count operators registered in gn_core.cfg + all gn_extension.cfg files."""
    count = 0
    cfgs = []
    core = ROOT / "addons" / "gonodes" / "gn_core.cfg"
    if core.exists():
        cfgs.append(core)
    for entry in sorted((ROOT / "addons").iterdir()):
        if entry.is_dir() and entry.name.startswith("gn_ext_"):
            cfg = entry / "gn_extension.cfg"
            if cfg.exists():
                cfgs.append(cfg)
    for cfg_path in cfgs:
        text = cfg_path.read_text(encoding="utf-8")
        count += len(re.findall(r"^\[operator\.\w+\]", text, re.MULTILINE))
    return count


# ── Verify one operator ──────────────────────────────────────────────────────

def verify_operator(class_name, verbose=True):
    """Run all checks for a single operator. Returns (pass_count, fail_count, warn_count)."""
    passes = 0
    fails = 0
    warns = 0

    if verbose:
        print(f"\n{bold(f'Verifying: {class_name}')}")
        print("=" * 50)

    # 1. Find .gd file
    gd_path, gd_text = find_gd_file(class_name)
    if gd_path:
        if verbose:
            print(f"  {PASS} Operator file: {gd_path}")
        passes += 1
    else:
        if verbose:
            print(f"  {FAIL} Operator .gd file NOT FOUND for class_name '{class_name}'")
        fails += 1
        return passes, fails, warns

    # 2. Extract metadata from .gd
    node_type, family = extract_info(gd_text)
    if node_type:
        if verbose:
            print(f"  {PASS} node_type = \"{node_type}\"")
        passes += 1
    else:
        if verbose:
            print(f"  {FAIL} Missing node_type in _init()")
        fails += 1

    if family:
        if verbose:
            print(f"  {PASS} family = {family}")
        passes += 1
    else:
        if verbose:
            print(f"  {FAIL} Missing family assignment")
        fails += 1

    # 2b. Check description in .cfg (single source of truth)
    cfg_desc = extract_cfg_description(class_name)
    if cfg_desc:
        if verbose:
            print(f"  {PASS} description in .cfg")
        passes += 1
    else:
        if verbose:
            print(f"  {WARN} Missing description= in .cfg entry")
        warns += 1

    # 3. Registration
    cfg_label = find_cfg_entry(class_name)
    if cfg_label:
        if verbose:
            print(f"  {PASS} Registered in {cfg_label}")
        passes += 1
    else:
        if verbose:
            print(f"  {FAIL} NOT registered in any .cfg file")
            print(f"        → Add [operator.{class_name}] to gn_core.cfg or gn_extension.cfg")
        fails += 1

    # 4. Help patches
    help_patches = find_help_patches(class_name, node_type or "")
    if len(help_patches) >= 3:
        if verbose:
            print(f"  {PASS} {len(help_patches)} help patches found")
        passes += 1
    elif len(help_patches) >= 1:
        if verbose:
            print(f"  {WARN} {len(help_patches)} help patch(es) — target is 3+")
            for p in help_patches:
                print(f"        {p}")
        warns += 1
    else:
        if verbose:
            print(f"  {FAIL} No help patches found")
            fam_lower = (family or "unknown").lower()
            fam_dir = "output" if fam_lower == "out" else fam_lower
            print(f"        → Create addons/gonodes/help/{fam_dir}/{node_type or 'xxx'}_basic.gnpatch")
        fails += 1

    # 5. operator_registry.json
    in_op_reg = check_operator_registry(class_name)
    if in_op_reg is True:
        if verbose:
            print(f"  {PASS} In operator_registry.json")
        passes += 1
    elif in_op_reg is False:
        if verbose:
            print(f"  {WARN} Missing from operator_registry.json")
            print(f"        → Run: python scripts/scan_operators.py")
        warns += 1
    # None = file not found, skip

    # 6. port_registry.json
    in_port_reg = check_port_registry(class_name)
    if in_port_reg is True:
        if verbose:
            print(f"  {PASS} In port_registry.json")
        passes += 1
    elif in_port_reg is False:
        if verbose:
            print(f"  {WARN} Missing from port_registry.json")
            print(f"        → Run: python scripts/build_port_registry.py")
        warns += 1

    # 7. docs/OPERATORS.md
    in_docs = check_operators_md(class_name)
    if in_docs is True:
        if verbose:
            print(f"  {PASS} Listed in docs/OPERATORS.md")
        passes += 1
    elif in_docs is False:
        if verbose:
            print(f"  {FAIL} Missing from docs/OPERATORS.md")
            print(f"        → Add entry under the {family} section with parameter table")
        fails += 1

    # 8. Test coverage
    test_file = check_test_coverage(class_name, family)
    if test_file:
        if verbose:
            print(f"  {PASS} Referenced in test: {test_file}")
        passes += 1
    else:
        if verbose:
            fam_lower = (family or "unknown").lower()
            fam_dir = "output" if fam_lower == "out" else fam_lower
            print(f"  {WARN} No test reference found")
            print(f"        → Add to tests/operators/{fam_dir}/test_{fam_dir}_operators.gd")
        warns += 1

    if verbose:
        print()
        status = green("ALL CLEAR") if fails == 0 and warns == 0 else \
                 yellow(f"{fails} issues, {warns} warnings") if fails == 0 else \
                 red(f"{fails} MISSING, {warns} warnings")
        print(f"  Result: {status}")

    return passes, fails, warns


# ── Aggregate checks ─────────────────────────────────────────────────────────

def check_doc_counts():
    """Verify operator counts match across docs."""
    print(f"\n{bold('Operator Count Consistency')}")
    print("=" * 50)

    reg_count = count_registered_operators()
    doc_count = count_operators_in_docs()

    print(f"  Registered in .cfg files: {reg_count}")
    print(f"  Stated in docs/OPERATORS.md: {doc_count}")

    files_to_check = [
        ("README.md", r"\*\*(\d+)\s+operators\*\*"),
        ("docs/OPERATORS.md", r"\*\*(\d+)\s+operators\*\*"),
        ("dev_docs/TESTING.md", r"All\s+(\d+)\s+operators"),
        ("dev_docs/GONODES_VS_THE_REST.md", r"(\d+)\s+operators\s+across"),
    ]

    mismatches = []
    for filepath, pattern in files_to_check:
        fp = ROOT / filepath
        if not fp.exists():
            continue
        text = fp.read_text(encoding="utf-8")
        matches = re.findall(pattern, text)
        for m in matches:
            count = int(m)
            if count != reg_count:
                mismatches.append((filepath, count))

    if mismatches:
        print(f"\n  {FAIL} Count mismatches (expected {reg_count}):")
        for fp, count in mismatches:
            print(f"        {fp}: says {count}")
    else:
        print(f"\n  {PASS} All doc counts consistent ({reg_count})")

    return len(mismatches) == 0


def find_unregistered():
    """Find .gd files with class_name that look like operators but aren't registered."""
    print(f"\n{bold('Checking for unregistered operators...')}")

    # Collect all registered class names
    registered = set()
    cfgs = []
    core = ROOT / "addons" / "gonodes" / "gn_core.cfg"
    if core.exists():
        cfgs.append(core)
    for entry in sorted((ROOT / "addons").iterdir()):
        if entry.is_dir() and entry.name.startswith("gn_ext_"):
            cfg = entry / "gn_extension.cfg"
            if cfg.exists():
                cfgs.append(cfg)
    for cfg_path in cfgs:
        text = cfg_path.read_text(encoding="utf-8")
        for m in re.finditer(r"^\[operator\.(\w+)\]", text, re.MULTILINE):
            registered.add(m.group(1))

    # Scan operator directories for class_names
    unregistered = []
    for root, _, files in os.walk("addons"):
        # Only look in operators/ directories
        if "/operators/" not in root.replace("\\", "/"):
            continue
        for f in files:
            if not f.endswith(".gd"):
                continue
            fp = os.path.join(root, f)
            try:
                text = open(fp, "r", encoding="utf-8").read()
            except Exception:
                continue
            m = re.search(r"^class_name\s+(\w+)", text, re.MULTILINE)
            if not m:
                continue
            cn = m.group(1)
            # Skip Native variants, base classes, and utilities
            if cn.endswith("Native") or cn.startswith("GN") or cn == "DotNode":
                continue
            if cn not in registered:
                unregistered.append((cn, fp))

    if unregistered:
        print(f"  {WARN} {len(unregistered)} unregistered operator(s):")
        for cn, fp in unregistered:
            print(f"        {cn} ({fp})")
    else:
        print(f"  {PASS} All operators are registered")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Verify new operator integration")
    parser.add_argument("class_name", nargs="?", help="Operator class_name (e.g., SinkOUT)")
    parser.add_argument("--all", action="store_true", help="Verify all registered operators")
    parser.add_argument("--recent", action="store_true", help="Find unregistered operators")
    parser.add_argument("--counts", action="store_true", help="Check doc count consistency")
    parser.add_argument("--quiet", action="store_true", help="Summary only")
    parser.add_argument("--auto-register", action="store_true",
                        help="Auto-register the operator in gn_core.cfg using its ## docstring")
    args = parser.parse_args()

    if args.auto_register:
        if not args.class_name:
            print(red("ERROR: --auto-register requires a class_name argument"))
            return 1
        ok = auto_register(args.class_name)
        if not ok:
            return 1
        # After registering, run the full verify
        _, fails, _ = verify_operator(args.class_name)
        return 1 if fails > 0 else 0

    if args.counts or (not args.class_name and not args.all and not args.recent):
        check_doc_counts()

    if args.recent or (not args.class_name and not args.all):
        find_unregistered()

    if args.all:
        # Verify every registered operator
        cfgs = []
        core = ROOT / "addons" / "gonodes" / "gn_core.cfg"
        if core.exists():
            cfgs.append(core)
        for entry in sorted((ROOT / "addons").iterdir()):
            if entry.is_dir() and entry.name.startswith("gn_ext_"):
                cfg = entry / "gn_extension.cfg"
                if cfg.exists():
                    cfgs.append(cfg)

        all_names = []
        for cfg_path in cfgs:
            text = cfg_path.read_text(encoding="utf-8")
            for m in re.finditer(r"^\[operator\.(\w+)\]", text, re.MULTILINE):
                all_names.append(m.group(1))

        total_p, total_f, total_w = 0, 0, 0
        problem_ops = []
        for cn in sorted(all_names):
            p, f, w = verify_operator(cn, verbose=not args.quiet)
            total_p += p
            total_f += f
            total_w += w
            if f > 0:
                problem_ops.append(cn)

        print(f"\n{'=' * 50}")
        print(f"TOTAL: {len(all_names)} operators, {total_p} checks passed, "
              f"{total_f} failed, {total_w} warnings")
        if problem_ops:
            print(f"  Operators with issues: {', '.join(problem_ops)}")

        check_doc_counts()
        return 1 if total_f > 0 else 0

    if args.class_name:
        _, fails, _ = verify_operator(args.class_name)
        return 1 if fails > 0 else 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
