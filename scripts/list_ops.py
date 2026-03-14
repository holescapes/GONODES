import json
ops = json.load(open('scripts/operator_registry.json'))
by_family = {}
for o in ops:
    f = o['family']
    by_family.setdefault(f, []).append(o)
for fam in sorted(by_family.keys()):
    ops_list = by_family[fam]
    print(f"\n=== {fam.upper()} ({len(ops_list)}) ===")
    for o in sorted(ops_list, key=lambda x: x['node_type']):
        ext = f" [{o['extension']}]" if o.get('extension') else ""
        print(f"  {o['node_type']:30s} {o['class_name']}{ext}")
print(f"\nTotal: {len(ops)}")
