#!/usr/bin/env python3
"""Add human-readable port labels to multi-port operators that still lack them.

Phase 2: targeted label addition for the 43 remaining multi-port operators.
into:
    add_output("velocity_out", GNFamily.Type.VOL, "Velocity field", "Velocity")

Rules:
- Strip _in, _out, _input, _output suffixes
- Replace _ with space, title-case
- Expand common abbreviations (vel->Velocity, den->Density, etc.)
- Skip if port_label arg already present (5th arg for add_input, 4th for add_output)
"""

import os
import re
import sys

# Abbreviation expansions (applied after suffix stripping + title-casing)
EXPANSIONS = {
    "Vel": "Velocity",
    "Den": "Density",
    "Geo": "Geometry",
    "Tex": "Texture",
    "Mat": "Material",
    "Bg": "Background",
    "Fg": "Foreground",
    "Pos": "Position",
    "Dir": "Direction",
    "Res": "Resolution",
    "Freq": "Frequency",
    "Amp": "Amplitude",
    "Vol": "Volume",
    "Img": "Image",
    "Sop": "SOP",
    "Chop": "CHOP",
    "Prev": "Previous",
    "Num": "Number",
    "Ref": "Reference",
    "Src": "Source",
    "Dst": "Destination",
    "Idx": "Index",
    "Btn": "Button",
    "Lbl": "Label",
    "Sel": "Selection",
    "Env": "Environment",
    "Cam": "Camera",
}

# Port names that are already clean enough — just capitalize
PASS_THROUGH = {
    "in", "out", "seed", "dye", "mask", "state", "spectrum",
    "table", "text", "data", "mesh", "material", "color",
    "depth", "normal", "obstacle", "trigger", "reset",
}

def make_label(port_name: str) -> str:
    """Convert a port_name like 'density_out' to a clean label like 'Density'."""
    name = port_name.lower()

    # Strip common suffixes
    for suffix in ("_output", "_input", "_out", "_in"):
        if name.endswith(suffix):
            name = name[:-len(suffix)]
            break

    # Strip common prefixes for bridge operators
    for prefix in ("chop_", "top_", "sop_", "dat_", "mat_", "vol_", "img_", "pop_", "ui_"):
        if name.startswith(prefix) and len(name) > len(prefix):
            name = name[len(prefix):]
            break

    # Handle numbered ports: in0, in1, out0, out1
    m = re.match(r'^(in|out)(\d+)$', name)
    if m:
        base = "Input" if m.group(1) == "in" else "Output"
        return "%s %s" % (base, m.group(2))

    # Split on underscores, title-case each word
    parts = name.split("_")
    titled = [p.capitalize() for p in parts if p]

    # Apply abbreviation expansions
    result = " ".join(titled)
    for abbr, expanded in EXPANSIONS.items():
        # Word-boundary replacement
        result = re.sub(r'\b' + re.escape(abbr) + r'\b', expanded, result)

    return result


def count_args(text: str) -> int:
    """Count comma-separated arguments in a parenthesized call, respecting nesting."""
    depth = 0
    count = 1  # At least 1 arg if text is non-empty
    in_string = False
    escape_next = False
    for ch in text:
        if escape_next:
            escape_next = False
            continue
        if ch == '\\':
            escape_next = True
            continue
        if ch == '"' and not escape_next:
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch in ('(', '[', '{'):
            depth += 1
        elif ch in (')', ']', '}'):
            depth -= 1
        elif ch == ',' and depth == 0:
            count += 1
    return count


def process_file(filepath: str) -> tuple:
    """Process a single .gd file, returns (modified: bool, changes: int)."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    changes = 0
    new_lines = []

    for line in lines:
        stripped = line.strip()

        # Match add_input(...) or add_output(...) calls
        # We need to handle multi-line calls too, but most are single-line
        if 'add_input(' in stripped or 'add_output(' in stripped:
            is_input = 'add_input(' in stripped
            func_name = 'add_input' if is_input else 'add_output'

            # Extract the full call arguments
            # Find the opening paren after add_input/add_output
            idx = stripped.find(func_name + '(')
            if idx >= 0:
                args_start = idx + len(func_name) + 1
                # Find matching closing paren
                depth = 1
                pos = args_start
                while pos < len(stripped) and depth > 0:
                    ch = stripped[pos]
                    if ch == '(':
                        depth += 1
                    elif ch == ')':
                        depth -= 1
                    pos += 1

                if depth == 0:
                    args_text = stripped[args_start:pos-1]
                    nargs = count_args(args_text)

                    # add_input has 5 args max (name, family, multi, desc, label)
                    # add_output has 4 args max (name, family, desc, label)
                    max_args = 5 if is_input else 4

                    if nargs < max_args:
                        # Extract port_name (first quoted string)
                        name_match = re.search(r'"([^"]*)"', args_text)
                        if name_match:
                            port_name = name_match.group(1)
                            label = make_label(port_name)

                            # Only add if label differs from port_name
                            if label.lower() != port_name.lower():
                                # Insert label as the last argument
                                close_paren_idx = line.rfind(')')
                                if close_paren_idx >= 0:
                                    new_line = line[:close_paren_idx] + ', "%s")' % label
                                    # Preserve anything after the closing paren
                                    after = line[close_paren_idx+1:]
                                    new_line += after
                                    line = new_line
                                    changes += 1

        new_lines.append(line)

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8', newline='') as f:
            f.write('\n'.join(new_lines))

    return changes > 0, changes


def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Directories to scan
    scan_dirs = [
        os.path.join(base_dir, "addons", "gonodes", "operators"),
        os.path.join(base_dir, "addons", "gonodes", "core"),
    ]

    total_files = 0
    total_changes = 0
    modified_files = 0

    for scan_dir in scan_dirs:
        if not os.path.isdir(scan_dir):
            print(f"Skipping missing dir: {scan_dir}")
            continue

        for root, dirs, files in os.walk(scan_dir):
            for fname in sorted(files):
                if not fname.endswith('.gd'):
                    continue
                filepath = os.path.join(root, fname)
                total_files += 1
                modified, changes = process_file(filepath)
                if modified:
                    modified_files += 1
                    total_changes += changes
                    relpath = os.path.relpath(filepath, base_dir)
                    print(f"  {relpath}: {changes} port(s) labeled")

    print(f"\nDone: {total_changes} labels added across {modified_files}/{total_files} files")


if __name__ == "__main__":
    main()
