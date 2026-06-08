"""Auto-add missing port labels to GONODES operators (Rule 25.14).

Companion to audit_labels.py.  Scans all operator .gd files under
addons/gonodes/operators/ and addons/gn_ext_*/operators/ for add_input()
and add_output() calls that lack a label argument.  Adds a title-cased
label derived from the port name.

Usage:
    python scripts/fix_labels.py              # apply fixes
    python scripts/fix_labels.py --dry-run    # preview only
"""
import os, re, sys

DRY_RUN = "--dry-run" in sys.argv

_script_dir = os.path.dirname(os.path.abspath(__file__))
_root = os.path.dirname(_script_dir)


def _label_from_name(port_name: str) -> str:
    """Convert snake_case port name to Title Case label.

    Examples:
        "pop_in"  -> "Pop In"
        "vel_out" -> "Vel Out"
        "geo_in"  -> "Geo In"
        "out"     -> "Out"
        "density_out" -> "Density Out"
    """
    return port_name.replace("_", " ").title()


def _add_labels_to_file(path: str) -> int:
    """Add missing labels to add_input/add_output calls.  Returns count."""
    text = open(path, "r", encoding="utf-8").read()
    count = 0

    # add_input("name", family, required, "description")
    #        -> add_input("name", family, required, "description", "Label")
    # But NOT if there are already 5+ args (label present).
    def fix_input(m):
        nonlocal count
        full = m.group(0)
        # Skip if a 5th arg (label) already exists after the description.
        # Check by counting commas in the matched text.
        if full.count(",") >= 4:
            return full
        name = m.group(1)
        label = _label_from_name(name)
        count += 1
        return full.rstrip(")") + ', "' + label + '")'

    # Match add_input("name", GNFamily..., true/false, "desc")
    # The description can be a plain string or use % formatting.
    text = re.sub(
        r'add_input\("(\w+)",\s*GNFamily\.\w+\.\w+,\s*(?:true|false),\s*"[^"]*"(?:\s*%\s*\w+)?\)',
        fix_input,
        text,
    )

    # add_output("name", family, "description")
    #         -> add_output("name", family, "description", "Label")
    # But NOT if there are already 4+ args.
    def fix_output(m):
        nonlocal count
        full = m.group(0)
        if full.count(",") >= 3:
            return full
        name = m.group(1)
        label = _label_from_name(name)
        count += 1
        return full.rstrip(")") + ', "' + label + '")'

    text = re.sub(
        r'add_output\("(\w+)",\s*GNFamily\.\w+\.\w+,\s*"[^"]*"(?:\s*%\s*\w+)?\)',
        fix_output,
        text,
    )

    if count > 0 and not DRY_RUN:
        open(path, "w", encoding="utf-8", newline="").write(text)

    return count


def main():
    scan_dirs = [os.path.join(_root, "addons", "gonodes", "operators")]
    # Also scan extension operators
    addons = os.path.join(_root, "addons")
    for d in os.listdir(addons):
        if d.startswith("gn_ext_"):
            ext_ops = os.path.join(addons, d, "operators")
            if os.path.isdir(ext_ops):
                scan_dirs.append(ext_ops)

    total_labels = 0
    total_files = 0
    for scan_dir in scan_dirs:
        for dirpath, _dirs, files in os.walk(scan_dir):
            for f in sorted(files):
                if not f.endswith(".gd"):
                    continue
                path = os.path.join(dirpath, f)
                added = _add_labels_to_file(path)
                if added > 0:
                    rel = os.path.relpath(path, _root)
                    print(f"  {'[dry-run] ' if DRY_RUN else ''}+{added} labels: {rel}")
                    total_labels += added
                    total_files += 1

    verb = "Would add" if DRY_RUN else "Added"
    print(f"\n{verb} {total_labels} labels across {total_files} files")


if __name__ == "__main__":
    main()
