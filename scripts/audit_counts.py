import re, os

os.chdir(r'c:\MeOwn\Gonodes')

# Count core registrations
reg_file = 'addons/gonodes/core/gn_extension_registry.gd'
with open(reg_file, 'r', encoding='utf-8') as f:
    content = f.read()

families = {}
for m in re.finditer(r'_reg\(\s*"([^"]+)"\s*,\s*"([^"]+)"', content):
    family = m.group(1)
    op = m.group(2)
    families.setdefault(family, []).append(op)

print('=== CORE REGISTRATIONS ===')
total = 0
for fam in sorted(families.keys()):
    count = len(families[fam])
    total += count
    print(f'  {fam}: {count} -> {", ".join(families[fam])}')
print(f'TOTAL CORE: {total}')
print()

# Count extension registrations  
print('=== EXTENSION REGISTRATIONS ===')
ext_total = 0
ext_families = {}
for ext_dir in sorted(os.listdir('addons')):
    if ext_dir.startswith('gn_ext_'):
        cfg = os.path.join('addons', ext_dir, 'gn_extension.cfg')
        if os.path.exists(cfg):
            with open(cfg, 'r', encoding='utf-8') as f:
                cfg_content = f.read()
            ops = re.findall(r'\[operator\.(\w+)\]', cfg_content)
            fams = re.findall(r'family="(\w+)"', cfg_content)
            pairs = list(zip(ops, fams))
            print(f'  {ext_dir}: {len(ops)} ops')
            for op, fam in pairs:
                print(f'    {fam}: {op}')
                ext_families.setdefault(fam, []).append(op)
            ext_total += len(ops)

print(f'\nTOTAL EXT (non-native): {ext_total}')

# Combined per-family
print('\n=== COMBINED PER FAMILY ===')
all_fams = set(list(families.keys()) + list(ext_families.keys()))
grand = 0
for fam in sorted(all_fams):
    core = len(families.get(fam, []))
    ext = len(ext_families.get(fam, []))
    t = core + ext
    grand += t
    print(f'  {fam}: {core} core + {ext} ext = {t}')
print(f'GRAND TOTAL: {grand}')

# Check for MidiInCHOP duplicate
print('\n=== DUPLICATE CHECK ===')
core_ops = set()
for ops_list in families.values():
    core_ops.update(ops_list)
ext_ops = set()
for ops_list in ext_families.values():
    ext_ops.update(ops_list)
dupes = core_ops & ext_ops
if dupes:
    print(f'  DUPLICATES (in both core and ext): {dupes}')
else:
    print('  No duplicates found')
