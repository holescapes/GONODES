"""
GONODES Help Patch Fixer
Fixes common quality issues detected by audit_help_patches.py.

Targeted fixes:
1. Trivial "Default settings" annotations → meaningful description from cfg
2. Expressions in _basic patches → stripped to VALUE mode
3. Missing annotations → added from cfg description
4. Expressions on known menu parameters → stripped to VALUE mode
5. Generic "Showcases: x, y" → expanded with descriptions

Usage:
    python scripts/fix_help_patches.py                    # Full fix (dry-run)
    python scripts/fix_help_patches.py --apply            # Actually write fixes
    python scripts/fix_help_patches.py --family top       # Fix one family
    python scripts/fix_help_patches.py --family top --apply
"""
import json
import os
import re
import sys
import io

# Force UTF-8 stdout to avoid cp1252 encoding errors on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from pathlib import Path
from configparser import ConfigParser
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
HELP_DIR = ROOT / "addons" / "gonodes" / "help"
CORE_CFG = ROOT / "addons" / "gonodes" / "gn_core.cfg"
REGISTRY_PATH = ROOT / "scripts" / "operator_registry.json"

# ── Known menu parameters (should never have expressions) ──────────
MENU_PARAMS = {
    "noise_type", "method", "mode", "waveform", "operation",
    "blend_mode", "key_mode", "projection", "shape", "algorithm",
    "space", "axis", "function", "order", "direction",
    "primitive_type", "filter", "interpolation", "type",
    "wrap_mode", "fill_mode", "source", "target", "combine",
    "cull_mode", "depth_func", "blend_src", "blend_dst",
    "topology", "format", "color_space", "channel",
}

# ── Load all operator descriptions from cfg files ──────────────────

def load_descriptions():
    """Parse gn_core.cfg and extension cfgs for operator descriptions."""
    descs = {}  # class_name -> description

    # Find all .cfg files
    cfg_files = [CORE_CFG]
    ext_dirs = (ROOT / "addons").glob("gn_ext_*")
    for ext_dir in ext_dirs:
        cfgs = list(ext_dir.glob("gn_extension.cfg"))
        cfg_files.extend(cfgs)

    for cfg_path in cfg_files:
        if not cfg_path.exists():
            continue
        try:
            cp = ConfigParser()
            cp.read(str(cfg_path), encoding="utf-8")
            for section in cp.sections():
                if section.startswith("operator."):
                    class_name = section.split(".", 1)[1]
                    desc = cp.get(section, "description", fallback="")
                    if desc:
                        # Strip quotes if present
                        desc = desc.strip('"').strip("'")
                        descs[class_name] = desc
        except Exception as e:
            print(f"  Warning: Could not parse {cfg_path}: {e}")

    return descs


def load_registry():
    """Load operator registry for node_type lookups."""
    if REGISTRY_PATH.exists():
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Build lookup: node_type -> entry, class_name -> entry
        by_type = {}
        by_class = {}
        for entry in data:
            by_type[entry["node_type"]] = entry
            by_class[entry["class_name"]] = entry
        return by_type, by_class
    return {}, {}


