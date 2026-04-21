#!/usr/bin/env python3
"""Generate the Native Acceleration section content for docs/OPERATORS.md.

Reads all native wrapper .gd files and their cfg descriptions,
then produces a markdown-formatted listing grouped by family.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NATIVE_DIR = os.path.join(ROOT, "addons", "gn_ext_native")


def scan_natives():
    """Scan native wrappers → list of {class_name, node_type, family, description}."""
    ops_dir = os.path.join(NATIVE_DIR, "operators")
    natives = []
    for root, dirs, files in os.walk(ops_dir):
        for f in files:
            if not f.endswith(".gd"):
                continue
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8") as fh:
                content = fh.read()
            cn = None
            nt = None
            for line in content.splitlines():
                if line.strip().startswith("class_name "):
                    cn = line.strip().split()[1]
                m = re.match(r'\s*node_type\s*=\s*"(.+?)"', line)
                if m:
                    nt = m.group(1)
            if cn and cn.endswith("Native") and nt:
                family = os.path.basename(root).upper()
                natives.append({
                    "class_name": cn,
                    "node_type": nt,
                    "family": family,
                    "original": cn[:-6],
                })
    return sorted(natives, key=lambda x: (x["family"], x["class_name"]))


def get_cfg_descriptions():
    """Read all cfg descriptions for native operators."""
    cfg_path = os.path.join(NATIVE_DIR, "gn_extension.cfg")
    if not os.path.exists(cfg_path):
        return {}
    text = open(cfg_path, "r", encoding="utf-8").read()
    descs = {}
    current_class = None
    for line in text.splitlines():
        m = re.match(r"\[operator\.(\w+)\]", line)
        if m:
            current_class = m.group(1)
        m = re.match(r'description="(.+?)"', line)
        if m and current_class:
            descs[current_class] = m.group(1)
    return descs


def generate_section(natives, descs):
    """Generate the full markdown section content."""
    # Count by family
    from collections import Counter
    family_counts = Counter(n["family"] for n in natives)

    lines = []
    lines.append("## Native Acceleration Extension (Optional)")
    lines.append("")
    lines.append(
        f"The `gn_ext_native` extension provides C++ GDExtension-accelerated variants of "
        f"**{len(natives)}** CPU-heavy operators across {len(family_counts)} families. "
        f"These appear as separate operators in the palette under a \"Native\" section when "
        f"the C++ binaries are compiled. Each native operator has an identical parameter "
        f"interface to its GDScript counterpart and includes a pure-GDScript fallback for "
        f"when the C++ library is unavailable."
    )
    lines.append("")
    lines.append("### Summary by Family")
    lines.append("")
    lines.append("| Family | Count |")
    lines.append("|--------|-------|")
    for fam in sorted(family_counts.keys()):
        lines.append(f"| {fam} | {family_counts[fam]} |")
    lines.append(f"| **Total** | **{len(natives)}** |")
    lines.append("")
    lines.append(
        "**Build status:** Windows x86_64 binary compiled and active "
        "(`bin/win64/libgn_native.windows.template_release.x86_64.dll`). "
        "Linux/macOS builds require running `scons platform=linux|macos target=template_release` "
        "on those platforms. The extension registry auto-detects the C++ classes via "
        "`ClassDB.class_exists()` and falls back to pure GDScript if the library is missing."
    )
    lines.append("")

    # Per-family tables
    current_family = None
    for n in natives:
        if n["family"] != current_family:
            current_family = n["family"]
            lines.append(f"### {current_family} — Native Variants")
            lines.append("")
            lines.append("| Operator | Native Class | Description |")
            lines.append("|----------|-------------|-------------|")

        desc = descs.get(n["class_name"], "C++ accelerated variant")
        # Clean up description — remove trailing period if present
        desc = desc.rstrip(".")
        lines.append(f"| {n['original']} | {n['class_name']} | {desc} |")

    lines.append("")
    return "\n".join(lines)


def main():
    natives = scan_natives()
    descs = get_cfg_descriptions()

    content = generate_section(natives, descs)

    if "--print" in sys.argv:
        print(content)
        return 0

    # Update docs/OPERATORS.md — replace existing native section
    md_path = os.path.join(ROOT, "docs", "OPERATORS.md")
    text = open(md_path, "r", encoding="utf-8").read()

    # Find the section boundaries
    start_marker = "## Native Acceleration Extension (Optional)"
    end_markers = [
        "## Shadertoy Extension",
        "## ISF Extension",
        "## Custom Assets",
    ]

    start_idx = text.find(start_marker)
    if start_idx < 0:
        print("ERROR: Could not find Native Acceleration section in OPERATORS.md")
        return 1

    # Find the next section after native
    end_idx = len(text)
    for marker in end_markers:
        idx = text.find(marker, start_idx + len(start_marker))
        if idx >= 0 and idx < end_idx:
            end_idx = idx

    # Replace
    # Include the trailing --- before next section
    old_section = text[start_idx:end_idx]
    new_section = content + "\n---\n\n"

    new_text = text[:start_idx] + new_section + text[end_idx:]
    open(md_path, "w", encoding="utf-8", newline="").write(new_text)

    print(f"Updated docs/OPERATORS.md — {len(natives)} native operators listed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
