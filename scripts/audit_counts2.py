import re, os

os.chdir(r'c:\MeOwn\Gonodes')

reg_file = 'addons/gonodes/core/gn_extension_registry.gd'
with open(reg_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Parse _reg("OpName", "FAMILY", ...) 
core = {}
for m in re.finditer(r'_reg\("(\w+)",\s*"(\w+)"', content):
    op, fam = m.group(1), m.group(2)
    core.setdefault(fam, []).append(op)

# Extension configs
ext = {}
for d in sorted(os.listdir('addons')):
    if not d.startswith('gn_ext_'): continue
    cfg = os.path.join('addons', d, 'gn_extension.cfg')
    if not os.path.exists(cfg): continue
    with open(cfg, 'r', encoding='utf-8') as f:
        cfg_text = f.read()
    ops = re.findall(r'\[operator\.(\w+)\]', cfg_text)
    fams = re.findall(r'family="(\w+)"', cfg_text)
    for op, fam in zip(ops, fams):
        ext.setdefault(d, {}).setdefault(fam, []).append(op)

print('=== CORE BY FAMILY ===')
core_total = 0
for fam in ['TOP','IMG','CHOP','DAT','SOP','POP','VOL','COMP','MAT','OUT','UI']:
    ops = core.get(fam, [])
    core_total += len(ops)
    print(f'  {fam}: {len(ops)}')
print(f'  CORE TOTAL: {core_total}')

print('\n=== EXTENSIONS (non-native only) ===')
ext_non_native = 0
for d in sorted(ext):
    if d == 'gn_ext_native': continue
    for fam, ops in sorted(ext[d].items()):
        for op in ops:
            print(f'  {d} -> {fam}: {op}')
            ext_non_native += 1
print(f'  NON-NATIVE EXT TOTAL: {ext_non_native}')

print('\n=== NATIVE EXTENSION ===')
native_total = 0
if 'gn_ext_native' in ext:
    for fam, ops in sorted(ext['gn_ext_native'].items()):
        native_total += len(ops)
        print(f'  {fam}: {len(ops)}')
    print(f'  NATIVE TOTAL: {native_total}')

# Dedupe check
all_core_ops = set()
for ops in core.values():
    all_core_ops.update(ops)
all_ext_ops = set()
for d in ext:
    if d == 'gn_ext_native': continue
    for ops in ext[d].values():
        all_ext_ops.update(ops)
dupes = all_core_ops & all_ext_ops
print(f'\n=== DUPLICATES (core vs non-native ext): {dupes if dupes else "NONE"} ===')

# Grand total (core + non-native ext, dedupe)
unique = len(all_core_ops | all_ext_ops)
print(f'\n=== UNIQUE OPERATORS (core + non-native ext): {unique} ===')
print(f'=== + {native_total} native variants ===')

# Per-family combined (core + non-native ext)
print('\n=== COMBINED PER FAMILY (for docs) ===')
combined = {}
for fam, ops in core.items():
    combined.setdefault(fam, set()).update(ops)
for d in ext:
    if d == 'gn_ext_native': continue
    for fam, ops in ext[d].items():
        combined.setdefault(fam, set()).update(ops)
grand = 0
for fam in ['TOP','IMG','CHOP','DAT','SOP','POP','VOL','COMP','MAT','OUT','UI']:
    c = len(combined.get(fam, set()))
    grand += c
    print(f'  {fam}: {c}')
print(f'  GRAND TOTAL: {grand}')
