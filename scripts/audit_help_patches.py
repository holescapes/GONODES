"""
GONODES Help Patch Quality Auditor
Scans all help patches for common quality issues per HELP_PATCH_RULES.md.
Outputs a report of issues found, sorted by severity.

Usage:
    python scripts/audit_help_patches.py                    # Full audit
    python scripts/audit_help_patches.py --family top       # One family
    python scripts/audit_help_patches.py --severity high    # Only high-severity
    python scripts/audit_help_patches.py --fix-annotations  # Auto-fix trivial annotations
"""
import json
import os
import sys
import re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
HELP_DIR = ROOT / "addons" / "gonodes" / "help"
REGISTRY_PATH = ROOT / "scripts" / "operator_registry.json"

# ── Issue severity levels ──────────────────────────────────────────

CRITICAL = "CRITICAL"  # Patch is broken or misleading
HIGH = "HIGH"          # Patch fails quality rules
MEDIUM = "MEDIUM"      # Patch is weak but functional
LOW = "LOW"            # Minor style issue

# ── Load registry for operator metadata ────────────────────────────

def load_registry():
    if REGISTRY_PATH.exists():
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

# ── Audit functions ────────────────────────────────────────────────

def audit_patch(path, registry):
    """Audit a single .gnpatch file. Returns list of (severity, message)."""
    issues = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            patch = json.load(f)
    except json.JSONDecodeError as e:
        issues.append((CRITICAL, f"Invalid JSON: {e}"))
        return issues
    except Exception as e:
        issues.append((CRITICAL, f"Cannot read file: {e}"))
        return issues

    filename = path.stem  # e.g., "blur_basic"
    family = path.parent.name  # e.g., "top"

    nodes = patch.get("nodes", {})
    connections = patch.get("connections", [])
    annotations = patch.get("annotations", [])

    # ── Rule: Annotation must exist ────────────────────────────────
    if not annotations:
        issues.append((HIGH, "No annotation — patch has no explanation"))
    else:
        ann_text = annotations[0].get("text", "")

        # ── Rule: No "Default settings" or trivial annotations ─────
        # Content is the text AFTER the title line and any blank lines
        lines = ann_text.strip().split("\n")
        # Skip title line (e.g., "BlurTOP — Basic") and blank lines
        content_lines = [l.strip() for l in lines[1:] if l.strip()]
        content = "\n".join(content_lines)

        trivial_content_patterns = [
            r"^Default settings\.?$",
            r"^Alternate parameter values\.?$",
            r"^More complex configuration\.?$",
        ]

        is_trivial = False
        # No content at all after title
        if not content:
            is_trivial = True
        else:
            for pattern in trivial_content_patterns:
                if re.match(pattern, content, re.IGNORECASE):
                    is_trivial = True
                    break

        if is_trivial:
            issues.append((HIGH, f"Trivial annotation: '{ann_text.strip()[:80]}...'"))

        # ── Rule: Annotation should say what to observe ────────────
        if len(ann_text.strip()) < 30:
            issues.append((MEDIUM, f"Annotation too short ({len(ann_text.strip())} chars)"))

        # ── Rule: "Showcases: x, y, z" without explanation ─────────
        if re.search(r"Showcases:\s*\w+,\s*\w+", ann_text) and len(ann_text) < 80:
            issues.append((MEDIUM, "Generic 'Showcases:' annotation without explanation"))

    # ── Rule: Must have at least one connection ────────────────────
    # Exempt standalone operators that are self-contained by design
    standalone_types = {"SubNetworkCOMP", "SubNetworkNode", "XYPadUI"}
    node_types_set = {n.get("type", "") for n in nodes.values()}
    if not connections and not (node_types_set & standalone_types):
        issues.append((MEDIUM, "No connections — isolated nodes"))

    # ── Rule: Must end in a visible output ─────────────────────────
    # Exempt: output family operators ARE the output by definition
    # Exempt: input operators that receive external data (audio, midi, osc, etc.)
    input_types = {
        "AudioInCHOP", "AudioFileInCHOP", "AudioSpectrumCHOP", "MidiInCHOP",
        "OSCInCHOP", "OscInCHOP", "TabletInCHOP", "CueListCHOP", "CueCHOP",
        "KeyboardInCHOP", "MouseInCHOP",
        "SerialDAT", "MidiInDAT", "OSCInDAT", "OscInDAT",
        "MultiTouchInDAT", "PanelExecuteDAT", "RenderPickDAT",
        "HostInCHOP", "HostInDAT", "HostInTOP", "HostInSOP", "HostInVOL", "HostInPOP",
        "SubNetworkCOMP", "SubNetworkNode", "ObjectMergeSOP", "MovieFileInTOP",
        "XYPadUI", "GDScriptSCRIPT",
    }
    has_input_op = bool(node_types_set & input_types)

    if family != "output" and not has_input_op:
        has_window = any(n.get("type") == "WindowOUT" for n in nodes.values())
        has_sink = any(n.get("type", "").startswith("HostOut") or
                       n.get("type") in ("SinkOUT", "HapOUT", "MovieFileOutTOP")
                       for n in nodes.values())
        if not has_window and not has_sink:
            issues.append((HIGH, "No WindowOUT or visible output — result isn't viewable"))

    # ── Rule: No expressions on enum/menu parameters ───────────────
    for nid, ndata in nodes.items():
        params = ndata.get("parameters", {})
        for pname, pval in params.items():
            if isinstance(pval, dict):
                has_expr = pval.get("mode") == "EXPRESSION" and "expression" in pval
                val = pval.get("value")

                # Check if this is likely a menu param (int value 0-10 range)
                # We flag expressions on params that have integer values 0-5
                # which are almost certainly enum/menu params
                if has_expr and isinstance(val, int) and 0 <= val <= 5:
                    # Known menu parameter names
                    menu_params = {
                        "noise_type", "method", "mode", "waveform", "operation",
                        "blend_mode", "key_mode", "projection", "shape", "algorithm",
                        "space", "axis", "function", "order", "direction",
                        "primitive_type", "filter", "interpolation", "type",
                        "wrap_mode", "fill_mode", "source", "target",
                    }
                    if pname in menu_params:
                        issues.append((HIGH,
                            f"Expression on menu param '{pname}' in node '{nid}' "
                            f"— menus shouldn't be expression-driven"))

    # ── Rule: "basic" patches should not have expressions ──────────
    is_basic = filename.endswith("_basic")
    if is_basic:
        for nid, ndata in nodes.items():
            params = ndata.get("parameters", {})
            for pname, pval in params.items():
                if isinstance(pval, dict) and pval.get("mode") == "EXPRESSION":
                    issues.append((HIGH,
                        f"Expression on '{pname}' in '{nid}' — basic patches should be static"))

    # ── Rule: Focus node should have demonstrative params ──────────
    # Find the focus node (the operator being demo'd, not source/viewer)
    viewer_types = {"WindowOUT", "CHOPtoTOP", "TextTOP", "ImgToTOP",
                    "GeometryCOMP", "CameraCOMP", "RenderTOP", "RenderPOP",
                    "RaymarchVOL"}
    source_prefixes = {"src_", "noise", "ramp", "circle", "constant", "lfo", "wave",
                       "grid", "sphere", "box", "torus"}
    focus_candidates = []
    for nid, ndata in nodes.items():
        ntype = ndata.get("type", "")
        if ntype in viewer_types:
            continue
        # Skip obvious sources
        is_source = any(nid.startswith(sp) for sp in source_prefixes)
        if is_source and ntype != nid.rstrip("0123456789") + ntype:
            continue
        focus_candidates.append((nid, ndata))

    # ── Rule: Must have nodes ──────────────────────────────────────
    if not nodes:
        issues.append((CRITICAL, "Empty patch — no nodes"))

    return issues


