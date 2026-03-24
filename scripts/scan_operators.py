"""Scan all operator .gd files and extract class_name, node_type, family, parameters."""
import os, re, json

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def scan_ops(base_dir, ext_name=None):
    results = []
    if not os.path.isdir(base_dir):
        return results
    for fam in sorted(os.listdir(base_dir)):
        fam_dir = os.path.join(base_dir, fam)
        if not os.path.isdir(fam_dir):
            continue
        for f in sorted(os.listdir(fam_dir)):
            if not f.endswith('.gd'):
                continue
            fp = os.path.join(fam_dir, f)
            try:
                text = open(fp, 'r', encoding='utf-8').read()
            except:
                continue
            m = re.search(r'class_name\s+(\w+)', text)
            if not m:
                continue
            cls = m.group(1)
            if cls.endswith('Native'):
                continue
            m2 = re.search(r'node_type\s*=\s*["\']([^"\'\n]+)["\']', text)
            nt = m2.group(1) if m2 else ''
            params = []
            # Try both _init_parameters and _setup_parameters
            pm = re.search(r'func (?:_init_parameters|_setup_parameters)\s*\(\s*\)[^:]*:', text)
            if pm:
                block_start = pm.end()
                lines = text[block_start:].split('\n')
                for line in lines[1:]:
                    stripped = line.strip()
                    if stripped == '' or stripped.startswith('#'):
                        continue
                    if not line.startswith('\t') and not line.startswith('    '):
                        if stripped and not stripped.startswith('pass'):
                            break
                    cm = re.search(r'create_(float|int|bool|menu|enum|string|color|vector2i|file_path|separator|header|pulse|ramp)\s*\(\s*"([^"]+)"', stripped)
                    if cm:
                        ptype = cm.group(1)
                        pname = cm.group(2)
                        if ptype == 'enum':
                            ptype = 'menu'
                        default = None
                        if ptype == 'float':
                            dm = re.search(r'create_float\s*\(\s*"[^"]+"\s*,\s*([0-9.\-]+)', stripped)
                            if dm: default = float(dm.group(1))
                        elif ptype == 'int':
                            dm = re.search(r'create_int\s*\(\s*"[^"]+"\s*,\s*([0-9\-]+)', stripped)
                            if dm: default = int(dm.group(1))
                        elif ptype == 'bool':
                            dm = re.search(r'create_bool\s*\(\s*"[^"]+"\s*,\s*(true|false)', stripped, re.I)
                            if dm: default = dm.group(1).lower() == 'true'
                        elif ptype == 'menu':
                            dm = re.search(r'create_(?:menu|enum)\s*\(\s*"[^"]+"\s*,\s*([0-9]+)', stripped)
                            if dm: default = int(dm.group(1))
                        elif ptype == 'string':
                            dm = re.search(r'create_string\s*\(\s*"[^"]+"\s*,\s*"([^"]*)"', stripped)
                            if dm: default = dm.group(1)
                        if ptype not in ('separator', 'header'):
                            params.append({'name': pname, 'type': ptype, 'default': default})
            results.append({
                'class_name': cls,
                'node_type': nt,
                'family': fam,
                'file': fp.replace('\\', '/'),
                'extension': ext_name,
                'params': params
            })
    return results

all_ops = scan_ops('addons/gonodes/operators')
# Auto-discover extensions: any addons/gn_ext_*/operators directory
for entry in sorted(os.listdir('addons')):
    if entry.startswith('gn_ext_') and os.path.isdir(os.path.join('addons', entry, 'operators')):
        all_ops.extend(scan_ops(os.path.join('addons', entry, 'operators'), entry))

all_ops.sort(key=lambda x: (x['family'], x['class_name']))

with open('scripts/operator_registry.json', 'w', encoding='utf-8') as f:
    json.dump(all_ops, f, indent=2, ensure_ascii=False)

print(f'Total operators: {len(all_ops)}')
for fam in sorted(set(o['family'] for o in all_ops)):
    count = sum(1 for o in all_ops if o['family'] == fam)
    ext_count = sum(1 for o in all_ops if o['family'] == fam and o['extension'])
    print(f'  {fam}: {count} ({ext_count} ext)')

has_params = sum(1 for o in all_ops if o['params'])
print(f'\nOperators with params extracted: {has_params}/{len(all_ops)}')
for o in all_ops[:5]:
    print(f'  {o["class_name"]}: {len(o["params"])} params - {[p["name"] for p in o["params"][:3]]}')
