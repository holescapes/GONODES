"""Rename an operator class across the entire GONODES workspace.

Updates all locations where a class_name appears:
  1. Operator .gd file: class_name declaration
  2. gn_core.cfg / gn_extension.cfg: [operator.X] section + script path
  3. Help patches (.gnpatch): "type" field in node dicts
  4. Manual test patches: "class_name" field
  5. Test .gd files: Constructor calls, string refs, comments
  6. operator_registry.json / port_registry.json
  7. docs/OPERATORS.md: heading + body references
  8. Python help-patch scripts: node("ClassName", ...) calls

Usage:
  python scripts/rename_node.py --old BoxSOP --new CubeSOP [--rename-file]
  python scripts/rename_node.py --old BoxSOP --new CubeSOP --dry-run

Flags:
  --rename-file   Also rename the .gd file (e.g. box_sop.gd → cube_sop.gd)
  --dry-run       Show what would change without writing anything
"""
import argparse, os, re, json, sys

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── File helpers ──────────────────────────────────────────────────────────────

def read(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)

# ── Collect files ─────────────────────────────────────────────────────────────

def find_files(pattern_dirs, extensions):
    """Walk directories, yield files matching extensions."""
    for d in pattern_dirs:
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for fn in files:
                if any(fn.endswith(ext) for ext in extensions):
                    yield os.path.join(root, fn).replace('\\', '/')

def find_cfg_files():
    """Find gn_core.cfg + all gn_extension.cfg files."""
    paths = []
    core = 'addons/gonodes/gn_core.cfg'
    if os.path.isfile(core):
        paths.append(core)
    for entry in sorted(os.listdir('addons')):
        cfg = f'addons/{entry}/gn_extension.cfg'
        if entry.startswith('gn_ext_') and os.path.isfile(cfg):
            paths.append(cfg)
    return paths

# ── Replacement engine ────────────────────────────────────────────────────────