def _build_nodetype_to_class(registry_path):
    """Build (node_type, family) -> class_name lookup from registry."""
    lookup = {}
    if registry_path.exists():
        with open(registry_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for entry in data:
            key = (entry["node_type"], entry["family"])
            lookup[key] = entry["class_name"]
    return lookup

_NT_FAM_TO_CLASS = _build_nodetype_to_class(REGISTRY_PATH)

# Render/viewer chain types — always skip as focus node
CHAIN_TYPES = {
    "WindowOUT", "CHOPtoTOP", "NullCHOP", "NullTOP", "NullSOP", "NullDAT",
    "GeometryCOMP", "CameraCOMP", "RenderTOP", "RenderPOP", "RaymarchVOL",
    "ImgToTOP", "LightCOMP", "SinkOUT",
}

# Common source types (skip when id starts with "src_")
SOURCE_TYPES = {
    "NoiseTOP", "CircleTOP", "RampTOP", "RectangleTOP", "ConstantCHOP",
    "WaveCHOP", "LFO_CHOP", "GridSOP", "SphereSOP", "BoxSOP", "LevelTOP",
    "TorusSOP", "TextDAT", "ConstantTOP",
}


def class_name_from_patch(patch, filename, family=None):
    """Infer the focus operator class_name from a patch.
    Uses the filename + registry to resolve, then falls back to node heuristics."""
    nodes = patch.get("nodes", {})

    # Strategy 1: Use filename to look up class_name via registry
    # Filename format: "{node_type}_{variant}.gnpatch" or "{node_type}_{feature}.gnpatch"
    # Strip variant suffixes to get node_type
    stem = filename
    for suffix in ("_basic", "_advanced"):
        if stem.endswith(suffix):
            stem = stem[:-len(suffix)]
            break
    else:
        # Feature variant: strip last segment (e.g., "blur_size" -> "blur")
        parts = stem.rsplit("_", 1)
        if len(parts) > 1:
            stem = parts[0]

    # Look up in registry (family-aware)
    if family and (stem, family) in _NT_FAM_TO_CLASS:
        expected_class = _NT_FAM_TO_CLASS[(stem, family)]
        # Verify the operator is actually in the patch
        for nid, ndata in nodes.items():
            if ndata.get("type") == expected_class:
                return expected_class
        # Operator NOT in patch — return it anyway so annotations use the right name
        return expected_class

    # Strategy 2: Heuristic — first non-source, non-chain node
    candidates = []
    for nid, ndata in nodes.items():
        ntype = ndata.get("type", "")
        if ntype in CHAIN_TYPES:
            continue
        if ntype in SOURCE_TYPES and nid.startswith("src_"):
            continue
        candidates.append((nid, ntype))

    if candidates:
        return candidates[0][1]
    return None


def human_name(class_name):
    """Convert class_name to human-readable form.
    'BlurTOP' -> 'Blur TOP', 'Fluid2DTOP' -> 'Fluid 2D TOP',
    'CHOPtoTOP' -> 'CHOP to TOP', 'AntiAliasTOP' -> 'Anti Alias TOP'."""
    if not class_name:
        return "Unknown"
    name = class_name
    # Handle known special cases
    name = name.replace("CHOPtoTOP", "CHOP to TOP")
    # Separate trailing family suffix (TOP, CHOP, SOP, DAT, IMG, MAT, COMP, VOL, POP, UI, OUT, SDF)
    m = re.match(r'^(.+?)(TOP|CHOP|SOP|DAT|IMG|MAT|COMP|VOL|POP|UI|OUT|SDF)$', name)
    if m:
        body, suffix = m.group(1), m.group(2)
        # Insert spaces: "AntiAlias" -> "Anti Alias", "Fluid2D" -> "Fluid 2D"
        body = re.sub(r'([a-z])([A-Z])', r'\1 \2', body)  # camelCase
        body = re.sub(r'([A-Z]{2,})([A-Z][a-z])', r'\1 \2', body)  # NDIAudio -> NDI Audio
        body = re.sub(r'(\d+)([A-Z])', r'\1 \2', body)  # 2D -> 2 D (then rejoin below)
        body = re.sub(r'([a-zA-Z])(\d)', r'\1 \2', body)  # Fluid2 -> Fluid 2
        # Rejoin "2 D" back to "2D"
        body = re.sub(r'(\d)\s+([A-Z])(?=[^a-z]|$)', r'\1\2', body)
        return f"{body} {suffix}"
    # Fallback
    return re.sub(r'([a-z])([A-Z])', r'\1 \2', name)


def _variant_from_filename(filename):
    """Extract the variant/feature name from a patch filename stem."""
    if filename.endswith("_basic"):
        return "Basic"
    if filename.endswith("_advanced"):
        return "Advanced"
    parts = filename.rsplit("_", 1)
    return parts[-1].replace("_", " ").title() if len(parts) > 1 else "Demo"


# ── Fix functions ──────────────────────────────────────────────────

def strip_expressions_in_basic(patch, filename):
    """Remove all expressions from _basic patches. Returns (fixed, changes)."""
    if not filename.endswith("_basic"):
        return False, []

    changes = []
    nodes = patch.get("nodes", {})
    for nid, ndata in nodes.items():
        params = ndata.get("parameters", {})
        for pname, pval in params.items():
            if isinstance(pval, dict) and pval.get("mode") == "EXPRESSION":
                pval.pop("expression", None)
                pval.pop("mode", None)
                changes.append(f"  Stripped expression from '{pname}' in '{nid}'")

    return bool(changes), changes


def strip_menu_expressions(patch):
    """Remove expressions from known menu/enum parameters. Returns (fixed, changes)."""
    changes = []
    nodes = patch.get("nodes", {})
    for nid, ndata in nodes.items():
        params = ndata.get("parameters", {})
        for pname, pval in params.items():
            if isinstance(pval, dict) and pval.get("mode") == "EXPRESSION":
                if pname in MENU_PARAMS:
                    pval.pop("expression", None)
                    pval.pop("mode", None)
                    changes.append(f"  Stripped menu expression from '{pname}' in '{nid}'")

    return bool(changes), changes


def fix_trivial_annotation(patch, filename, descs, family):
    """Replace trivial annotations with meaningful ones. Returns (fixed, changes)."""
    annotations = patch.get("annotations", [])

    if not annotations:
        return False, []

    ann = annotations[0]
    text = ann.get("text", "")

    # Check if annotation is trivial
    trivial_patterns = [
        r"Default settings\.?",
        r"^.*—\s*(Basic|Parameters|Advanced)\s*\n\s*Default settings\.?\s*$",
        r"^.*—\s*(Basic|Parameters|Advanced)\s*\n\s*$",
        r"Alternate parameter values\.?",
        r"More complex configuration\.?",
    ]

    is_trivial = False
    for pattern in trivial_patterns:
        if re.search(pattern, text, re.MULTILINE | re.IGNORECASE):
            is_trivial = True
            break

    if not is_trivial:
        return False, []

    # Find the focus class_name to get description
    class_name = class_name_from_patch(patch, filename, family)
    if not class_name:
        return False, [f"  Could not identify focus operator for {filename}"]

    desc = descs.get(class_name, "")
    if not desc:
        return False, [f"  No description found for {class_name}"]

    # Determine patch variant from filename
    variant = _variant_from_filename(filename)

    hname = human_name(class_name)

    # Get demonstrative params from the focus node
    nodes = patch.get("nodes", {})
    focus_params = ""
    for nid, ndata in nodes.items():
        if ndata.get("type") == class_name:
            params = ndata.get("parameters", {})
            param_strs = []
            for pname, pval in params.items():
                if isinstance(pval, dict):
                    val = pval.get("value")
                else:
                    val = pval
                if val is not None and pname not in ("resolution", "open"):
                    if isinstance(val, dict) and "_type" in val:
                        continue  # Skip Vector2i etc
                    param_strs.append(f"{pname}={val}")
            if param_strs:
                focus_params = ", ".join(param_strs[:4])
            break

    if variant == "Basic":
        new_text = f"{hname} — Basic\n\n{desc}"
        if focus_params:
            new_text += f"\nUsing: {focus_params}."
    elif variant == "Advanced":
        new_text = f"{hname} — Advanced\n\n{desc}"
        if focus_params:
            new_text += f"\nCombined configuration: {focus_params}."
    else:
        new_text = f"{hname} — {variant}\n\n{desc}"
        if focus_params:
            new_text += f"\nShowcasing: {focus_params}."

    ann["text"] = new_text
    # Make annotation bigger if text is longer
    if len(new_text) > 120:
        ann["size"] = [500.0, 140.0]

    return True, [f"  Replaced trivial annotation with: '{new_text[:80]}...'"]


def add_missing_annotation(patch, filename, descs, family):
    """Add annotation to patches that have none. Returns (fixed, changes)."""
    if patch.get("annotations"):
        return False, []

    class_name = class_name_from_patch(patch, filename, family)
    if not class_name:
        return False, [f"  Could not identify focus operator for {filename}"]

    desc = descs.get(class_name, "")
    hname = human_name(class_name)
    variant = _variant_from_filename(filename)

    if desc:
        text = f"{hname} — {variant}\n\n{desc}"
    else:
        text = f"{hname} — {variant}\n\nDemonstrates {hname.lower()} functionality."

    patch["annotations"] = [{
        "id": "ann_1",
        "type": "note",
        "text": text,
        "position": [-100.0, -100.0],
        "size": [500.0, 120.0],
        "color": [1.0, 1.0, 1.0, 0.8],
    }]

    return True, [f"  Added annotation: '{text[:80]}...'"]


def fix_showcases_annotation(patch, filename, descs, family):
    """Expand generic 'Showcases: x, y' annotations. Returns (fixed, changes)."""
    annotations = patch.get("annotations", [])
    if not annotations:
        return False, []

    ann = annotations[0]
    text = ann.get("text", "")

    # Match "Showcases: param1, param2, param3" pattern
    m = re.search(r"Showcases:\s*(.+)", text)
    if not m:
        return False, []
    if len(text) > 100:
        # Already has a decent explanation
        return False, []

    # Get description for this operator
    class_name = class_name_from_patch(patch, filename, family)
    desc = descs.get(class_name, "") if class_name else ""

    # Extract feature params being showcased
    showcased = m.group(1).strip().rstrip(".")

    hname = human_name(class_name) if class_name else filename
    variant = _variant_from_filename(filename)

    if desc:
        new_text = f"{hname} — {variant}\n\n{desc}\nFocused parameters: {showcased}."
    else:
        new_text = f"{hname} — {variant}\n\nDemonstrates {showcased} parameters."

    ann["text"] = new_text
    if len(new_text) > 120:
        ann["size"] = [500.0, 140.0]

    return True, [f"  Expanded Showcases annotation to: '{new_text[:80]}...'"]


# ── Main orchestrator ──────────────────────────────────────────────

def fix_all(families=None, apply=False, scope="all"):
    """Fix all help patches. If apply=False, dry-run only."""
    descs = load_descriptions()
    print(f"  Loaded {len(descs)} operator descriptions from cfg files.")

    total_patches = 0
    total_fixed = 0
    total_changes = 0
    broken_patches = []
    family_stats = defaultdict(lambda: {"patches": 0, "fixed": 0, "changes": 0})

    # Collect family directories (core + extensions)
    family_dirs = []
    if scope in ("all", "core") and HELP_DIR.exists():
        family_dirs.extend(sorted(d for d in HELP_DIR.iterdir() if d.is_dir()))
    if scope in ("all", "extensions"):
        ext_dirs = sorted(ROOT.glob("addons/gn_ext_*/help"))
        for ext_help in ext_dirs:
            for d in sorted(ext_help.iterdir()):
                if d.is_dir():
                    family_dirs.append(d)
    if not family_dirs:
        print("No help directories found")
        return

    for family_dir in family_dirs:
        parent_name = family_dir.parent.parent.name
        if parent_name.startswith("gn_ext_"):
            family_name = f"{parent_name}/{family_dir.name}"
            raw_family = family_dir.name  # just "sop", "top", etc. for registry lookups
        else:
            family_name = family_dir.name
            raw_family = family_dir.name
        if families and family_name not in families and family_dir.name not in families:
            continue

        for patch_file in sorted(family_dir.glob("*.gnpatch")):
            total_patches += 1
            family_stats[family_name]["patches"] += 1

            try:
                with open(patch_file, "r", encoding="utf-8") as f:
                    patch = json.load(f)
            except (json.JSONDecodeError, Exception) as e:
                print(f"  SKIP {patch_file.name}: {e}")
                continue

            filename = patch_file.stem

            # Check if focus operator is missing from patch (broken/misplaced)
            stem = filename
            for sfx in ("_basic", "_advanced"):
                if stem.endswith(sfx):
                    stem = stem[:-len(sfx)]
                    break
            else:
                parts = stem.rsplit("_", 1)
                if len(parts) > 1:
                    stem = parts[0]

            key = (stem, raw_family)
            if key in _NT_FAM_TO_CLASS:
                expected_class = _NT_FAM_TO_CLASS[key]
                types_in_patch = {nd.get("type") for nd in patch.get("nodes", {}).values()}
                if expected_class not in types_in_patch:
                    broken_patches.append(f"{family_name}/{patch_file.name} (expected {expected_class})")
                    continue  # Skip — needs regeneration, not text fixes

            all_changes = []
            was_fixed = False

            # Apply fixes in priority order
            for fix_fn in [
                lambda p, fn: strip_expressions_in_basic(p, fn),
                lambda p, fn: strip_menu_expressions(p),
                lambda p, fn: fix_trivial_annotation(p, fn, descs, raw_family),
                lambda p, fn: add_missing_annotation(p, fn, descs, raw_family),
                lambda p, fn: fix_showcases_annotation(p, fn, descs, raw_family),
            ]:
                fixed, changes = fix_fn(patch, filename)
                if fixed:
                    was_fixed = True
                    all_changes.extend(changes)

            if was_fixed:
                total_fixed += 1
                total_changes += len(all_changes)
                family_stats[family_name]["fixed"] += 1
                family_stats[family_name]["changes"] += len(all_changes)

                if apply:
                    with open(patch_file, "w", encoding="utf-8", newline="") as f:
                        json.dump(patch, f, indent=4, ensure_ascii=False)
                        f.write("\n")

                mode = "FIXED" if apply else "WOULD FIX"
                print(f"\n  [{mode}] {family_name}/{patch_file.name}:")
                for change in all_changes:
                    print(f"  {change}")

    # Summary
    print("\n" + "=" * 70)
    print(f"  {'APPLIED' if apply else 'DRY-RUN'} Summary")
    print("=" * 70)
    print(f"  Total patches scanned: {total_patches}")
    print(f"  Patches fixed:         {total_fixed}")
    print(f"  Total changes:         {total_changes}")
    print()

    print(f"  {'Family':<12s} {'Patches':>8s} {'Fixed':>8s} {'Changes':>8s}")
    print("  " + "-" * 40)
    for family_name in sorted(family_stats.keys()):
        fs = family_stats[family_name]
        print(f"  {family_name:<12s} {fs['patches']:>8d} {fs['fixed']:>8d} {fs['changes']:>8d}")

    if broken_patches:
        print(f"\n  BROKEN PATCHES (need regeneration): {len(broken_patches)}")
        for bp in broken_patches:
            print(f"    {bp}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Fix GONODES help patch quality issues")
    parser.add_argument("--family", type=str, help="Fix only this family")
    parser.add_argument("--apply", action="store_true", help="Actually write fixes (default: dry-run)")
    parser.add_argument("--extensions-only", action="store_true", help="Fix only extension patches")
    parser.add_argument("--core-only", action="store_true", help="Fix only core patches")
    args = parser.parse_args()

    families = [args.family] if args.family else None
    scope = "extensions" if args.extensions_only else ("core" if args.core_only else "all")
    fix_all(families=families, apply=args.apply, scope=scope)