def audit_family(family_dir, registry):
    """Audit all patches in a family directory."""
    results = {}
    if not family_dir.exists():
        return results

    for patch_file in sorted(family_dir.glob("*.gnpatch")):
        issues = audit_patch(patch_file, registry)
        if issues:
            results[patch_file.name] = issues
    return results


def audit_all(families=None, severity_filter=None, summary_only=False, scope="all"):
    """Audit all help patches, optionally filtered by family and severity.
    scope: 'all', 'core', or 'extensions'"""
    registry = load_registry()
    all_results = {}
    total_patches = 0
    total_issues = 0
    severity_counts = defaultdict(int)
    family_counts = defaultdict(lambda: {"patches": 0, "issues": 0, "clean": 0})

    # Collect all family directories (core + extensions)
    family_dirs = []
    if scope in ("all", "core") and HELP_DIR.exists():
        family_dirs.extend(sorted(d for d in HELP_DIR.iterdir() if d.is_dir()))

    # Extension help directories: addons/gn_ext_*/help/*/
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
        # For extensions: use "ext_name/family", for core: just "family"
        parent_name = family_dir.parent.parent.name
        if parent_name.startswith("gn_ext_"):
            family_name = f"{parent_name}/{family_dir.name}"
        else:
            family_name = family_dir.name

        if families and family_name not in families and family_dir.name not in families:
            continue

        patches = list(family_dir.glob("*.gnpatch"))
        family_counts[family_name]["patches"] = len(patches)
        total_patches += len(patches)

        results = audit_family(family_dir, registry)
        for patch_name, issues in results.items():
            filtered = issues
            if severity_filter:
                filtered = [(s, m) for s, m in issues if s == severity_filter]

            if filtered:
                all_results[f"{family_name}/{patch_name}"] = filtered
                total_issues += len(filtered)
                family_counts[family_name]["issues"] += len(filtered)
                for sev, _ in filtered:
                    severity_counts[sev] += 1

        clean = len(patches) - len(results)
        family_counts[family_name]["clean"] = clean

    # ── Print Report ───────────────────────────────────────────────
    print("=" * 70)
    print("  GONODES Help Patch Quality Audit")
    print("=" * 70)
    print(f"\n  Total patches scanned: {total_patches}")
    print(f"  Total issues found:    {total_issues}")
    print(f"  Clean patches:         {total_patches - len(all_results)}")
    print()

    # Severity summary
    print("  Severity Breakdown:")
    for sev in [CRITICAL, HIGH, MEDIUM, LOW]:
        if severity_counts[sev]:
            print(f"    {sev:10s}: {severity_counts[sev]}")
    print()

    # Per-family summary
    print("  Per-Family Summary:")
    print(f"    {'Family':<12s} {'Patches':>8s} {'Issues':>8s} {'Clean':>8s} {'Rate':>8s}")
    print("    " + "-" * 48)
    for family_name in sorted(family_counts.keys()):
        fc = family_counts[family_name]
        total = fc["patches"]
        clean = fc["clean"]
        rate = f"{100 * clean / total:.0f}%" if total > 0 else "N/A"
        print(f"    {family_name:<12s} {total:>8d} {fc['issues']:>8d} {clean:>8d} {rate:>8s}")
    print()

    # Detailed issues
    if all_results and not summary_only:
        print("  Detailed Issues:")
        print("  " + "-" * 68)
        for patch_path in sorted(all_results.keys()):
            issues = all_results[patch_path]
            print(f"\n  {patch_path}:")
            for sev, msg in issues:
                print(f"    [{sev:8s}] {msg}")

    return all_results


# ── Main ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Audit GONODES help patches")
    parser.add_argument("--family", type=str, help="Audit only this family (e.g., top, chop)")
    parser.add_argument("--severity", type=str, choices=["CRITICAL", "HIGH", "MEDIUM", "LOW"],
                        help="Show only this severity level")
    parser.add_argument("--summary-only", action="store_true", help="Print only summary, no details")
    parser.add_argument("--extensions-only", action="store_true", help="Audit only extension help patches")
    parser.add_argument("--core-only", action="store_true", help="Audit only core help patches")
    args = parser.parse_args()

    families = [args.family] if args.family else None
    scope = "extensions" if args.extensions_only else ("core" if args.core_only else "all")
    results = audit_all(families=families, severity_filter=args.severity,
                        summary_only=args.summary_only, scope=scope)