class Renamer:
    def __init__(self, old, new, rename_file, dry_run):
        self.old = old
        self.new = new
        self.rename_file = rename_file
        self.dry_run = dry_run
        self.changes = []  # (filepath, description)
        self.warnings = []

    def log(self, path, desc):
        self.changes.append((path, desc))

    def warn(self, msg):
        self.warnings.append(msg)

    # ── 1. Operator .gd file ────────────────────────────────────────────────

    def rename_gd_source(self):
        """Find and update class_name in the operator .gd file."""
        search_dirs = ['addons/gonodes/operators']
        for entry in sorted(os.listdir('addons')):
            d = f'addons/{entry}/operators'
            if entry.startswith('gn_ext_') and os.path.isdir(d):
                search_dirs.append(d)

        found = None
        for fp in find_files(search_dirs, ['.gd']):
            text = read(fp)
            if re.search(rf'^class_name\s+{re.escape(self.old)}\b', text, re.MULTILINE):
                found = fp
                break

        if not found:
            self.warn(f'Operator .gd file with class_name {self.old} not found')
            return None

        text = read(found)
        new_text = re.sub(
            rf'^(class_name\s+){re.escape(self.old)}\b',
            rf'\g<1>{self.new}',
            text, count=1, flags=re.MULTILINE
        )
        if new_text != text:
            if not self.dry_run:
                write(found, new_text)
            self.log(found, f'class_name {self.old} → {self.new}')

        if self.rename_file:
            dirname = os.path.dirname(found)
            old_basename = os.path.basename(found)
            # Derive new filename from new class name using snake_case
            new_basename = self._to_snake(self.new) + '.gd'
            if new_basename != old_basename:
                new_path = os.path.join(dirname, new_basename).replace('\\', '/')
                if not self.dry_run:
                    os.rename(found, new_path)
                self.log(found, f'file renamed → {new_basename}')
                return (found, new_path)
        return (found, found)

    @staticmethod
    def _to_snake(name):
        """PascalCase/MixedCase → snake_case, preserving acronyms like SOP/CHOP."""
        # Insert _ before uppercase runs that precede lowercase
        s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', name)
        s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s)
        return s.lower()

    # ── 2. Manifest .cfg files ──────────────────────────────────────────────

    def rename_in_cfgs(self, old_script_path, new_script_path):
        """Update [operator.X] section headers and script= paths in cfg files."""
        for cfg_path in find_cfg_files():
            text = read(cfg_path)
            original = text

            # Section header
            text = text.replace(f'[operator.{self.old}]', f'[operator.{self.new}]')

            # Script path (if file was renamed)
            if old_script_path and new_script_path and old_script_path != new_script_path:
                old_res = 'res://' + old_script_path
                new_res = 'res://' + new_script_path
                text = text.replace(f'script="{old_res}"', f'script="{new_res}"')

            if text != original:
                if not self.dry_run:
                    write(cfg_path, text)
                self.log(cfg_path, f'section/script updated')

    # ── 3-4. Help + test patches (.gnpatch) ─────────────────────────────────

    def rename_in_patches(self):
        """Update "type" and "class_name" fields in .gnpatch JSON files."""
        search_dirs = ['addons/gonodes/help', 'tests/manual']
        for entry in sorted(os.listdir('addons')):
            d = f'addons/{entry}/help'
            if entry.startswith('gn_ext_') and os.path.isdir(d):
                search_dirs.append(d)

        count = 0
        for fp in find_files(search_dirs, ['.gnpatch']):
            text = read(fp)
            if self.old not in text:
                continue
            original = text
            # "type": "OldName" and "class_name": "OldName"
            text = re.sub(
                rf'("(?:type|class_name)":\s*"){re.escape(self.old)}"',
                rf'\g<1>{self.new}"',
                text
            )
            if text != original:
                if not self.dry_run:
                    write(fp, text)
                count += 1

        if count:
            self.log(f'{count} .gnpatch files', 'type/class_name refs updated')

    # ── 5. Test .gd files ───────────────────────────────────────────────────

    def rename_in_tests(self):
        """Update constructor calls, comments, string refs in test files."""
        search_dirs = ['tests']
        for entry in sorted(os.listdir('addons')):
            d = f'addons/{entry}/tests'
            if entry.startswith('gn_ext_') and os.path.isdir(d):
                search_dirs.append(d)

        count = 0
        for fp in find_files(search_dirs, ['.gd']):
            text = read(fp)
            if self.old not in text:
                continue
            original = text
            # OldName.new() → NewName.new()
            text = text.replace(f'{self.old}.new()', f'{self.new}.new()')
            # String references
            text = re.sub(rf'\b{re.escape(self.old)}\b', self.new, text)
            if text != original:
                if not self.dry_run:
                    write(fp, text)
                count += 1

        if count:
            self.log(f'{count} test .gd files', 'class refs updated')

    # ── 6. JSON registries ──────────────────────────────────────────────────

    def rename_in_json_registries(self, old_script_path, new_script_path):
        """Update operator_registry.json and port_registry.json."""
        for jpath in ['scripts/operator_registry.json', 'scripts/port_registry.json']:
            if not os.path.isfile(jpath):
                continue
            text = read(jpath)
            if self.old not in text:
                continue
            original = text

            # class_name field value
            text = text.replace(f'"class_name": "{self.old}"', f'"class_name": "{self.new}"')
            # Top-level key in port_registry.json
            text = text.replace(f'"{self.old}": {{', f'"{self.new}": {{')
            # file path (if renamed)
            if old_script_path and new_script_path and old_script_path != new_script_path:
                text = text.replace(old_script_path, new_script_path)

            if text != original:
                if not self.dry_run:
                    write(jpath, text)
                self.log(jpath, 'class_name / file refs updated')

    # ── 7. Docs ─────────────────────────────────────────────────────────────

    def rename_in_docs(self):
        """Update docs/OPERATORS.md and flag for human review."""
        doc_files = ['docs/OPERATORS.md', 'GONODES_CONTEXT.md']
        for dp in doc_files:
            if not os.path.isfile(dp):
                continue
            text = read(dp)
            if self.old not in text:
                continue
            original = text
            text = re.sub(rf'\b{re.escape(self.old)}\b', self.new, text)
            if text != original:
                if not self.dry_run:
                    write(dp, text)
                self.log(dp, 'references updated — REVIEW RECOMMENDED')

    # ── 8. Python help-patch scripts ────────────────────────────────────────

    def rename_in_python_scripts(self):
        """Update node("ClassName", ...) calls in patches_chop.py etc."""
        py_files = [
            'scripts/patches_chop.py',
            'scripts/generate_help_patches.py',
            'scripts/help_patch_engine.py',
        ]
        count = 0
        for fp in py_files:
            if not os.path.isfile(fp):
                continue
            text = read(fp)
            if self.old not in text:
                continue
            original = text
            text = re.sub(rf'\b{re.escape(self.old)}\b', self.new, text)
            if text != original:
                if not self.dry_run:
                    write(fp, text)
                count += 1

        if count:
            self.log(f'{count} Python scripts', 'class refs updated')

    # ── 9. dev_docs ─────────────────────────────────────────────────────────

    def rename_in_dev_docs(self):
        """Update references in dev_docs/ markdown files."""
        if not os.path.isdir('dev_docs'):
            return
        count = 0
        for fp in find_files(['dev_docs'], ['.md']):
            text = read(fp)
            if self.old not in text:
                continue
            original = text
            text = re.sub(rf'\b{re.escape(self.old)}\b', self.new, text)
            if text != original:
                if not self.dry_run:
                    write(fp, text)
                count += 1
        if count:
            self.log(f'{count} dev_docs files', 'references updated — REVIEW RECOMMENDED')

    # ── Run all ─────────────────────────────────────────────────────────────

    def run(self):
        print(f'Renaming {self.old} → {self.new}' +
              (' (dry run)' if self.dry_run else '') +
              (' (with file rename)' if self.rename_file else ''))
        print()

        result = self.rename_gd_source()
        old_script = result[0] if result else None
        new_script = result[1] if result else None

        self.rename_in_cfgs(old_script, new_script)
        self.rename_in_patches()
        self.rename_in_tests()
        self.rename_in_json_registries(old_script, new_script)
        self.rename_in_docs()
        self.rename_in_python_scripts()
        self.rename_in_dev_docs()

        print(f'{"Would change" if self.dry_run else "Changed"}:')
        for path, desc in self.changes:
            print(f'  {path}: {desc}')

        if self.warnings:
            print()
            print('Warnings:')
            for w in self.warnings:
                print(f'  ⚠ {w}')

        print(f'\nTotal: {len(self.changes)} location(s)')
        if not self.dry_run and self.changes:
            print('\nDon\'t forget to:')
            print('  1. Re-scan in Godot (Project → Reload) to regenerate .uid files')
            print('  2. Run tests:  godot --headless -s tests/test_runner.gd')
            print('  3. Regenerate registry:  python scripts/scan_operators.py')


def main():
    parser = argparse.ArgumentParser(description='Rename a GONODES operator class worldwide.')
    parser.add_argument('--old', required=True, help='Current class_name (e.g. BoxSOP)')
    parser.add_argument('--new', required=True, help='New class_name (e.g. CubeSOP)')
    parser.add_argument('--rename-file', action='store_true',
                        help='Also rename the .gd source file')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show changes without writing')
    args = parser.parse_args()

    if args.old == args.new:
        print('Old and new names are the same — nothing to do.')
        sys.exit(0)

    renamer = Renamer(args.old, args.new, args.rename_file, args.dry_run)
    renamer.run()


if __name__ == '__main__':
    main()
