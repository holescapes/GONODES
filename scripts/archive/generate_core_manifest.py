#!/usr/bin/env python3
"""Generate gn_core.cfg from existing _reg() calls in gn_extension_registry.gd
and class_name declarations in operator .gd files.

Also identifies operators that require_compute based on requires_compute() or
compute shader usage in their source.
"""
import re, os, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "addons" / "gonodes" / "core" / "gn_extension_registry.gd"
OPERATORS_DIR = ROOT / "addons" / "gonodes" / "operators"
OUTPUT = ROOT / "addons" / "gonodes" / "gn_core.cfg"

# ── Step 1: Parse _reg() calls ──────────────────────────────────────────────
reg_pattern = re.compile(
    r'_reg\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*\w+\s*,\s*\n?\s*"([^"]+)"\s*\)',
    re.MULTILINE
)

registry_src = REGISTRY.read_text(encoding="utf-8")
reg_entries = []  # (class_name, family, description)
for m in reg_pattern.finditer(registry_src):
    reg_entries.append((m.group(1), m.group(2), m.group(3)))

print(f"Found {len(reg_entries)} _reg() calls")

# ── Step 2: Build class_name → file path map ────────────────────────────────
class_to_file = {}
for gd_file in OPERATORS_DIR.rglob("*.gd"):
    text = gd_file.read_text(encoding="utf-8", errors="replace")
    cn_match = re.search(r'^class_name\s+(\w+)', text, re.MULTILINE)
    if cn_match:
        cn = cn_match.group(1)
        # Convert to res:// path
        rel = gd_file.relative_to(ROOT).as_posix()
        res_path = "res://" + rel
        class_to_file[cn] = res_path

print(f"Found {len(class_to_file)} operator .gd files with class_name")

# ── Step 3: Detect compute/renderer requirements ────────────────────────────
compute_classes = set()
forward_plus_classes = set()
for gd_file in OPERATORS_DIR.rglob("*.gd"):
    text = gd_file.read_text(encoding="utf-8", errors="replace")
    cn_match = re.search(r'^class_name\s+(\w+)', text, re.MULTILINE)
    if not cn_match:
        continue
    cn = cn_match.group(1)
    # Check for compute shader usage
    if "requires_compute" in text and "return true" in text:
        compute_classes.add(cn)
    if "RenderingDevice" in text or "compute_shader" in text.lower():
        compute_classes.add(cn)
    # Check for CompositorEffect (forward_plus only)
    if "CompositorEffect" in text and cn != "CompositorEffectTOP":
        forward_plus_classes.add(cn)

# Manual overrides for known compute-dependent nodes
compute_overrides = {
    "ComputeShaderTOP", "GPUMarchingCubesVOL", "Fluid2DTOP",
    "ReactionDiffusionTOP", "RaymarchVOL",
}
compute_classes.update(compute_overrides)

# CompositorEffectTOP needs forward_plus
forward_plus_overrides = {"CompositorEffectTOP"}
forward_plus_classes.update(forward_plus_overrides)

print(f"Detected {len(compute_classes)} compute-dependent operators")
print(f"Detected {len(forward_plus_classes)} forward_plus-only operators")

# ── Step 4: Generate gn_core.cfg ─────────────────────────────────────────────
lines = []
lines.append("[extension]")
lines.append("")
lines.append('name="GONODES Core"')
lines.append('version="0.1.0"')
lines.append('author="GONODES"')
lines.append('description="Core built-in operators for all families."')
lines.append('section=""')
lines.append("")

missing = []
for class_name, family, description in reg_entries:
    script_path = class_to_file.get(class_name)
    if not script_path:
        missing.append(class_name)
        continue

    lines.append(f"[operator.{class_name}]")
    lines.append("")
    lines.append(f'family="{family}"')
    lines.append(f'script="{script_path}"')
    # Escape any quotes in description
    desc_escaped = description.replace('"', '\\"')
    lines.append(f'description="{desc_escaped}"')

    # Add capability tags
    if class_name in compute_classes:
        lines.append('requires_compute=true')
    if class_name in forward_plus_classes:
        lines.append('requires_renderers=["forward_plus"]')

    lines.append("")

OUTPUT.write_text("\n".join(lines), encoding="utf-8", newline="")
print(f"\nGenerated {OUTPUT} with {len(reg_entries) - len(missing)} operators")
if missing:
    print(f"WARNING: {len(missing)} operators not found on disk: {missing}")
